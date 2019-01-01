########################################################################
## sample_tdb.sh: Empowering Quick, Massive Simulation of Financial Data
########################################################################

setup_ta_lib() {
 bash ~/mod_talib/installtalib.sh &>~/mod_talib/installtalib.txt
 if [[ `grep "All tests succeeded" ~/mod_talib/installtalib.txt | wc -l` == 0 ]]
 then
  cat ~/mod_talib/installtalib.txt &>>task.log
  exit
 fi
}

category() {
	ess select local
	ess category add EURUSD "/home/sampledata/Financial/EURUSD_Ticks_*.zip" --overwrite
}

createdb () {
        # Define Minute and Hour Aggregations and Features
        ess server reset ### Reset old config ###
        ess create database ohlc --port 0
        # Define a Minute-Aggregated Table
        ess create table bymin s,pkey:curr s,+key:minute f,+first:open f,+max:high f,+min:low f:close f:nextclose f,+add:vol l:t f:max_$1_close f:min_$1_close f:linreg_angle_$2 i:entrysignal
        # Define a Hour-Aggregated Table
        ess create table byhour s,pkey:curr s,+key:hour f,+first:open f,+max:high f,+min:low f:close f:nextclose f,+add:vol l:t f:max_$1_close f:min_$1_close f:linreg_angle_$2 i:entrysignal
        ess create variable i:fg_t i:vI1 i:vI2 s:vS1 s:vS2 f:vF1 f,+add:vF2 l:vL1 l,+add:vL2 f,+max:lmx f,+min:lmn
        # Save these definitions and send them to any worker nodes if you have them
        ess server commit
}

read_from_files () {
        # Stop any existing Time Series Databases and Start a new Time Series Database using the US/Eastern Timezone
        tdb_ctl stop
        TZ=US/Eastern tdb_ctl start

        # Filter out the data near market close to prevent low liquidity trades
        filtertimes=`bash funcs.custom/additionalfiles/cmb-getdates.sh funcs.custom/additionalfiles/safety`
        if [ -z "$filtertimes" ]
        then
         echo "Failed to filter out low liquidity trades, allowing all data" &>>/home/ess/task.log
         filtertimes="t>0"
        fi

        # Load the Time Series Database (tdb) from the Raw Data File, Enhance the Data, and Aggregate the Data by Minute and by Hour
        ess stream EURUSD "*" "*" \
        "TZ='GMT' aq_pp -f+1 - -d s:utc f:ask f:bid f:askvol f:bidvol -eval s:curr '\"EURUSD\"' \
         -eval s:minute 'SubStr(utc,0,16)'  -eval s:hour 'SubStr(utc,0,13)' -eval f:price '(ask + bid)/2' \
         -eval f:open price -eval f:high price -eval f:low price -eval f:close price -eval f:vol askvol \
         -eval l:t 'DateToTime(minute,\"%Y.%m.%d.%H.%M\")+60' \
         -if -filt '$filtertimes' \
         -imp,ddef ohlc:bymin -imp,ddef ohlc:byhour -endif \
         -eval s:DateToS 'ClipStr(utc,\"3->.\")' -eval s:milliseconds 'ClipStr(utc,\"1-<.\")' \
         -eval t 'DateToTime(DateToS,\"%Y.%m.%d.%H.%M.%S\")*1000+ToI(milliseconds)' \
         -o,notitle - -c t bid ask | tdb -imp - -db EURUSD"

        # Check the total number of rows imported into each database 
        # Tick Time-Series Data
        tdb -inf -db EURUSD
        # Minute-Aggregated Data
        ess exec "aq_udb -cnt ohlc:bymin"
        # Hour-Aggregated Data
        ess exec "aq_udb -cnt ohlc:byhour"
}

ta_lib () {
        # Calculating TALIB Features: Maximum, Minimum, and Linear Regression Angle by Minute and by Hour
        eval "aq_udb -scn ohlc:bymin -mod 'talib-umod(1,MAXIMUM,bymin.close,bymin.max_$1_close,$1)'"
        eval "aq_udb -scn ohlc:bymin -mod 'talib-umod(1,MINIMUM,bymin.close,bymin.min_$1_close,$1)'"
        eval "aq_udb -scn ohlc:bymin -mod 'talib-umod(1,LINEARREG_ANGLE,bymin.close,bymin.linreg_angle_$2,$2)'"
        eval "aq_udb -scn ohlc:byhour -mod 'talib-umod(1,MAXIMUM,byhour.close,byhour.max_$1_close,$1)'"
        eval "aq_udb -scn ohlc:byhour -mod 'talib-umod(1,MINIMUM,byhour.close,byhour.min_$1_close,$1)'"
        eval "aq_udb -scn ohlc:byhour -mod 'talib-umod(1,LINEARREG_ANGLE,byhour.close,byhour.linreg_angle_$2,$2)'"
}

getnextclose() {
        # Calculate and Store the next period (future) Minute and Hour Prices

        # Reverse Data by Time (minute) Column
        ess exec "aq_udb -ord,dec ohlc:bymin minute"
        # Scan through database, calculating and storing the next period (future) Minute Price
        tmpval=`ess exec "aq_udb -exp ohlc:bymin -lim_rec 1 -o,notitle - -c nextclose"`
        ess exec "aq_udb -scn ohlc:bymin -pp bymin -bvar vF1 $tmpval -eval nextclose vF1 -eval vF1 close -endpp"
        # Reorder Data by Time (minute) Column
        ess exec "aq_udb -ord ohlc:bymin minute"

        # Reverse Data by Time (hour) Column
        ess exec "aq_udb -ord,dec ohlc:byhour hour"
        # Scan through database, calculating and storing the next period (future) Hour Price
        tmpval=`ess exec "aq_udb -exp ohlc:byhour -lim_rec 1 -o,notitle - -c nextclose"`
        ess exec "aq_udb -scn ohlc:byhour -pp byhour -bvar vF1 $tmpval -eval nextclose vF1 -eval vF1 close -endpp"
        # Reorder Data by Time (hour) Column
        ess exec "aq_udb -ord ohlc:byhour hour"
}

gensignals() {
        # Generate Entry Signals for Your Model
        ess exec "aq_udb -scn ohlc:bymin -if -filt 'vol!=0 && (close == min_$1_close && linreg_angle_$2 <= 0.0) && max_$1_close - min_$1_close > (high - low)*5 && max_$1_close - min_$1_close < (high - low)*10' -eval entrysignal '21' -elif -filt 'vol!=0 && (close == max_$1_close && linreg_angle_$2 >= 0.006) && max_$1_close - min_$1_close > (high - low)*5 && max_$1_close - min_$1_close < (high - low)*10' -eval entrysignal '12' -endif"
}

import(){
        if [ ! -e ~/mod_talib/installtalib.txt ]
        then
         setup_ta_lib
        fi
      	category
      	createdb 80 10
      	read_from_files
      	ta_lib 80 10
        getnextclose
        gensignals 80 10
}
