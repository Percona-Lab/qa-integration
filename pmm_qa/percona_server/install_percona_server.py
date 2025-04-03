import subprocess

def install_percona_server(ps_version):
    ps_port=3317
    ps_container=f"pmm_ps_{ps_version}"
    print(f"Percona server version is: {ps_version}")
    subprocess.run("docker network create pmm-qa | true")
    subprocess.run(f"docker run -d --name={ps_container} -p {ps_port}:3307 phusion/baseimage:noble-1.0.1")