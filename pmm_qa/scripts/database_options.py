database_options = {
    "PSMDB": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "8.0", "latest"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "SETUP_TYPE": "pss", "COMPOSE_PROFILES": "classic",
                           "TARBALL": ""}
    },
    "MLAUNCH_PSMDB": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "8.0"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "SETUP_TYPE": "pss", "TARBALL": ""}
    },
    "MLAUNCH_MODB": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "8.0"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "SETUP_TYPE": "pss", "TARBALL": ""}
    },
    "SSL_MLAUNCH": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "8.0"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "SETUP_TYPE": "pss", "COMPOSE_PROFILES": "classic",
                           "TARBALL": ""}
    },
    "SSL_PSMDB": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "8.0", "latest"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "SETUP_TYPE": "pss", "COMPOSE_PROFILES": "classic",
                           "TARBALL": ""}
    },
    "MYSQL": {
        "versions": ["8.0", "8.4"],
        "configurations": {"QUERY_SOURCE": "perfschema", "SETUP_TYPE": "", "CLIENT_VERSION": "3-dev-latest",
                           "TARBALL": ""}
    },
    "PS": {
        "versions": ["5.7", "8.4", "8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "SETUP_TYPE": "", "CLIENT_VERSION": "3-dev-latest",
                           "TARBALL": "", "NODES_COUNT": 1}
    },
    "SSL_MYSQL": {
        "versions": ["5.7", "8.4", "8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "SETUP_TYPE": "", "CLIENT_VERSION": "3-dev-latest",
                           "TARBALL": ""}
    },
    "PGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16", "17"],
        "configurations": {"QUERY_SOURCE": "pgstatements", "CLIENT_VERSION": "3-dev-latest", "USE_SOCKET": "",
                           "SETUP_TYPE": ""}
    },
    "PDPGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16", "17"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "USE_SOCKET": "", "SETUP_TYPE": ""}
    },
    "SSL_PDPGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16", "17"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "USE_SOCKET": ""}
    },
    "PXC": {
        "versions": ["5.7", "8.0"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "QUERY_SOURCE": "perfschema", "TARBALL": ""}
    },
    "PROXYSQL": {
        "versions": ["2"],
        "configurations": {"PACKAGE": ""}
    },
    "HAPROXY": {
        "versions": [""],
        "configurations": {"CLIENT_VERSION": "3-dev-latest"}
    },
    "EXTERNAL": {
        "REDIS": {
            "versions": ["1.14.0", "1.58.0"],
        },
        "NODEPROCESS": {
            "versions": ["0.7.5", "0.7.10"],
        },
        "configurations": {"CLIENT_VERSION": "3-dev-latest"}
    },
    "DOCKERCLIENTS": {
        "configurations": {}  # Empty dictionary for consistency
    },
}
