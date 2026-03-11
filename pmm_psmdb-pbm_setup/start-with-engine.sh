#!/bin/bash
set -euo pipefail

engine_raw="${ENGINE:-wiredTiger}"
setup_type_raw="${MONGO_SETUP_TYPE:-pss}"

engine="$(echo "${engine_raw}" | tr '[:upper:]' '[:lower:]')"
setup_type="$(echo "${setup_type_raw}" | tr '[:upper:]' '[:lower:]')"

base_script=""

case "${setup_type}" in
  pss|psa)
    base_script="start-rs-only.sh"
    ;;
  shards|sharding)
    base_script="start-sharded-no-server.sh"
    ;;
  *)
    echo "Unsupported MONGO_SETUP_TYPE '${setup_type_raw}'. Expected: pss, psa, shards, sharding."
    exit 1
    ;;
esac

if [[ ! -f "${base_script}" ]]; then
  echo "Required setup script '${base_script}' not found in $(pwd)."
  if [[ "${setup_type}" == "shards" || "${setup_type}" == "sharding" ]]; then
    echo "For sharding, generate '${base_script}' first using the existing pmm framework flow."
  fi
  exit 1
fi

case "${engine}" in
  wiredtiger|wired_tiger|inmemory|in_memory)
    exec bash "./${base_script}" "$@"
    ;;
  *)
    echo "Unsupported ENGINE '${engine_raw}'. Expected: wiredTiger or inmemory."
    exit 1
    ;;
esac
