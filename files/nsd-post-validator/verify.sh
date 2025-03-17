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
## kzonesign -v is a great multithreaded verifier, but it takes some work:
## a) it cannot take the zonefile on stdin (that is taken care of above with 'cat >').
## b) it takes its config from a configfile. By default /etc/knot/knot.conf.
## To solve b) and avoid maintaining two knot.conf files, this nsd-post-validator
## gets the official knot.conf from knot-signer, by volume in compose.yml.
## This way it gets the correct dnssec policy, but also the same number of
## signing-threads as knot-signer (which you may like or not) and also the
## same path to the zonefile as knot-signer (which is a bit awkward). Hence the
## surprising /var/lib/knot/zones/... path above.
echo 'Starting kzonesign -v'
kzonesign -v $VERIFY_ZONE &
pid=$!
kzonesign_pid="${pid}"
#
## Validns is is a great multithreaded verifier.
echo 'Starting validns'
validns -n 8 -s $ZF &
pid=$!
validns_pid="${pid}"
#
## Now wait for all backgrounded processes to finish
for p in kzonesign_pid checkzone1_pid checkzone2_pid validns_pid
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
