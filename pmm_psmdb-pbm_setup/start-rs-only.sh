#!/bin/bash
#set -e

profile=${COMPOSE_PROFILES:-classic}
mongo_setup_type=${MONGO_SETUP_TYPE:-pss}
ol_version=${OL_VERSION:-9}

docker network create qa-integration || true
docker network create pmm-qa || true
docker network create pmm-ui-tests_pmm-network || true
docker network create pmm2-upgrade-tests_pmm-network || true
docker network create pmm2-ui-tests_pmm-network || true

export COMPOSE_PROFILES=${profile}
export MONGO_SETUP_TYPE=${mongo_setup_type}
export OL_VERSION=${ol_version}

docker compose -f docker-compose-rs.yaml down -v --remove-orphans
docker compose -f docker-compose-rs.yaml build --no-cache
docker compose -f docker-compose-rs.yaml up -d
echo
echo "waiting 60 seconds for replica set members to start"
sleep 60
echo

docker ps --format "{{.Names}}" | grep '^rs'
PLAYBOOK_FILE="install_pmm_client.yml"
cat > "$PLAYBOOK_FILE" <<EOF
- hosts: localhost
  connection: local
  tasks:
    - include_tasks: ../pmm_qa/tasks/install_pmm_client.yml
EOF

echo "Generated $PLAYBOOK_FILE. You can now run:"
echo "ansible-playbook $PLAYBOOK_FILE"
echo "PMM Client version is: $PMM_CLIENT_VERSION"

for c in $(docker ps --format "{{.Names}}" | grep '^rs'); do
    echo "Container: $c"
    ansible_out=$(ansible-playbook install_pmm_client.yml -i localhost, --connection=local -e "container_name=$c pmm_server_ip=$PMM_SERVER_IP client_version=$PMM_CLIENT_VERSION admin_password=$ADMIN_PASSWORD" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Ansible failed for $c:"
        echo "$ansible_out"
      fi
  docker exec "$c" pmm-admin list
done

if [ $mongo_setup_type == "pss" ]; then
  bash -e ./configure-replset.sh
else
  bash -e ./configure-psa.sh
fi
bash -x ./configure-agents.sh

if [ $profile = "extra" ]; then
  if [ $mongo_setup_type == "pss" ]; then
    bash -x ./configure-extra-replset.sh
  else
    bash -x ./configure-extra-psa.sh
  fi
  bash -x ./configure-extra-agents.sh
fi
