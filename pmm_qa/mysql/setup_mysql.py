import os
from scripts.get_env_value import get_value
from scripts.run_ansible_playbook import run_ansible_playbook

def setup_mysql_docker(db_type, container_name, db_config=None, args=None):
    env_vars = {
        'SETUP_TYPE': get_value('SETUP_TYPE', db_type, args, db_config).lower(),
        'MS_VERSION': get_value('MS_VERSION', db_type, args, db_config),
        'PMM_SERVER_IP': args.pmm_server_ip or container_name or '127.0.0.1',
        'CLIENT_VERSION': get_value('CLIENT_VERSION', db_type, args, db_config),
        'QUERY_SOURCE': get_value('QUERY_SOURCE', db_type, args, db_config),
        'ADMIN_PASSWORD': os.getenv('ADMIN_PASSWORD') or args.pmm_server_password or 'admin',
        'NODES_COUNT': get_value('NODES_COUNT', db_type, args, db_config),
    }

    run_ansible_playbook('mysql/mysql_setup.yml', env_vars, args)
