#!/bin/bash
set -euo pipefail

engine_raw="${ENGINE:-wiredTiger}"
replset_name="${REPLSET_NAME:-rs}"
shard_role="${SHARD_ROLE:-}"

engine="$(echo "${engine_raw}" | tr '[:upper:]' '[:lower:]')"
target_conf="/tmp/mongod.dynamic.conf"
sysconfig_file="/etc/sysconfig/mongod"

case "${engine}" in
  wiredtiger|wired_tiger)
    storage_block="$(cat <<'EOF'
storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
EOF
)"
    ;;
  inmemory|in_memory)
    storage_block="$(cat <<'EOF'
storage:
  dbPath: /var/lib/mongo
  engine: inMemory
  inMemory:
    engineConfig:
      inMemorySizeGB: 1
EOF
)"
    ;;
  *)
    echo "Unsupported ENGINE '${engine_raw}'. Expected: wiredTiger or inmemory." >&2
    exit 1
    ;;
esac

{
  printf "%s\n\n" "${storage_block}"
  cat <<EOF
systemLog:
  destination: syslog

net:
  port: 27017
  bindIp: 0.0.0.0

replication:
  replSetName: "${replset_name}"
EOF
  if [[ -n "${shard_role}" ]]; then
    cat <<EOF

sharding:
  clusterRole: ${shard_role}
EOF
  fi
  cat <<'EOF'

operationProfiling:
  mode: all
  slowOpThresholdMs: 1

security:
  keyFile: /etc/keyfile
  authorization: enabled
setParameter:
  authenticationMechanisms: SCRAM-SHA-1,GSSAPI
EOF
} > "${target_conf}"

if [[ -f "${sysconfig_file}" ]]; then
  sed -i "s|^OPTIONS=.*|OPTIONS=\"-f ${target_conf}\"|" "${sysconfig_file}"
else
  echo "OPTIONS=\"-f ${target_conf}\"" > "${sysconfig_file}"
fi
