#! /usr/bin/python3 -E
import subprocess
import argparse
import os
import sys
import ansible_runner

# Database configurations
database_configs = {
    "PSMDB": {
        "versions": ["4.4", "5.0", "6.0", "7.0", "latest"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "SETUP_TYPE": "pss", "COMPOSE_PROFILES": "classic",
                           "TARBALL": ""}
    },
    "MYSQL": {
        "versions": ["8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "SETUP_TYPE": "", "CLIENT_VERSION": "3-dev-latest",
                           "TARBALL": ""}
    },
    "PS": {
        "versions": ["5.7", "8.0"],
        "configurations": {"QUERY_SOURCE": "perfschema", "CLIENT_VERSION": "3-dev-latest", "TARBALL": ""}
    },
    "PGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16"],
        "configurations": {"QUERY_SOURCE": "pgstatements", "CLIENT_VERSION": "3-dev-latest", "USE_SOCKET": ""}
    },
    "PDPGSQL": {
        "versions": ["11", "12", "13", "14", "15", "16"],
        "configurations": {"CLIENT_VERSION": "3-dev-latest", "USE_SOCKET": ""}
    },
}


def run_ansible_playbook(playbook_filename, env_vars, args):
    # Get Script Dir
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    playbook_path = script_dir + "/" + playbook_filename

    if args.verbose:
        print(f'Options set after considering defaults: {env_vars}')

    r = ansible_runner.run(
        private_data_dir=script_dir,
        playbook=playbook_path,
        inventory='127.0.0.1',
        cmdline='-l localhost, --connection=local',
        envvars=env_vars
    )
    print(f'{playbook_filename} playbook execution {r.status}')


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
        return args.client_version

    # Check if the variable exists in the args config
    config_value = db_config.get(key)
    if config_value is not None:
        return config_value

    # Fall back to default configs value or empty ''
    return database_configs[db_type]["configurations"].get(key, '')


