#!/usr/bin/env bash
if [ "$HOSTNAME" != nsd-zoneloader ]; then
   rm /var/lib/stiab/zones/* > /dev/null 2>&1
fi
rm /var/lib/stiab/zones/*.ixfr > /dev/null 2>&1
nsd -d
