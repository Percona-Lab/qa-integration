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
random_number=$RANDOM
nodes="rs101 rs102 rs103"
for node in $nodes
do
    echo "congiguring pmm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T -e PMM_AGENT_SETUP_NODE_NAME=${node}._${random_number} $node pmm-agent setup
    if [[ $mongo_setup_type == "psa" && $node == "rs103" ]]; then
      docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --cluster=replicaset --replication-set=rs ${node}_${random_number} 127.0.0.1:27017
    else
      docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --cluster=replicaset --replication-set=rs --username=${pmm_mongo_user} --password=${pmm_mongo_user_pass} ${node}_${random_number} 127.0.0.1:27017

      if [[ $gssapi_enabled == "true" ]]; then
        docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --cluster=replicaset --replication-set=rs --username=${gssapi_username} --password=${gssapi_password} --authentication-mechanism=GSSAPI --authentication-database="$external" --host=${$node} --port=27017 ${node}_gssapi_${random_number}
      fi
    fi
done
echo
echo "adding some data"
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
