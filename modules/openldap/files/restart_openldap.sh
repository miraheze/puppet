#!/bin/bash
# restart slapd if it uses more than 50% of memory
mem_usage=$(ps -C slapd -o pmem=|awk '{sum+=$1} END {print sum}')

if [[ (($mem_usage > 50.0)) ]]; then
  /bin/systemctl restart slapd
fi
