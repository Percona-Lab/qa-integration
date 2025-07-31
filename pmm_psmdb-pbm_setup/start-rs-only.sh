#!/bin/bash
set -e

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
if [ $mongo_setup_type == "pss" ]; then
  bash -e ./configure-replset.sh
else
  bash -e ./configure-psa.sh
fi

# Enable authorization first
echo "Enabling authorization..."
docker exec rs101 sed -i 's/authorization: disabled/authorization: enabled/' /etc/mongod/mongod.conf
docker exec rs101 systemctl restart mongod
sleep 10

# Setup Kerberos users after authorization is enabled
echo "Setting up Kerberos authentication users..."
# Wait for MongoDB to be ready
sleep 5
# Direct command to create Kerberos user
docker exec rs101 mongo --quiet -u root -p root --authenticationDatabase admin --eval "db.getSiblingDB('\$external').createUser({user: 'pmm-test@PERCONATEST.COM', roles: [{role: 'explainRole', db: 'admin'}, {role: 'clusterMonitor', db: 'admin'}, {role: 'userAdminAnyDatabase', db: 'admin'}, {role: 'dbAdminAnyDatabase', db: 'admin'}, {role: 'readWriteAnyDatabase', db: 'admin'}, {role: 'read', db: 'local'}]})"
echo "✓ Kerberos user setup completed"

bash -x ./configure-agents.sh

if [ $profile = "extra" ]; then
# Enable authorization first
echo "Enabling authorization..."
  docker exec rs201 sed -i 's/authorization: disabled/authorization: enabled/' /etc/mongod/mongod.conf
  docker exec rs201 systemctl restart mongod
  sleep 10

  # Setup Kerberos users after authorization is enabled
  echo "Setting up Kerberos authentication users..."
  # Wait for MongoDB to be ready
  sleep 5
  # Direct command to create Kerberos user
  docker exec rs201 mongo --quiet -u root -p root --authenticationDatabase admin --eval "db.getSiblingDB('\$external').createUser({user: 'pmm-test@PERCONATEST.COM', roles: [{role: 'explainRole', db: 'admin'}, {role: 'clusterMonitor', db: 'admin'}, {role: 'userAdminAnyDatabase', db: 'admin'}, {role: 'dbAdminAnyDatabase', db: 'admin'}, {role: 'readWriteAnyDatabase', db: 'admin'}, {role: 'read', db: 'local'}]})"
  echo "✓ Kerberos user setup completed"
  if [ $mongo_setup_type == "pss" ]; then
    bash -x ./configure-extra-replset.sh
  else
    bash -x ./configure-extra-psa.sh
  fi
  bash -x ./configure-extra-agents.sh
fi