def setup_ps(db_type, db_version=None, db_config=None, args=None):
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
        'PS_CONTAINER': 'ps_pmm_' + str(ps_version),
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'PS_TARBALL': get_value('TARBALL', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'PMM_QA_GIT_BRANCH': os.getenv('ADMIN_PASSWORD') or 'v3'
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

    # Check Setup Types
    setup_type = ''
    if get_value('SETUP_TYPE', db_type, args, db_config).lower() == "group_repilication" or "gr":
        setup_type = 1

    # Define environment variables for playbook
    env_vars = {
        'GROUP_REPLICATION': f'{setup_type}',
        'MS_NODES': '3' if setup_type else '1',
        'MS_VERSION': ms_version,
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'MS_CONTAINER': 'mysql_pmm_' + str(ms_version),
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'MS_TARBALL': get_value('TARBALL', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'PMM_QA_GIT_BRANCH': os.getenv('ADMIN_PASSWORD') or 'v3'
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
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'PMM_QA_GIT_BRANCH': os.getenv('ADMIN_PASSWORD') or 'v3'
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
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'PMM_QA_GIT_BRANCH': os.getenv('ADMIN_PASSWORD') or 'v3'
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


def execute_shell_scripts(shell_scripts, env_vars, args):
    # Get script directory
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    shell_scripts_path = script_dir + "/../pmm_psmdb-pbm_setup/"

    # Get the original working directory
    original_dir = os.getcwd()

    if args.verbose:
        print(f'Options set after considering defaults: {env_vars}')

    # Set environment variables if provided
    if env_vars:
        for key, value in env_vars.items():
            os.environ[key] = value

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


# Temporary method for Sharding Setup.
def mongo_sharding_setup(script_filename, args):
    # Get script directory
    script_path = os.path.abspath(sys.argv[0])
    script_dir = os.path.dirname(script_path)
    scripts_path = script_dir + "/../pmm_psmdb-pbm_setup/"

    # Temporary shell script filename
    shell_file_path = scripts_path + script_filename

    # Temporary docker compose filename
    compose_filename = f'docker-compose-sharded-no-server.yaml'
    compose_file_path = scripts_path + compose_filename

    no_server = True
    # Add workaround (copy files) till sharding only support is ready.
    try:
        if no_server:
            # Search & Replace content in the temporary compose files
            subprocess.run(
                ['cp', f'{scripts_path}docker-compose-sharded.yaml', f'{compose_file_path}'])
            admin_password = os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin'
            subprocess.run(['sed', '-i', f's/password/{admin_password}/g', f'{compose_file_path}'])
            subprocess.run(['sed', '-i', '/- test-network/a\\      - pmm-qa', f'{compose_file_path}'])
            subprocess.run(['sed', '-i', '/driver: bridge/a\\  pmm-qa:\\n    name: pmm-qa\\n    external: true',
                            f'{compose_file_path}'])
            subprocess.run(
                ['sed', '-i', '/^  pmm-server:/,/^$/{/^  test:/!d}', f'{compose_file_path}'])
            with open(f'{compose_file_path}', 'a') as f:
                subprocess.run(['echo', '   backups: null'], stdout=f, text=True, check=True)

            # Search replace content in the temporary shell files
            subprocess.run(['cp', f'{scripts_path}start-sharded.sh', f'{shell_file_path}'])
            subprocess.run(['sed', '-i', '/echo "configuring pmm-server/,/sleep 30/d',
                            f'{shell_file_path}'])
            subprocess.run(['sed', '-i', f's/docker-compose-sharded.yaml/{compose_filename}/g',
                            f'{shell_file_path}'])
    except subprocess.CalledProcessError as e:
        print(f"Error occurred: {e}")


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
        'PMM_SERVER_CONTAINER_ADDRESS': f'{args.pmm_server_ip}:443' or f'{container_name}:8443' or '127.0.0.1:443',
        'PSMDB_CONTAINER': 'psmdb_pmm_' + str(psmdb_version),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'PMM_CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'COMPOSE_PROFILES': get_value('COMPOSE_PROFILES', db_type, args, db_config),
        'MONGO_SETUP_TYPE': get_value('SETUP_TYPE', db_type, args, db_config),
        'TESTS': 'no',
        'CLEANUP': 'no'
    }

    compose_filename = ''
    shell_scripts = []
    if get_value('SETUP_TYPE', db_type, args, db_config).lower() == "pss":
        # Docker Compose filename
        compose_filename = 'docker-compose-rs.yaml'
        # Shell script names
        shell_scripts = ['configure-replset.sh', 'configure-agents.sh']

        # If profile is extra, include additional shell scripts
        if get_value('COMPOSE_PROFILES', db_type, args, db_config).lower() == "extra":
            shell_scripts.append('configure-extra-replset.sh')
            shell_scripts.append('configure-extra-agents.sh')
    elif get_value('SETUP_TYPE', db_type, args, db_config).lower() == "psa":
        # Docker Compose filename
        compose_filename = 'docker-compose-rs.yaml'
        # Shell script names
        shell_scripts = ['configure-psa.sh', 'configure-agents.sh']

        # If profile is extra, include additional shell scripts
        if get_value('COMPOSE_PROFILES', db_type, args, db_config).lower() == "extra":
            shell_scripts.append('configure-extra-psa.sh')
            shell_scripts.append('configure-extra-agents.sh')
    elif get_value('SETUP_TYPE', db_type, args, db_config).lower() == "shards":
        # Shell script names
        shell_scripts = [f'start-sharded-no-server.sh']
        mongo_sharding_setup(shell_scripts[0], args)

    # Define commands for compose file setup
    commands = {
        'down': ['-v', '--remove-orphans'],  # Cleanup containers
        'build': ['--no-cache'],  # Build containers
        'up': ['-d'],  # Start containers
    }
    # Call the function to run the Compose files
    if not compose_filename == '':
        execute_docker_compose(compose_filename, commands, env_vars, args)

    # Execute shell scripts
    if not shell_scripts == []:
        execute_shell_scripts(shell_scripts, env_vars, args)


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
    elif db_type == 'PS':
        setup_ps(db_type, db_version, db_config, args)
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
                             "--database mysql=5.7,QUERY_SOURCE=perfschema,SETUP_TYPE=gr,CLIENT_VERSION=3-dev-latest "
                             "--database pdpgsql=16,USE_SOCKET=1,CLIENT_VERSION=3.0.0 "
                             "--database psmdb=latest,SETUP_TYPE=psa,CLIENT_VERSION=3.0.0)")
    parser.add_argument("--pmm-server-ip", nargs='?', help='PMM Server IP to connect')
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

                    # Convert all arguments/options only to uppercase
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
