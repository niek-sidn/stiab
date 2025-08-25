#!/usr/bin/env bash
#if [ "$HOSTNAME" == nameshed-signer ]; then
#   rm /var/lib/knot/zones/* /var/lib/knot/journal/* > /dev/null 2>&1
#fi
chown --recursive nameshed:nameshed /nameshed

# No zone file registration support yet in Nameshed, invoke dnst manually for
# now
if [ ! -f /tmp/tld.conf ]; then
    /nameshed/bin/dnst keyset -c /tmp/tld.conf create -n tld -s /tmp/tld.state

    # the name 'hsmrelay' has to match the hard-coded name in nameshed/src/manager.rs
    # the hostname "nameshed-hsm-relay" has to match the hostname assigned in
    # compose.yaml to the Nameshed-HSM-Relay container.
    # the hostname "nameshed-hsm-relay" and port 5696 have to match between
    # dnst kmip server settings and nameshed env vars.
    # the username and passwords have to match between dnst kmip server
    # settings and nameshed env vars.
    /nameshed/bin/dnst keyset -c /tmp/tld.conf kmip add-server \
        hsmrelay \
        nameshed-hsm-relay \
        --credential-store /tmp/tld.creds \
        --insecure \
        --username Nameshed \
        --password 1234 \
        --port 5696 \
        --key-label-prefix NS \
        --key-label-max-bytes 255
    /nameshed/bin/dnst keyset -c /tmp/tld.conf init
fi

# No config file parsing support yet in Nameshed, use env vars for now
export NAMESHED_HSM_RELAY_HOST="nameshed-hsm-relay"
export NAMESHED_HSM_RELAY_PORT=5696
export NAMESHED_HSM_RELAY_USERNAME=Nameshed
export NAMESHED_HSM_RELAY_PASSWORD=1234
export ZL_IN_ZONE="tld"
export ZL_XFR_IN="172.20.0.21:53" # nsd-pre-validator
# No env var support for XFR out or other config yet.
exec /nameshed/bin/nameshed --config /nameshed/etc/nameshed.conf
