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
    run_command(f"docker exec {ps_container} apt install gnupg2 lsb-release ./percona-release_latest.generic_all.deb")
    run_command(f"docker exec {ps_container} apt update")

    if(ps_version == 84):
        run_command(f"docker exec {ps_container} sudo percona-release setup ps80")
    else:
        raise Exception(f"Percona server version: {ps_version} is not supported")

    run_command(f"docker exec {ps_container} apt install percona-server-server")
    # if(query_source == "perfschema"):

def run_command(cmd):
    print(f"Running command: {cmd}")
    response = subprocess.run(cmd, shell=True, check=True, text=True, capture_output=True)
    print(response.stdout)