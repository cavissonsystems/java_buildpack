var1=$(vmstat 1 2|tail -1|awk '{print $15}')
val=`expr 100 - $var1`
echo $val
