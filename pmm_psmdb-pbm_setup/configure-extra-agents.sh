#!/bin/bash
set -e

pmm_mongo_user=${PMM_MONGO_USER:-pmm}
pmm_mongo_user_pass=${PMM_MONGO_USER_PASS:-pmmpass}
pbm_user=${PBM_USER:-pbm}
pbm_pass=${PBM_PASS:-pbmpass}

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
echo
echo "configuring pmm agents"
nodes="rs201 rs202 rs203"
for node in $nodes
do
    echo "configuring pmm agent on $node"
    docker compose -f docker-compose-rs.yaml exec -T $node pmm-agent setup
    docker compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --cluster=replicaset1 --replication-set=rs1 --username=${pmm_mongo_user} --password=${pmm_mongo_user_pass} $node 127.0.0.1:27017
done
echo
