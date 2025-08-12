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
nodes="rs201 rs202 rs203"
for node in $nodes
do
    echo "configuring pbm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T $node bash -c "echo \"PBM_MONGODB_URI=mongodb://${pbm_user}:${pbm_pass}@127.0.0.1:27017\" > /etc/sysconfig/pbm-agent"
    echo "restarting pbm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T $node systemctl restart pbm-agent
done

if [[ $mongo_setup_type == "psa" ]]; then
  echo "stop pbm agent for arbiter node rs203"
  docker compose -f docker-compose-rs.yaml exec -T rs203 systemctl stop pbm-agent
fi
echo
echo "configuring pmm agents"
random_number=$RANDOM
nodes="rs201 rs202 rs203"
for node in $nodes
do
    echo "configuring pmm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T -e PMM_AGENT_SETUP_NODE_NAME=${node}._${random_number} $node pmm-agent setup
    if [[ $mongo_setup_type == "psa" && $node == "rs203"  ]]; then
      docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --cluster=replicaset --replication-set=rs1 ${node}_${random_number} 127.0.0.1:27017
    else
      docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --cluster=replicaset --replication-set=rs1 --username=${pmm_mongo_user} --password=${pmm_mongo_user_pass} ${node}_${random_number} 127.0.0.1:27017

      if [[ $gssapi_enabled == "true" ]]; then
        docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --enable-all-collectors --agent-password=mypass --cluster=replicaset --replication-set=rs --username=${gssapi_username} --password=${gssapi_password} --authentication-mechanism=GSSAPI --authentication-database="$external" --host=${node} --port=27017 ${node}_gssapi_${random_number}
      fi
    fi
done
