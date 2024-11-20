#!/usr/bin/env bash
if [ "$HOSTNAME" != knot-fakeroot ]; then
   rm /var/lib/knot/zones/* /var/lib/knot/journal/* > /dev/null 2>&1
fi
chown --recursive knot:knot /run/knot/ /var/lib/knot /etc/knot
knotd
