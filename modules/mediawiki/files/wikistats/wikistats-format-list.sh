#!/bin/bash

while read line
do
	wiki=`echo $line | cut -d "|" -f1`
	echo ${wiki%????}
done < $1
