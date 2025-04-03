import subprocess

def install_percona_server(ps_version, query_source):
    print(f"Query Source is: {query_source}")
    ps_port=3317
    ps_container=f"pmm_ps_{ps_version}"
    print(f"Percona server version is: {ps_version}")
    run_command(f"docker rm -f {ps_container} || true")
    run_command("docker network create pmm-qa || true")
    run_command(f"docker run -d --name={ps_container} -p {ps_port}:3307 phusion/baseimage:noble-1.0.1")
    run_command(f"docker cp ./client_container_ps_setup.sh {ps_container}:/")
    run_command(f"docker exec {ps_container} apt-get update")
    run_command(f"docker exec {ps_container} apt-get -y install wget curl git gnupg2 lsb-release")
    run_command(f"docker exec {ps_container} apt-get -y install libaio1t64 libaio-dev libnuma-dev socat")
    run_command(f"docker exec {ps_container} apt-get -y install sysbench")
    run_command(f"docker exec {ps_container} curl -O https://repo.percona.com/apt/percona-release_latest.generic_all.deb")
    run_command(f"docker exec {ps_container} apt -y install gnupg2 lsb-release ./percona-release_latest.generic_all.deb")
    run_command(f"docker exec {ps_container} apt update")

    # if(ps_version == 84):
        # run_command(f"docker exec {ps_container} percona-release setup ps84lts")
    # else:
    #     raise Exception(f"Percona server version: {ps_version} is not supported")

    # run_command(f"docker exec {ps_container} DEBIAN_FRONTEND=noninteractive  apt -y install percona-server-server")
    # mysql - u root - p - e "CREATE USER 'msandbox'@'%' IDENTIFIED BY 'msandbox'; GRANT ALL PRIVILEGES ON *.* TO 'msandbox'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"

    # sysbench
    # oltp_common - -db - driver = mysql - -mysql - db = test - -mysql - user = username - -mysql - password = password - -mysql - host = localhost - -mysql - port = 3306 - -tables = 10 - -table - size = 1000000
    # prepare
    # service
    # mysql
    # restart
    # mysql - e
    # "create user pmm@'%' identified by \"pmm\""
    # mysql - e
    # "grant all on *.* to pmm@'%'"
    # mysql - e
    # "CREATE USER 'pmm_tls'@'%' REQUIRE X509"
    # service
    # mysql
    # restart
    # if(query_source == "perfschema"):

def run_command(cmd):
    print(f"Running command: {cmd}")
    response = subprocess.run(cmd, shell=True, check=True, text=True, capture_output=True)
    print(response.stdout)