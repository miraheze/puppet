#!/bin/bash

while read line
do
	wiki=`/bin/echo $line | /usr/bin/cut -d "|" -f1`
	/bin/echo ${wiki%????}
done < $1
