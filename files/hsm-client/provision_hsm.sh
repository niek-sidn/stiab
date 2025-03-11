#!/usr/bin/env bash
# NetHSM needs provisioning:
# - Admin user & password, Unlock password, set systemtime
# - Set unattended boot so NetHSM starts without interaction (without unlocking)
# - Operator user & pass, Metrics user & pass, Backup user & pass
# - Encryption password for backup files
# All vars below originate in /root/hsm_env_vars

if [ -f /root/hsm_env_vars ]; then
    . /root/hsm_env_vars
fi

STATE=''
while [[ ${STATE} == '' ]]; do
  STATE=$(curl --silent --insecure https://${NETHSM_HOST}/api/v1/health/state | jq -r '.state')
  sleep 1
done;

if [[ ${STATE} == "Unprovisioned" ]]; then
  echo "$(date) Provisioning NetHSM"
  curl -s --insecure -X 'POST' "https://${NETHSM_HOST}/api/v1/provision" \
  -H 'accept: */*' -H 'Content-Type: application/json' \
  -d '{"unlockPassphrase": "'${UNLOCKPASS}'", "adminPassphrase": "'${ADMINPASS}'", "systemTime": "'$(date +%FT%TZ)'"}'
  curl -s --user "admin:${ADMINPASS}" --insecure -X 'PUT' "https://${NETHSM_HOST}/api/v1/config/unattended-boot" \
  -H 'accept: */*' -H 'Content-Type: application/json' \
  -d '{"status": "on"}'
  curl -s --user "admin:${ADMINPASS}" --insecure -X 'PUT' "https://${NETHSM_HOST}/api/v1/users/operator" \
  -H 'accept: */*' -H 'Content-Type: application/json' \
  -d '{"realName": "Nitrokey Operator", "role": "Operator", "passphrase": "'${OPERATORPASS}'"}'
  curl -s --user "admin:${ADMINPASS}" --insecure -X 'PUT' "https://${NETHSM_HOST}/api/v1/users/metrics" \
  -H 'accept: */*' -H 'Content-Type: application/json' \
  -d '{"realName": "Nitrokey Metrics", "role": "Metrics", "passphrase": "'${METRICSPASS}'"}'
  curl -s --user "admin:${ADMINPASS}" --insecure -X 'PUT' "https://${NETHSM_HOST}/api/v1/users/backup" \
  -H 'accept: */*' -H 'Content-Type: application/json' \
  -d '{"realName": "Nitrokey Backup", "role": "Backup", "passphrase": "'${BACKUPPASS}'"}'
  curl -s --user "admin:${ADMINPASS}" --insecure -X 'PUT' "https://${NETHSM_HOST}/api/v1/config/backup-passphrase" \
  -H 'accept: */*' -H 'Content-Type: application/json' \
  -d '{"newPassphrase": "t0P$eCr3Tz", "currentPassphrase": ""}'
fi

STATE=$(curl --silent --insecure https://${NETHSM_HOST}/api/v1/health/state | jq -r '.state')
echo "$(date) HSM state: ${STATE}"
