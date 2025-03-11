#!/usr/bin/env bash
echo "$(date) Starting HSM client"
echo "$(date) Checking if HSM provisioned"
/root/provision_hsm.sh
echo "$(date) Ready, awaiting logins"
exec sleep infinity
