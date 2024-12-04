#!/usr/bin/env bash
set -o errexit
set -o pipefail
## Some verifiers cannot use stdin directly, and need an actual file to verify
## kzonesign -v is such a verifier, but it is too good to ignore (verifies at 1200% CPU in stead of 100%!)
## To accomodate kzonesign we direct the stdin feed from nsd to the path dictated by knot.conf
## (this is the actual knot.conf used by knot-signer shared in by volume)
ZF=/var/lib/knot/zones/$VERIFY_ZONE.zone   # path is dictated by /etc/knot/knot.conf, VERIFY_ZONE provided by NSD
cat > $ZF                                  # read from stdin (nsd: verifier-feed-zone: yes) to file (in memory if not on volume)
kzonesign -v $VERIFY_ZONE                  # will use 'policy' and 'signing-threads'(!) and 'file' settings from /etc/knot/knot.conf
## Others can use it too
nsd-checkzone $VERIFY_ZONE $ZF
##
named-checkzone -i local-sibling $VERIFY_ZONE $ZF
