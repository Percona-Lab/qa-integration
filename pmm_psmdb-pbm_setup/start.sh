#!/bin/bash
docker-compose -f docker-compose-rs.yaml down -v --remove-orphans
docker-compose -f docker-compose-rs.yaml up -d
echo "waiting 30 seconds for pmm-server to start"
sleep 30
docker-compose -f docker-compose-rs.yaml exec pmm-client pmm-agent setup
docker-compose -f docker-compose-rs.yaml exec pmm-client pmm-admin add mongodb --replication-set=rs1 rs101 rs101:27017
docker-compose -f docker-compose-rs.yaml exec pmm-client pmm-admin add mongodb --replication-set=rs1 rs102 rs102:27017
docker-compose -f docker-compose-rs.yaml exec pmm-client pmm-admin add mongodb --replication-set=rs1 rs103 rs103:27017
