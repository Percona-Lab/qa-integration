import subprocess
import argparse
import os

# Database configurations
database_configs = {
    "psmdb": {
        "versions": ["4.4", "5.0", "6.0", "7.0"],
        "configurations": {"client_version": "dev-latest"}
    },
    "mysql": {
        "versions": ["8.0"],
        "configurations": {"query_source": "perfschema", "client_version": "dev-latest", "tarball": "https"}
    },
    "pdmysql": {
        "versions": ["5.7", "8.0"],
        "configurations": {"query_source": "perfschema", "client_version": "dev-latest", "tarball": "https"}
    },
    "pdpgsql": {
        "versions": ["14", "15", "16"],
        "configurations": {"client_version": "dev-latest", "use_socket": "/tmp/"}
    }
}


def get_running_container_name():
    # Check if PMM server is running, and establish N/W connection
    container_name = "pmm-server"
    try:
        # Run 'docker ps' to get a list of running containers
        output = subprocess.check_output(['docker', 'ps', '--format', '{{.Names}}'])

        # Split the output into a list of container names
        running_containers = output.strip().decode('utf-8').split('\n')

        # Check if the desired container is in the list of running containers
        if container_name in running_containers:
            subprocess.run(['docker', 'network', 'create', 'pmm-qa'])
            subprocess.run(['docker', 'network', 'connect', 'pmm-qa', container_name])
            return container_name
        else:
            print("Check if PMM docker container named:", container_name, "is Up and Running..")
            return None
    except subprocess.CalledProcessError:
        # Handle the case where the 'docker ps' command fails
        return None


def setup_pdmysql(db_type, version=None, config=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None:
        exit()
    # Path to Ansible playbook
    playbook_path = os.getcwd() + '/ps_pmm_setup.yml'

    # Define environment variables for playbook
    env_vars = {
        'PS_NODES': '1',
        'PS_VERSION': os.environ.get('PS_VERSION') if os.environ.get('PS_VERSION') else version,
        'PMM_SERVER_IP': container_name if container_name else '127.0.0.1',
        'PS_CONTAINER': 'pdmysql_pmm_' + os.environ.get('PS_VERSION') if os.environ.get(
            'PS_VERSION') else 'pdmysql_pmm_' + version,
        'CLIENT_VERSION': os.environ.get('CLIENT_VERSION') if os.environ.get('CLIENT_VERSION') else config[
            'client_version'] if config.get('client_version') else '',
        'QUERY_SOURCE': config['query_source'] if config.get('query_source') else '',
        'PS_TARBALL': config['tarball'] if config.get('tarball') else '',
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars)


def setup_mysql(db_type, version=None, config=None):
    # Check if PMM server is running, and establish N/W connection
    container_name = get_running_container_name()
    if container_name is None:
        exit()

    # Path to Ansible playbook
    playbook_path = os.getcwd() + '/ms_pmm_setup.yml'

    # Define environment variables  for playbook
    env_vars = {
        'MS_NODES': '1',
        'MS_VERSION': os.environ.get('MS_VERSION') if os.environ.get('MS_VERSION') else version,
        'PMM_SERVER_IP': container_name if container_name else '127.0.0.1',
        'MS_CONTAINER': 'mysql_pmm_' + os.environ.get('MS_VERSION') if os.environ.get(
            'MS_VERSION') else 'mysql_pmm_' + version,
        'CLIENT_VERSION': os.environ.get('CLIENT_VERSION') if os.environ.get('CLIENT_VERSION') else config[
            'client_version'] if config.get('client_version') else '',
        'QUERY_SOURCE': config['query_source'] if config.get('query_source') else '',
        'MS_TARBALL': config['tarball'] if config.get('tarball') else '',
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars)


def setup_pdpgsql(db_type, version=None, config=None):
    # Check if PMM server is running, and establish N/W connection
    container_name = get_running_container_name()
    if container_name is None:
        exit()

    # Path to Ansible playbook
    playbook_path = os.getcwd() + '/pgsql_pgsm_setup.yml'

    # Define environment variables  for playbook
    env_vars = {
        'PGSTAT_MONITOR_BRANCH': 'main',
        'PGSQL_VERSION': os.environ.get('PGSQL_VERSION') if os.environ.get('PGSQL_VERSION') else version,
        'PMM_SERVER_IP': container_name if container_name else '127.0.0.1',
        'PGSQL_PGSM_CONTAINER': 'pdpgsql_pmm_' + os.environ.get('PGSQL_VERSION') if os.environ.get(
            'PGSQL_VERSION') else 'pdpgsql_pmm_' + version,
        'CLIENT_VERSION': os.environ.get('CLIENT_VERSION') if os.environ.get('CLIENT_VERSION') else config[
            'client_version'] if config.get('client_version') else '',
        'USE_SOCKET': config['use_socket'] if config.get('use_socket') else ''
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars)


# Function to set up a databases based on choice
def setup_database(db_type, version=None, config=None, verbose=None):
    if verbose:
        if version:
            print(f"Setting up {db_type} version {version}", end=" ")
        else:
            print(f"Setting up {db_type}", end=" ")

        if config:
            print(f"with configuration: {config}")
        else:
            print()

    if db_type == 'mysql':
        setup_mysql(db_type, version, config)
    elif db_type == 'pdmysql':
        setup_pdmysql(db_type, version, config)
    elif db_type == 'pdpgsql':
        setup_pdpgsql(db_type, version, config)
    else:
        print(f"Database type {db_type} is not recognised")
        exit()


def run_ansible_playbook(playbook_path, env_vars):
    # Build the command to execute the playbook
    command = ["ansible-playbook", f"{playbook_path}", f'-e os_type=linux', f'--connection=local',
               f'-l 127.0.0.1', f'-i 127.0.0.1,']
    subprocess.run(command, env=env_vars, check=True)

# Main
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='PMM Framework Script to setup Multiple Databases')
    # Add arguments
    parser.add_argument("--databases", "--d", action='append', nargs='+', metavar='databases',
                        help="list of databases configs format 'db_type[:version][:key1=value1:key2=value2,...]' (e.g."
                             "'mysql:5.7:query_source=perfschema:client_version=dev-latest')"
                             "'pdpgsql:5.7:query_source=perfschema:client_version=dev-latest')")
    parser.add_argument("--verbose", "--v", action='store_true', help='display verbose information')
    args = parser.parse_args()

    # Parse arguments
    for db in args.databases:
        db_parts = db[0].split(':')
        db_type = db_parts[0]
        version = db_parts[1] if len(db_parts) > 1 else None
        configs = db_parts[2:] if len(db_parts) > 2 else None

        if version and version not in database_configs[db_type]["versions"]:
            version = None

        if configs:
            db_config = {}
            for config in configs:
                key, value = config.split('=')
                if key in database_configs[db_type]["configurations"]:
                    db_config[key] = value

            # Set up the specified database
            setup_database(db_type, version, db_config, args.verbose)
