var db = connect("mongodb://dba:secret@localhost:27017/admin");
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
db.getSiblingDB("admin").createRole({
     role: "cn=readers,ou=users,dc=example,dc=org",
     privileges: [],
     roles: [
       { role: "explainRole", db: "admin" },
       { role: "clusterMonitor", db: "admin" },
       { role: "userAdminAnyDatabase", db: "admin" },
       { role: "dbAdminAnyDatabase", db: "admin" },
       { role: "readWriteAnyDatabase", db: "admin" },
       { role: "read", db: "local" }]
});
db.getSiblingDB("admin").createUser({
   user: "pmm_mongodb",
   pwd: "5M](Q%q/U+YQ<^m",
   roles: [
      { role: "explainRole", db: "admin" },
      { role: "clusterMonitor", db: "admin" },
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "dbAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" },
      { role: "read", db: "local" }
   ]
});
