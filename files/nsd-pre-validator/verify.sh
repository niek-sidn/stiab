#!/usr/bin/env bash
set -o errexit  # if commands fail, quit
set -o pipefail # if anything in a pipe construction fails, quit

## Some verifiers cannot use stdin from 'NSD verifier-feed-zone: yes' directly, and need an
## actual file to verify. So we direct the stdin feed from NSD to a file.
## The path may surprise you, so keep reading.
ZF=/var/lib/knot/zones/$VERIFY_ZONE.zone
echo "writing $VERIFY_ZONE to file $ZF"
cat > $ZF                                  # read from stdin to file (in memory if not on volume)
echo "writing $VERIFY_ZONE to file $ZF finished"

## start the verifing software in parallel by backgrounding, please
## note the waiting loop below the starting of the verifing software.
echo 'Starting nsd-checkzone'
nsd-checkzone $VERIFY_ZONE $ZF &
pid=$!
checkzone1_pid="${pid}"
#
echo 'Starting named-checkzone'
named-checkzone -i none $VERIFY_ZONE $ZF &   # '-i none': no post zone load checks
pid=$!
checkzone2_pid="${pid}"
#
## Validns is is a great multithreaded verifier.
echo 'Starting validns'
validns -n 8 -s $ZF &
pid=$!
validns_pid="${pid}"
#
## Now wait for all backgrounded processes to finish
for p in checkzone1_pid checkzone2_pid validns_pid
do
    if wait "${!p}"; then
        echo "Process ${p%_*} success"
    else
        # there were one or more failed processes.
	# Note: errexit and/or pipefail may have already terminated this script,
	#       so don't assume that not seeing the next output implies success.
        echo "ERROR: checking signed zonefile using ${p} failed"
        exit 1
    fi
done
echo "$0 done"
