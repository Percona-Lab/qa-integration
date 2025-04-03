import subprocess

def install_percona_server(ps_version):
    ps_port=3317
    ps_container=f"pmm_ps_{ps_version}"
    print(f"Percona server version is: {ps_version}")
    run_command(f"docker rm -f {ps_container} || true")
    run_command("docker network create pmm-qa || true")
    run_command(f"docker run -d --name={ps_container} -p {ps_port}:3307 phusion/baseimage:noble-1.0.1")
    run_command(f"docker cp ../client_container_ps_setup.sh {ps_container}:/")

def run_command(cmd):
    subprocess.run(cmd, shell=True, check=True, text=True, capture_output=True)