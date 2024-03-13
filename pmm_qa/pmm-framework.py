#! /usr/bin/python3
import subprocess
import argparse
import os
import sys

# Database configurations
database_configs = {
    "PSMDB": {
        "versions": ["4.4", "5.0", "6.0", "7.0"],
        "configurations": {"CLIENT_VERSION": "dev-latest"}
    },
    "MYSQL": {
        "versions": ["8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "GROUP_REPLICATION" : "","CLIENT_VERSION": "dev-latest", "TARBALL": ""}
    },
    "PDMYSQL": {
        "versions": ["5.7", "8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "CLIENT_VERSION": "dev-latest", "TARBALL": ""}
    },
    "PGSQL": {
        "versions": ["11", "12", "14", "15", "16"],
        "configurations": {"CLIENT_VERSION": "dev-latest", "USE_SOCKET": ""}
    },
    "PDPGSQL": {
        "versions": ["11", "12", "14", "15", "16"],
        "configurations": {"CLIENT_VERSION": "dev-latest", "USE_SOCKET": ""}
    }
}

def run_ansible_playbook(playbook_path, env_vars, args):
    # Build the commands to execute the playbook
    command = ["ansible-playbook", f"{playbook_path}", f'-e os_type=linux', f'--connection=local',
               f'-l localhost', f'-i localhost,']
    if args.verbose:
        print(f'Options set after considering defaults: {env_vars}')
    subprocess.run(command, env=env_vars, check=True)

def get_running_container_name():
    container_name = "pmm-server"
    try:
        # Run 'docker ps' to get a list of running containers
        output = subprocess.check_output(['docker', 'ps', '--format', '{{.Names}}'])

        # Split the output into a list of container names
        running_containers = output.strip().decode('utf-8').split('\n')

        # Check if the container is in the list of running containers
        # and establish N/W connection with it.
        if container_name in running_containers:
            subprocess.run(['docker', 'network', 'create', 'pmm-qa'])
            subprocess.run(['docker', 'network', 'connect', 'pmm-qa', container_name])
            return container_name
        else:
            return None
    except subprocess.CalledProcessError:
        # Handle the case where the 'docker ps' command fails
        return None


def get_value(key, db_type, args, db_config):
    # Check if the variable exists in the environment
    env_value = os.environ.get(key)
    if env_value is not None:
        return env_value

    # Only for client_version we accept global command line argument
    if key == "CLIENT_VERSION" and args.client_version is not None:
        return args.client_version.upper()

    # Check if the variable exists in the args config
    config_value = db_config.get(key)
    if config_value is not None:
        return config_value

    # Fall back to default configs value
    return database_configs[db_type]["configurations"].get(key, '')


def setup_pdmysql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running..Exiting")
        exit()

    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    # Path to Ansible playbook
    playbook_path = script_dir + '/ps_pmm_setup.yml'

    # Define environment variables for playbook
    env_vars = {
        'PS_NODES': '1',
        'PS_VERSION':  os.getenv('PS_VERSION') or db_version or database_configs[db_type]["versions"][-1],
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'PS_CONTAINER': 'pdmysql_pmm_' + os.getenv('PS_VERSION', db_version) if db_version else 'pdmysql_pmm_' + database_configs[db_type]["versions"][-1],
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'PS_TARBALL': get_value('TARBALL', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars, args)


def setup_mysql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running.., Exiting")
        exit()

    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    # Path to Ansible playbook
    playbook_path = script_dir + '/ms_pmm_setup.yml'

    # Define environment variables for playbook
    env_vars = {
        'GROUP_REPLICATION': get_value('GROUP_REPLICATION', db_type, args, db_config),
        'MS_NODES': '3' if get_value('GROUP_REPLICATION', db_type, args, db_config) else '1',
        'MS_VERSION': os.getenv('MS_VERSION') or db_version or database_configs[db_type]["versions"][-1],
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'MS_CONTAINER': 'mysql_pmm_' + os.getenv('PS_VERSION', db_version) if db_version else 'mysql_pmm_' + database_configs[db_type]["versions"][-1],
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args,  db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'MS_TARBALL': get_value('TARBALL', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars, args)


def setup_pdpgsql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running..Exiting")
        exit()

    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    # Path to Ansible playbook
    playbook_path = script_dir + '/pdpgsql_pgsm_setup.yml'

    # Define environment variables for playbook
    env_vars = {
        'PGSTAT_MONITOR_BRANCH': 'main',
        'PDPGSQL_VERSION': os.getenv('PDPGSQL_VERSION') or db_version or database_configs[db_type]["versions"][-1],
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'PDPGSQL_PGSM_CONTAINER': 'pdpgsql_pmm_' + os.getenv('PDPGSQL_VERSION', db_version) if db_version else 'pdpgsql_pmm_' + database_configs[db_type]["versions"][-1],
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'USE_SOCKET': get_value('USE_SOCKET', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars, args)

def setup_pgsql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running..Exiting")
        exit()

    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    # Path to Ansible playbook
    playbook_path = script_dir + '/pgsql_pgsm_setup.yml'

    # Define environment variables for playbook
    env_vars = {
        'PGSTAT_MONITOR_BRANCH': 'main',
        'PGSQL_VERSION': os.getenv('PGSQL_VERSION') or db_version or database_configs[db_type]["versions"][-1],
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'PGSQL_PGSM_CONTAINER': 'pgsql_pmm_' + os.getenv('PGSQL_VERSION', db_version) if db_version else 'pgsql_pmm_' + database_configs[db_type]["versions"][-1],
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'USE_SOCKET': get_value('USE_SOCKET', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_path, env_vars, args)


# Function to set up a databases based on choice
def setup_database(db_type, db_version=None, db_config=None, args=None):
    if args.verbose:
        if db_version:
            print(f"Setting up {db_type} version {version}", end=" ")
        else:
            print(f"Setting up {db_type}", end=" ")

        if db_config:
            print(f"with configuration: {config}")
        else:
            print()

    if db_type == 'MYSQL':
        setup_mysql(db_type, db_version, db_config, args)
    elif db_type == 'PDMYSQL':
        setup_pdmysql(db_type, db_version, db_config, args)
    elif db_type == 'PGSQL':
        setup_pgsql(db_type, db_version, db_config, args)
    elif db_type == 'PDPGSQL':
        setup_pdpgsql(db_type, db_version, db_config, args)
    else:
        print(f"Database type {db_type} is not recognised, Exiting...")
        exit()


# Main
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='PMM Framework Script to setup Multiple Databases')
    # Add arguments
    parser.add_argument("--database", "--d", action='append', nargs='+',metavar='database=version,option=value',
                        help="List of database options format 'db_type[,version][,key1=value1,key2=value2,...]' (e.g."
                             "'mysql=5.7,QUERY_SOURCE=perfschema,CLIENT_VERSION=dev-latest')"
                             "'pdpgsql=16,USE_SOCKET=1,CLIENT_VERSION=2.41.1')")
    parser.add_argument("--pmm-server-ip", nargs='?', help='PMM Server IP to connect')
    parser.add_argument("--pmm-server-password", nargs='?', help='PMM Server password')
    parser.add_argument("--client-version", nargs='?', help='PMM Client versoin/tarball')
    parser.add_argument("--verbose", "--v", action='store_true', help='Display Verbose information')
    args = parser.parse_args()

    # Parse arguments
    for db in args.database:
        db_parts = db[0].split(',')
        configs = db_parts[0:] if len(db_parts) > 1 else db[0:]
        db_type = None
        db_version = None
        db_config = {}

        if configs:
            for config in configs:
                if "=" in config:
                    key, value = config.split('=')
                else:
                    key, value = config, None

                # Convert all str arguments to uppercase
                key = key.upper()
                if value is not None:
                    value = value.upper()

                if key in database_configs:
                    db_type = key
                    if value in database_configs[db_type]["versions"]:
                        db_version = value
                    else:
                        print(f"Config value {value} is not recognised, for option {db_type} will be using default value")
                elif key in database_configs[db_type]["configurations"]:
                        db_config[key] = value
                else:
                    print(f"Config key {key} is not recognised, for option {db_type} will be using default value")

        # Set up the specified database
        setup_database(db_type, db_version, db_config, args)
