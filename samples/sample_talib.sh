#####################################################################
## sample_talib.sh: Enhancing Financial Data with TALIB features 
#####################################################################

setup_ta_lib() {
 # For the first run only, install TA-Lib and make sure it is installed correctly
 bash ~/mod_talib/installtalib.sh &>~/mod_talib/installtalib.txt
 if [[ `grep "All tests succeeded" ~/mod_talib/installtalib.txt | wc -l` == 0 ]]
 then
  cat ~/mod_talib/installtalib.txt &>>task.log
  exit
 fi
}

category() {
        # Select the current machine's filesystem as your datastore / data location
	ess select local
        # Categorize the raw, compressed Financial Tick data for the EURUSD currency
	ess category add EURUSD "/home/sampledata/Financial/EURUSD_Ticks_*.zip" --overwrite
}

createdb () {
        # Reset old config
	ess server reset 
        # Create a database "demo", a table "tick", and some variables to store the enhanced tick data in
	ess create database demo --port 0
	ess create table tick s,pkey:curr s,+key:utc f:ask f:bid f:avg f:askvol f:bidvol f:nextask f:nextbid f:nextavg \
          f:delta_NaskAsk f:delta_NbidBid f:delta_NavgAvg f:max_$1_avg f:min_$1_avg f:sma_$1_avg
	ess create variable i:fg_t i:vI1 i:vI2 s:vS1 s:vS2 f:vF1 f,+add:vF2 l:vL1 l,+add:vL2 f,+max:lmx f,+min:lmn
        # Save these definitions and send them to worker nodes if there are any
	ess server commit
}

read_from_files () {
        # Load the Database from the Raw Data File and Enhance the Data 
	ess stream EURUSD "*" "*" \
	"aq_pp -f+1 - -d s:utc f:ask f:bid f:askvol f:bidvol \
         -eval s:curr '\"EURUSD\"' -eval f:avg '(ask + bid)/2' \
         -imp,ddef demo:tick"
}

ta_lib () {
        # Calculating TALIB Features: Maximum, Minimum, Simple Moving Average
        eval "aq_udb -scn demo:tick -mod 'talib-umod(1,MAXIMUM,tick.avg,tick.max_$1_avg,$1)'"
        eval "aq_udb -scn demo:tick -mod 'talib-umod(1,MINIMUM,tick.avg,tick.min_$1_avg,$1)'"
        eval "aq_udb -scn demo:tick -mod 'talib-umod(1,SMA,tick.avg,tick.sma_$1_avg,$1)'"
}

getnexttickprice() {
        # Calculate and Store the next period (future) Tick Price
        # Reverse Data by Time (utc) Column
        ess exec "aq_udb -ord,dec demo:tick utc"

        # Scan through database, calculating and storing the next period (future) Tick Price
        tmpval=`ess exec "aq_udb -exp demo:tick -lim_rec 1 -o,notitle - -c ask"`
        ess exec "aq_udb -scn demo:tick -pp tick -bvar vF1 $tmpval -eval nextask vF1 -eval vF1 ask -endpp"
        tmpval=`ess exec "aq_udb -exp demo:tick -lim_rec 1 -o,notitle - -c bid"`
        ess exec "aq_udb -scn demo:tick -pp tick -bvar vF1 $tmpval -eval nextbid vF1 -eval vF1 bid -endpp"
        tmpval=`ess exec "aq_udb -exp demo:tick -lim_rec 1 -o,notitle - -c avg"` 
        ess exec "aq_udb -scn demo:tick -pp tick -bvar vF1 $tmpval -eval nextavg vF1 -eval vF1 '(ask+bid)/2' -endpp"

        # Reorder Data by Time (utc) Column
        ess exec "aq_udb -ord demo:tick utc"

        # Calculate and Store Difference in each tick price (ask/bid/average) to the corresponding next period tick price.        
        ess exec "aq_udb -scn demo:tick -eval delta_NaskAsk '(nextask - ask)' -eval delta_NbidBid '(nextbid - bid)' -eval delta_NavgAvg '(nextavg - avg)'" 
}

import(){
        # Call each of the previous functions in the proper order and ensure that you only install TA-Lib once
        if [ ! -e ~/mod_talib/installtalib.txt ]
        then
         setup_ta_lib
        fi
	category
	createdb 300
	read_from_files
	ta_lib 300
	getnexttickprice
}

### NEXT STEPS:

# # To analyze this demo tick data, you can create the following additional features in the Pivot Billions GUI:

# # Enter in the STANDARD tab of F(x):
#
# Label: delta_askbid
# Format: f
# Syntax: ask - bid

# Label: delta_maxmin_300
# Format: f
# Syntax: max_300_avg - min_300_avg

# # Enter in the ADVANCED tab of F(x):
#
# Label: cat_delta_askbid
# Format: i
# Column Name: cat_delta_askbid
# Syntax: -if -filt 'var_delta_askbid < (2*(ask - avg))' -eval i:cat_delta_askbid '0' -else -eval cat_delta_askbid '1' -endif

# Label: cat_delta_maxmin_300
# Format: i
# Column Name: cat_delta_maxmin_300
# Syntax: -if -filt 'var_delta_maxmin_300 <= 0.0005' -eval i:cat_delta_maxmin_300 '0' -else -eval cat_delta_maxmin_300 '1' -endif

# Once you've created these columns, select the Pivot Icon to the left of f(x). 
# Then under Dimensions click + then the box and select "cat_delta_askbid", 
# then click + then the box and select "cat_delta_maxmin_300".
# Now under Values click + then the box and select "delta_NavgAvg".
# Click View.

# You can now see the summary statistics and averages of the various categories we've created.
# It is clear that the thesholds we have set for both categories (>= 2*(ask - avg) and > 0.0005) greatly 
# improve the average increase in the tick avg price one tick into the future and that they have 
# predictive power and warrant further exploration.

# Please feel free to explore the data further using PivotBillions.
