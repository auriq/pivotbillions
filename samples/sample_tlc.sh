################################################################################
# tlc.sh:  import TLC logs 
################################################################################
green_schema_2017_h1="s:vendor_id s:pickup_datetime s:dropoff_datetime s:store_and_fwd_flag s:rate_code_id s:pickup_location_id s:dropoff_location_id i:passenger_count f:trip_distance f:fare_amount s:extra s:mta_tax f:tip_amount f:tolls_amount s:ehail_fee s:improvement_surcharge f:total_amount s:payment_type s:trip_type"

udbopt=",ddef,seg=1/20"
udbopt=",ddef"

create_category () {
	ess select local
	ess category add green "/home/sampledata/TLC/green_*.csv.gz" --dateregex "_[:%Y:]-[:%m:]" --overwrite
}

createdb () {
        ess server reset ### Reset old config ###
        ess create database demo --port 0
        ess create table green s:vendor_id s,pkey:pickup_datetime s:dropoff_datetime s:store_and_fwd_flag \
		s:rate_code_id s:pickup_location_id s:dropoff_location_id  i:passenger_count f:trip_distance \
		f:fare_amount s:extra s:mta_tax f:tip_amount f:tolls_amount s:ehail_fee s:improvement_surcharge \
		f:total_amount s:payment_type s:trip_type
        ess server commit
}

import_green () {
	ess stream green 2017-01-01 2017-01-31 "aq_pp -f+1,eok,qui - -d $green_schema_2017_h1 -imp$udbopt demo:green"
}

import () {
	create_category
	createdb
	import_green
}
