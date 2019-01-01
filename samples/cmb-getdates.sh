source ~/.bashrc
arg1="$1"
simfile=""
if [ "$arg1" = "sim" ]
then
simfile="sim"
elif [[ "$arg1" = *"safety"* ]]
then
simfile="$arg1"
fi
if [ "$2" != "" ]
then
arg2=$2
fi
if [[ "$arg1" = "" || "$arg1" = "s3" || "$arg1" = "sim" || "$arg1" = "1" || "$arg1" = "2" || "$arg1" = "3" || "$arg1" = "4" || "$arg1" = *"safety"* ]]
then
 cmbdates=""
 IFS=$'\n'
 if [ "$arg1" = "1" -o "$arg1" = "2" -o "$arg1" = "3" -o "$arg1" = "4" ]
 then
   echo $simfile
   end=`expr $arg2 + 1`
   start=`expr $arg2 + 1 - $arg1`
   grabbingdates="tail -n+2 ${simfile}getdates.csv | sed -n \"$start,$end"
   grabbingdates=$grabbingdates"p\" ${simfile}getdates.csv | sed 's/,/ /g'"
   echo $grabbingdates
 else
   grabbingdates="tail -n+2 ${simfile}getdates.csv | sed 's/,/ /g'"
 fi
 for row in $(eval $grabbingdates)
 do
  IFS=$' '
  set -- $row
  if [ "$cmbdates" = "" ]
  then
   if [ "$arg1" = "sim" ]
   then
      cmbdates="(t >= ($2 _ 1000) && t <= ($3 _ 1000))"
   else
      cmbdates="(t >= $2 && t <= $3)"
   fi
   firststart=$2
  else
   if [ "$arg1" = "sim" ]
   then
      #cmbdates="$cmbdates || (t >= ($2 "'* 1000) && t <= ('"$3 "'* 1000))'
      cmbdates="$cmbdates || (t >= ($2 _ 1000) && t <= ($3 _ 1000))"
   else
      cmbdates="$cmbdates || (t >= $2 && t <= $3)"
   fi
  fi
  lastend=$3
 done
 if [ "$arg1" = "sim" ]
 then
   cmbdates="'"$cmbdates"'"
 else
   cmbdates=$cmbdates""
 fi
 echo $cmbdates
fi
