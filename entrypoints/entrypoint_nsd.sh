#!/usr/bin/env bash
if [ "$HOSTNAME" != nsd-zoneloader ]; then
   rm /var/lib/stiab/zones/* > /dev/null 2>&1
fi
rm /var/lib/stiab/zones/*.ixfr > /dev/null 2>&1

if [ "$HOSTNAME" == nsd-post-validator ]; then
   # Needed when nsd verify is used in combination with
   # verifier that uses actual knot-signer's knot.conf, e.g. ksignzone -v
   # Ksignzone also needs
   # - knot-dnssecutils (Dockerfile_nsd)
   # - volume files/knot-signer/knot.conf:/etc/knot/knot.conf:ro (compose.yml)
   # - verifier script that provides workaround for missing zonefile (files/nsd-post-validator/verify.sh)
   mkdir -p /var/lib/knot/zones/
fi
exec nsd -d
