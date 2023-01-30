#!/bin/bash
pmm_user=${PMM_USER:-pmm}
pmm_pass=${PMM_PASS:-pmmpass}
pbm_user=${PBM_USER:-pbm}
pbm_pass=${PBM_PASS:-pbmpass}
docker-compose -f docker-compose-rs.yaml down -v --remove-orphans
docker-compose -f docker-compose-rs.yaml build
docker-compose -f docker-compose-rs.yaml up -d
echo
echo "waiting 30 seconds for pmm-server to start"
sleep 30
echo
echo "configuring pmm-server"
docker-compose -f docker-compose-rs.yaml exec -T pmm-server change-admin-password password
echo
echo "configuring replicaset with members priorities"
docker-compose -f docker-compose-rs.yaml exec -T rs101 mongo << EOF
    config = {
        "_id" : "rs",
        "members" : [
        {
            "_id" : 0,
            "host" : "rs101:27017",
            "priority": 2
        },
        {
            "_id" : 1,
            "host" : "rs102:27017",
            "priority": 1
        },
        {
            "_id" : 2,
            "host" : "rs103:27017",
            "priority": 1
        }
      ]
      };
      rs.initiate(config);
EOF
sleep 60
echo
echo "configuring root user on primary"
docker-compose -f docker-compose-rs.yaml exec -T rs101 mongo << EOF
db.getSiblingDB("admin").createUser({ user: "root", pwd: "root", roles: [ "root", "userAdminAnyDatabase", "clusterAdmin" ] });
EOF
echo
echo "configuring pbm and pmm roles"
docker-compose -f docker-compose-rs.yaml exec -T rs101 mongo "mongodb://root:root@localhost/?replicaSet=rs" << EOF
db.getSiblingDB("admin").createRole({
    "role": "pbmAnyAction",
    "privileges": [{
        "resource": { "anyResource": true },
	 "actions": [ "anyAction" ]
        }],
    "roles": []
});
db.getSiblingDB("admin").createRole({
    role: "explainRole",
    privileges: [{
        resource: {
            db: "",
            collection: ""
            },
        actions: [
            "listIndexes",
            "listCollections",
            "dbStats",
            "dbHash",
            "collStats",
            "find"
            ]
        }],
    roles:[]
});
EOF
echo
echo "creating pbm user"
docker-compose -f docker-compose-rs.yaml exec -T rs101 mongo "mongodb://root:root@localhost/?replicaSet=rs" << EOF
db.getSiblingDB("admin").createUser({
    user: "${pbm_user}",
    pwd: "${pbm_pass}",
    "roles" : [
        { "db" : "admin", "role" : "readWrite", "collection": "" },
        { "db" : "admin", "role" : "backup" },
        { "db" : "admin", "role" : "clusterMonitor" },
        { "db" : "admin", "role" : "restore" },
        { "db" : "admin", "role" : "pbmAnyAction" }
    ]
});
EOF
echo
echo "creating pmm user"
docker-compose -f docker-compose-rs.yaml exec -T rs101 mongo "mongodb://root:root@localhost/?replicaSet=rs" << EOF
db.getSiblingDB("admin").createUser({
    user: "${pmm_user}",
    pwd: "${pmm_pass}",
    roles: [
        { role: "explainRole", db: "admin" },
        { role: "clusterMonitor", db: "admin" },
        { role: "read", db: "local" },
        { "db" : "admin", "role" : "readWrite", "collection": "" },
        { "db" : "admin", "role" : "backup" },
        { "db" : "admin", "role" : "clusterMonitor" },
        { "db" : "admin", "role" : "restore" },
        { "db" : "admin", "role" : "pbmAnyAction" }
    ]
});
EOF
echo
echo "configuring pbm agents"
nodes="rs101 rs102 rs103"
for node in $nodes
do
    echo "congiguring pbm agent on $node"
    docker-compose -f docker-compose-sharded.yaml exec -T $node bash -c "echo \"PBM_MONGODB_URI=mongodb://${pbm_user}:${pbm_pass}@127.0.0.1:27017\" > /etc/sysconfig/pbm-agent"
    echo "restarting pbm agent on $node"
    docker-compose -f docker-compose-sharded.yaml exec -T $node systemctl restart pbm-agent
done
echo
echo "configuring pmm agents"
nodes="rs101 rs102 rs103"
for node in $nodes
do
    echo "congiguring pmm agent on $node"
    docker-compose -f docker-compose-rs.yaml exec -T $node pmm-agent setup
    docker-compose -f docker-compose-rs.yaml exec -T $node pmm-admin add mongodb --cluster=replicaset --replication-set=rs --username=${pmm_user} --password=${pmm_pass} $node 127.0.0.1:27017
done
echo
echo "adding some data"
docker-compose -f docker-compose-rs.yaml exec -T rs101 mgodatagen -f /etc/datagen/replicaset.json --uri=mongodb://root:root@127.0.0.1:27017/?replicaSet=rs
tests=${TESTS:-yes}
if [ $tests != "no" ]; then
    echo
    echo "running tests"
    docker-compose -f docker-compose-rs.yaml run test pytest -s -x --verbose test.py
    docker-compose -f docker-compose-rs.yaml run test chmod -R 777 .
    else
    echo
    echo "skipping tests"
fi
cleanup=${CLEANUP:-yes}
if [ $cleanup != "no" ]; then
    echo
    echo "cleanup"
    docker-compose -f docker-compose-rs.yaml down -v --remove-orphans
    else
    echo
    echo "skipping cleanup"
fi
