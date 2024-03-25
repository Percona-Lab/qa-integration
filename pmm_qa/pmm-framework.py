#! /usr/bin/python3
import subprocess
import argparse
import os
import sys

# Database configurations
database_configs = {
    "PSMDB": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "latest"],
        "configurations": {"CLIENT_VERSION": "dev-latest", "SETUP_TYPE": "replica", "COMPOSE_PROFILES": "classic", "TARBALL": ""}
    },
    "MYSQL": {
        "versions": ["8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "GROUP_REPLICATION": "", "CLIENT_VERSION": "dev-latest",
                           "TARBALL": ""}
    },
    "PDMYSQL": {
        "versions": ["5.7", "8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "CLIENT_VERSION": "dev-latest", "TARBALL": ""}
    },
    "PGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16"],
        "configurations": {"QUERY_SOURCE": "pgstatements", "CLIENT_VERSION": "dev-latest", "USE_SOCKET": ""}
    },
    "PDPGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16"],
        "configurations": {"CLIENT_VERSION": "dev-latest", "USE_SOCKET": ""}
    },
}


def run_ansible_playbook(playbook_filename, env_vars, args):
    # Install Ansible
    try:
        subprocess.run(['sudo', 'yum', 'install', 'ansible', '-y'])
    except Exception as e:
        print(f"Error installing Ansible: {e}")
        exit(1)

    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    playbook_path = script_dir + "/" + playbook_filename

    # Build the commands to execute the playbook
    command = ["ansible-playbook", f"{playbook_path}", f'-e os_type=linux', f'--connection=local',
               f'-l localhost', f'-i localhost,']

    if args.verbose:
        print(f'Options set after considering defaults: {env_vars}')

    try:
        subprocess.run(command, env=env_vars, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error executing Ansible {command}: {e}")
        exit(1)


def get_running_container_name():
    container_name = "pmm-server"
    try:
        # Run 'docker ps' to get a list of running containers
        output = subprocess.check_output(['docker', 'ps', '--format', 'table {{.ID}}\t{{.Image}}\t{{.Names}}'])
        # Split the output into a list of container
        containers = output.strip().decode('utf-8').split('\n')[1:]
        # Check each line for the docker image name
        for line in containers:
            # Extract the image name
            image_info = line.split('\t')[0]
            info_parts = image_info.split()[2:]
            # Check if the container is in the list of running containers
            # and establish N/W connection with it.
            if container_name in info_parts:
                subprocess.run(['docker', 'network', 'create', 'pmm-qa'])
                subprocess.run(['docker', 'network', 'connect', 'pmm-qa', container_name])
                return container_name

    except subprocess.CalledProcessError:
        # Handle the case where the 'docker ps' command fails
        return None

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

    # Fall back to default configs value or empty ''
    return database_configs[db_type]["configurations"].get(key, '')


def setup_pdmysql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running..Exiting")
        exit()

    # Gather Version details
    ps_version = os.getenv('PS_VERSION') or db_version or database_configs[db_type]["versions"][-1]

    # Define environment variables for playbook
    env_vars = {
        'PS_NODES': '1',
        'PS_VERSION': ps_version,
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'PS_CONTAINER': 'pdmysql_pmm_' + str(ps_version),
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'PS_TARBALL': get_value('TARBALL', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Ansible playbook filename
    playbook_filename = 'ps_pmm_setup.yml'

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_filename, env_vars, args)


def setup_mysql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running.., Exiting")
        exit()

    # Gather Version details
    ms_version = os.getenv('MS_VERSION') or db_version or database_configs[db_type]["versions"][-1]

    # Define environment variables for playbook
    env_vars = {
        'GROUP_REPLICATION': get_value('GROUP_REPLICATION', db_type, args, db_config),
        'MS_NODES': '3' if get_value('GROUP_REPLICATION', db_type, args, db_config) else '1',
        'MS_VERSION': ms_version,
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'MS_CONTAINER': 'mysql_pmm_' + str(ms_version),
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'MS_TARBALL': get_value('TARBALL', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Ansible playbook filename
    playbook_filename = 'ms_pmm_setup.yml'

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_filename, env_vars, args)


def setup_pdpgsql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running..Exiting")
        exit()

    # Gather Version details
    pdpgsql_version = os.getenv('PDPGSQL_VERSION') or db_version or database_configs[db_type]["versions"][-1]

    # Define environment variables for playbook
    env_vars = {
        'PGSTAT_MONITOR_BRANCH': 'main',
        'PDPGSQL_VERSION': pdpgsql_version,
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'PDPGSQL_PGSM_CONTAINER': 'pdpgsql_pgsm_pmm_' + str(pdpgsql_version),
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'USE_SOCKET': get_value('USE_SOCKET', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Ansible playbook filename
    playbook_filename = 'pdpgsql_pgsm_setup.yml'

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_filename, env_vars, args)


def setup_pgsql(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running..Exiting")
        exit()

    # Gather Version details
    pgsql_version = os.getenv('PGSQL_VERSION') or db_version or database_configs[db_type]["versions"][-1]

    # Define environment variables for playbook
    env_vars = {
        'PGSQL_VERSION': pgsql_version,
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'PGSQL_PGSS_CONTAINER': 'pgsql_pgss_pmm_' + str(pgsql_version),
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'USE_SOCKET': get_value('USE_SOCKET', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
    }

    # Ansible playbook filename
    playbook_filename = 'pgsql_pgss_setup.yml'

    # Call the function to run the Ansible playbook
    run_ansible_playbook(playbook_filename, env_vars, args)


def execute_docker_compose(compose_filename, commands, env_vars, args):
    # Setup n/w used by compose setup
    subprocess.run(['docker', 'network', 'create', 'qa-integration'])
    subprocess.run(['docker', 'network', 'create', 'pmm-ui-tests_pmm-network'])
    subprocess.run(['docker', 'network', 'create', 'pmm2-upgrade-tests_pmm-network'])
    subprocess.run(['docker', 'network', 'create', 'pmm2-ui-tests_pmm-network'])

    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    compose_path = script_dir + "/../pmm_psmdb-pbm_setup/" + compose_filename

    # Set environment variables if provided
    if env_vars:
        for key, value in env_vars.items():
            os.environ[key] = value

    if args.verbose:
        print(f'Options set after considering defaults: {env_vars}')

    for command, options in commands.items():
        # Build the Docker Compose command
        docker_compose_cmd = ['docker-compose', '-f', compose_path, command]

        # Add options if provided
        if options:
            docker_compose_cmd.extend(options)

        # Execute Docker Compose
        try:
            subprocess.run(docker_compose_cmd, check=True)
            print(f"Docker Compose {command} executed successfully!")
        except subprocess.CalledProcessError as e:
            print(f"Error executing Docker Compose {command}: {e}")
            exit(1)


def execute_shell_scripts(shell_scripts):
    # Get script directory
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    shell_scripts_path = script_dir + "/../pmm_psmdb-pbm_setup/"

    # Get the original working directory
    original_dir = os.getcwd()

    # Execute each shell script
    for script in shell_scripts:
        try:
            # Change directory to where the script is located
            os.chdir(shell_scripts_path)
            subprocess.run(['bash', script], check=True)
            print(f"Shell script '{script}' executed successfully!")
        except subprocess.CalledProcessError as e:
            print(f"Error executing shell script '{script} at path {shell_scripts_path}': {e}")
            exit(1)
        finally:
            # Return to the original working directory
            os.chdir(original_dir)


def setup_psmdb(db_type, db_version=None, db_config=None, args=None):
    # Check if PMM server is running
    container_name = get_running_container_name()
    if container_name is None and args.pmm_server_ip is None:
        print(f"Check if PMM Server is Up and Running...Exiting")
        exit(1)

    # Gather Version details
    psmdb_version = os.getenv('PSMDB_VERSION') or db_version or database_configs[db_type]["versions"][-1]

    # Define environment variables for playbook
    env_vars = {
        'PSMDB_VERSION': psmdb_version,
        'PMM_SERVER_CONTAINER_ADDRESS': args.pmm_server_ip or container_name or '127.0.0.1',
        'PSMDB_CONTAINER': 'psmdb_pmm_' + str(psmdb_version),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'PMM_CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'COMPOSE_PROFILES': get_value('COMPOSE_PROFILES', db_type, args, db_config)
    }

    # Docker Compose filename
    compose_filename = 'docker-compose-rs.yaml'

    # Define commands for compose file
    commands = {
        'down': ['-v', '--remove-orphans'],  # Cleanup containers
        'build': ['--no-cache'],  # Build containers
        'up': ['-d'],  # Start containers
    }
    # Call the function to run the Compose files
    execute_docker_compose(compose_filename, commands, env_vars, args)

    shell_scripts = []
    if get_value('SETUP_TYPE', db_type, args, db_config).lower() == "replica":
        # Shell script names
        shell_scripts = ['configure-replset.sh', 'configure-agents.sh']

        # If profile is extra, include additional shell scripts
        if get_value('COMPOSE_PROFILES', db_type, args, db_config).lower() == "extra":
            shell_scripts.append('configure-extra-replset.sh')
            shell_scripts.append('configure-extra-agents.sh')

    # Execute shell scripts
    execute_shell_scripts(shell_scripts)


# Function to set up a databases based on choice
def setup_database(db_type, db_version=None, db_config=None, args=None):
    if args.verbose:
        if db_version:
            print(f"Setting up {db_type} version {db_version}", end=" ")
        else:
            print(f"Setting up {db_type}", end=" ")

        if db_config:
            print(f"with configuration: {db_config}")
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
    elif db_type == 'PSMDB':
        setup_psmdb(db_type, db_version, db_config, args)
    else:
        print(f"Database type {db_type} is not recognised, Exiting...")
        exit(1)


# Main
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='PMM Framework Script to setup Multiple Databases')
    # Add arguments
    parser.add_argument("--database", action='append', nargs=1,
                        metavar='db_name[,=version][,option1=value1,option2=value2,...]',
                        help="(e.g: "
                             "--database mysql=5.7,QUERY_SOURCE=perfschema,CLIENT_VERSION=dev-latest "
                             "--database pdpgsql=16,USE_SOCKET=1,CLIENT_VERSION=2.41.1)")
    parser.add_argument("--pmm-server-ip", nargs='?', help='PMM Server IP to connect', default='pmm-server')
    parser.add_argument("--pmm-server-password", nargs='?', help='PMM Server password')
    parser.add_argument("--client-version", nargs='?', help='PMM Client version/tarball')
    parser.add_argument("--verbose", "--v", action='store_true', help='Display verbose information')
    args = parser.parse_args()

    # Parse arguments
    try:
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

                    try:
                        if key in database_configs:
                            db_type = key
                            if value in database_configs[db_type]["versions"]:
                                db_version = value
                            else:
                                if args.verbose:
                                    print(
                                        f"Value {value} is not recognised for Option {key}, will be using default value")
                        elif key in database_configs[db_type]["configurations"]:
                            db_config[key] = value
                        else:
                            if args.verbose:
                                print(f"Option {key} is not recognised, will be using default option")
                                continue
                    except KeyError:
                        print(f"Option {key} is not recognised, Please check and try again")
                        parser.print_help()
                        exit(1)
                # Set up the specified databases
                setup_database(db_type, db_version, db_config, args)
    except argparse.ArgumentError as e:
        print(f"Option is not recognised:", e)
        parser.print_help()
        exit(1)
    except Exception as e:
        print("An unexpected error occurred:", e)
        parser.print_help()
        exit(1)
