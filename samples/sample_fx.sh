########################################################
## sample_fx.sh: a financial data analysis 
#####################################################################

import(){
	category
	createdb
	read_from_files
}

category() {
	ess select local
	ess category add EURUSD "/home/sampledata/Financial/EURUSD_Ticks_*.zip" --overwrite
}

createdb () {
	ess server reset ### Reset old config ###
	ess create database demo --port 0
	ess create table tick s,pkey:utc f:ask f:bid f:askvol f:bidvol 
	ess create database ohlc --port 0
	ess create vector bymin s,pkey:minute f,+first:open f,+max:high f,+min:low f:close f,+add:vol
	ess server commit
}

read_from_files () {
	ess stream EURUSD "*" "*" \
	"aq_pp -f+1 - -d s:utc f:ask f:bid f:askvol f:bidvol -imp demo:tick \
	-eval s:minute 'SubStr(utc,0,16)' -eval f:price ask*100 \
        -eval f:open price -eval f:high price -eval f:low price -eval f:close price -eval f:vol askvol -imp,ddef ohlc:bymin"
	#
}
