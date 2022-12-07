#!/bin/bash
docker-compose -f docker-compose-rs.yaml down -v --remove-orphans
docker-compose -f docker-compose-rs.yaml build
docker-compose -f docker-compose-rs.yaml up -d
echo "waiting 30 seconds for pmm-server to start"
sleep 30
echo "configuring pmm-server"
docker-compose -f docker-compose-rs.yaml exec -T pmm-server change-admin-password password
echo "configuring pbm"
docker-compose -f docker-compose-rs.yaml exec -T rs101 pbm config --file=/etc/pbm/minio.yaml
echo "configuring pmm agents"
docker-compose -f docker-compose-rs.yaml exec -T rs101 pmm-agent setup
docker-compose -f docker-compose-rs.yaml exec -T rs101 pmm-admin add mongodb --replication-set=rs rs101 127.0.0.1:27017
docker-compose -f docker-compose-rs.yaml exec -T rs102 pmm-agent setup
docker-compose -f docker-compose-rs.yaml exec -T rs102 pmm-admin add mongodb --replication-set=rs rs102 127.0.0.1:27017
docker-compose -f docker-compose-rs.yaml exec -T rs103 pmm-agent setup
docker-compose -f docker-compose-rs.yaml exec -T rs103 pmm-admin add mongodb --replication-set=rs rs103 127.0.0.1:27017
echo "running tests"
docker-compose -f docker-compose-rs.yaml run test pytest -s -x --verbose test.py
docker-compose -f docker-compose-rs.yaml down -v --remove-orphans
