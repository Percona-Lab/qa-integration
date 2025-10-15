#!/bin/bash

# REPO - repo for PSMDB/PBM packages, by default - testing
# PMM_REPO - repo for PMM packages, by default - experimental
# PBM_VERSION - PBM version, by default - latest
# PSMDB_VERSION - PSMDB version, by default - latest
# PMM_CLIENT_VERSION - PMM client version, by default - latest
# PMM_IMAGE - PMM server version, by default - perconalab/pmm-server:dev-latest
# AWS_USERNAME - username of AWS user whose creds are provided, AWS auth tests are skipped unless creds are provided
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY - self-descriptive
# TESTS - whether to run tests, by default - yes
# CLEANUP - whether to remove setup, by default - yes

#set -e

# PSMDB 4.2 doesn't support AWS auth
if [[ -n "$PSMDB_VERSION" ]] && [[ "$PSMDB_VERSION" == *"4.2."* ]]; then
    sed -i 's/,MONGODB-AWS//' conf/mongod.conf
    export SKIP_AWS_TESTS="true"
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    export ADMIN_PASSWORD=admin
fi

bash -e ./generate-certs.sh

echo "Start setup"
docker compose -f docker-compose-pmm-psmdb.yml down -v --remove-orphans
docker compose -f docker-compose-pmm-psmdb.yml build
docker compose -f docker-compose-pmm-psmdb.yml up -d

echo "Add users"
docker compose -f docker-compose-pmm-psmdb.yml exec -T psmdb-server mongo --quiet << EOF
db.getSiblingDB("admin").createUser({ user: "root", pwd: "root", roles: [ "root", "userAdminAnyDatabase", "clusterAdmin" ] });
EOF
docker compose -f docker-compose-pmm-psmdb.yml exec -T psmdb-server mongo --quiet "mongodb://root:root@localhost/?replicaSet=rs0" < init/setup_psmdb.js

echo "Configure PBM"
docker compose -f docker-compose-pmm-psmdb.yml exec -T psmdb-server bash -c "echo \"PBM_MONGODB_URI=mongodb://pbm:pbmpass@127.0.0.1:27017\" > /etc/sysconfig/pbm-agent"
docker compose -f docker-compose-pmm-psmdb.yml exec -T psmdb-server systemctl restart pbm-agent

echo "Install PMM Client"

PLAYBOOK_FILE="install_pmm_client.yml"
cat > "$PLAYBOOK_FILE" <<EOF
- hosts: localhost
  connection: local
  tasks:
    - include_tasks: ../pmm_qa/tasks/install_pmm_client.yml
EOF

ansible_out=$(ansible-playbook install_pmm_client.yml -i localhost, --connection=local -e "container_name=psmdb-server pmm_server_ip=$PMM_SERVER_IP client_version=$PMM_CLIENT_VERSION admin_password=$ADMIN_PASSWORD" 2>&1)
exit 1
if [ $? -ne 0 ]; then
    echo "Ansible failed for: psmdb-server"
    echo "$ansible_out"
    exit 1
fi

echo "Add Mongo Service"
random_number=$RANDOM
docker compose -f docker-compose-pmm-psmdb.yml exec -T psmdb-server pmm-admin add mongodb psmdb-server_${random_number} --agent-password=mypass --username=pmm_mongodb --password="5M](Q%q/U+YQ<^m" --host psmdb-server --port 27017 --tls --tls-certificate-key-file=/mongodb_certs/client.pem --tls-ca-file=/mongodb_certs/ca-certs.pem --cluster=mycluster

echo "Add some data"
docker exec psmdb-server wget -O mgodatagen_linux_amd64.tar.gz https://github.com/feliixx/mgodatagen/releases/download/v0.12.0/mgodatagen_0.12.0_darwin_amd64.tar.gz
docker exec psmdb-server tar -xzf mgodatagen_linux_amd64.tar.gz
docker exec psmdb-server mv mgodatagen /usr/local/bin/
docker exec psmdb-server chmod +x /usr/local/bin/mgodatagen
docker exec psmdb-server mgodatagen -f /etc/datagen/replicaset.json --username=pmm_mongodb --password="5M](Q%q/U+YQ<^m" --host psmdb-server --port 27017 --tlsCertificateKeyFile=/mongodb_certs/client.pem --tlsCAFile=/mongodb_certs/ca-certs.pem

tests=${TESTS:-yes}
if [ $tests = "yes" ]; then
    echo "running tests"
    output=$(docker compose -f docker-compose-pmm-psmdb.yml run test pytest -s --verbose test.py)
    else
    echo "skipping tests"
fi

cleanup=${CLEANUP:-yes}
if [ $cleanup = "yes" ]; then
    echo "cleanup"
    docker compose -f docker-compose-pmm-psmdb.yml down -v --remove-orphans
    if [[ -n "$PSMDB_VERSION" ]] && [[ "$PSMDB_VERSION" == *"4.2"* ]]; then
       sed -i 's/MONGODB-X509/MONGODB-X509,MONGODB-AWS/' conf/mongod.conf
    fi
    else
    echo "skipping cleanup"
fi

echo "$output"
if echo "$output" | grep -q "\bFAILED\b"; then
    exit 1
fi
