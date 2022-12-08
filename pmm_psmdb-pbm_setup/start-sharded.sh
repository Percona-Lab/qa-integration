#!/bin/bash
docker-compose -f docker-compose-sharded.yaml down -v --remove-orphans
docker-compose -f docker-compose-sharded.yaml build
docker-compose -f docker-compose-sharded.yaml up -d
echo "waiting 60 seconds for sharded-cluster and pmm-server to start"
sleep 60
echo "configuring pmm-server"
docker-compose -f docker-compose-sharded.yaml exec -T pmm-server change-admin-password password
echo "configuring pbm-agents and pmm-agents"
nodes="rs101 rs102 rs103 rs201 rs202 rs203 rscfg01 rscfg02 rscfg03"
for node in $nodes
do
    echo "restarting pbm agent on $node"
    docker-compose -f docker-compose-sharded.yaml exec -T $node systemctl restart pbm-agent
    echo "congiguring pmm agent on $node"
    docker-compose -f docker-compose-sharded.yaml exec -T $node pmm-agent setup
    rs=$(echo $node | awk -F "0" '{print $1}')
    docker-compose -f docker-compose-sharded.yaml exec -T $node pmm-admin add mongodb --replication-set=$rs --cluster=sharded $node 127.0.0.1:27017
done
#echo "running tests"
#docker-compose -f docker-compose-sharded.yaml run test pytest -s -x --verbose test.py
#docker-compose -f docker-compose-sharded.yaml down -v --remove-orphans
