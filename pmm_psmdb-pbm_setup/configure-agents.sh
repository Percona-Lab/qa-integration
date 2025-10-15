#!/bin/bash
set -e

pmm_mongo_user=${PMM_MONGO_USER:-pmm}
pmm_mongo_user_pass=${PMM_MONGO_USER_PASS:-pmmpass}
pbm_user=${PBM_USER:-pbm}
pbm_pass=${PBM_PASS:-pbmpass}
mongo_setup_type=${MONGO_SETUP_TYPE:-pss}
gssapi_enabled=${GSSAPI:-false}
gssapi_username=${GSSAPI_USERNAME:-pmm@PERCONATEST.COM}
gssapi_password=${GSSAPI_PASSWORD:-password1}
client_credentials_flags="--username=${pmm_mongo_user} --password=${pmm_mongo_user_pass}"
gssapi_service_name_part=""

if [[ $gssapi_enabled == "true" ]]; then
    client_credentials_flags=(
      --username="$gssapi_username"
      --password="$gssapi_password"
      --authentication-mechanism=GSSAPI
      --authentication-database='$external'
    )
  gssapi_service_name_part="_gssapi"
fi

echo
echo "gssapi enabled: $gssapi_enabled. Using credentials: ${client_credentials_flags[*]}"

echo
echo "configuring pbm agents"
nodes="rs101 rs102 rs103"
for node in $nodes
do
    echo "congiguring pbm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T $node bash -c "echo \"PBM_MONGODB_URI=mongodb://${pbm_user}:${pbm_pass}@127.0.0.1:27017\" > /etc/sysconfig/pbm-agent"
    echo "restarting pbm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T $node systemctl restart pbm-agent
done

docker compose -f docker-compose-rs.yaml exec -T rs101 pbm config --file /etc/pbm/minio.yaml

if [[ $mongo_setup_type == "psa" ]]; then
  echo "stop pbm agent for arbiter node"
  docker compose -f docker-compose-rs.yaml exec -T rs103 systemctl stop pbm-agent
fi
echo
echo "configuring pmm agents"
PLAYBOOK_FILE="install_pmm_client.yml"
cat > "$PLAYBOOK_FILE" <<EOF
- hosts: localhost
  connection: local
  tasks:
    - include_tasks: ../pmm_qa/tasks/install_pmm_client.yml
EOF

if [ -z "${PMM_SERVER_IP+x}" ]; then
    PMM_SERVER_IP="pmm-server"
fi

if [ -z "${ADMIN_PASSWORD+x}" ]; then
    ADMIN_PASSWORD="admin"
fi

echo "PMM Server IP is: $PMM_SERVER_IP"
echo "PMM Client version is: $PMM_CLIENT_VERSION"
echo "Admin Password is: $ADMIN_PASSWORD"
ansible_out=$(ansible-playbook install_pmm_client.yml -vvv --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 -e "container_name=psmdb-server pmm_server_ip=$PMM_SERVER_IP client_version=$PMM_CLIENT_VERSION admin_password=$ADMIN_PASSWORD" 2>&1)

random_number=$RANDOM
nodes="rs101 rs102 rs103"
for node in $nodes
do
    echo "configuring pmm agent on $node"
    if [[ $mongo_setup_type == "psa" && $node == "rs103" ]]; then
      docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --environment=psmdb-dev --cluster=replicaset --replication-set=rs --host=${node} --port=27017 ${node}${gssapi_service_name_part}_${random_number}
    else
      echo
      docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --environment=psmdb-dev --cluster=replicaset --replication-set=rs ${client_credentials_flags[*]} --host=${node} --port=27017 ${node}${gssapi_service_name_part}_${random_number}
    fi
done
echo
echo "adding some data"
docker exec rs101 wget -O mgodatagen_linux_amd64.tar.gz https://github.com/feliixx/mgodatagen/releases/download/v0.12.0/mgodatagen_0.12.0_darwin_amd64.tar.gz
docker exec rs101 tar -xzf mgodatagen_linux_amd64.tar.gz
docker exec rs101 mv mgodatagen /usr/local/bin/
docker exec rs101 chmod +x /usr/local/bin/mgodatagen
docker compose -f docker-compose-rs.yaml exec -T rs101 mgodatagen -f /etc/datagen/replicaset.json --uri=mongodb://${pmm_mongo_user}:${pmm_mongo_user_pass}@127.0.0.1:27017/?replicaSet=rs
docker compose -f docker-compose-rs.yaml exec -T rs101 mongo "mongodb://${pmm_mongo_user}:${pmm_mongo_user_pass}@localhost/?replicaSet=rs" --quiet << EOF
use students;
db.students.insertMany([
  {
    sID: 22001, name: 'Alex', year: 1, score: 4.0,
  },
  {
    sID: 21001, name: 'bernie', year: 2, score: 3.7,
  },
  {
    sID: 20010, name: 'Chris', year: 3, score: 2.5,
  },
  {
    sID: 22021, name: 'Drew', year: 1, score: 3.2,
  },
]);

db.createView( 'firstYears', 'students', [{ \$match: { year: 1 } }]);
EOF
