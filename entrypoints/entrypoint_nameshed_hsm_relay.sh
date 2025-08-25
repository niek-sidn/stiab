#!/usr/bin/env bash
#if [ "$HOSTNAME" == nameshed-signer ]; then
#   rm /var/lib/knot/zones/* /var/lib/knot/journal/* > /dev/null 2>&1
#fi
chown --recursive nameshed:nameshed /nameshed
/nameshed/bin/keyls pkcs11:Nameshed:1234@/lib/softhsm/libsofthsm2.so

exec /nameshed/bin/nameshed-hsm-relay --config /nameshed/etc/relay.conf
