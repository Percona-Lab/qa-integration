import docker
import pytest
import testinfra
import re
import datetime
import time
import os
import json
import requests

env_vars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']

client = docker.from_env()
docker_pmm_client_host = client.containers.get('pmm-client')
docker_pmm_client = testinfra.get_host('docker://pmm-client')

def run_test(add_db_command):
    try:
        docker_pmm_client.check_output('pmm-admin remove mongodb psmdbserver', timeout=30)
    except AssertionError:
        pass
    try:
        docker_pmm_client.check_output(add_db_command, timeout=30)
    except AssertionError:
        pytest.fail("Fail to add MongoDB to pmm-admin")
    time.sleep(60)

    pmm_admin_list = json.loads(docker_pmm_client.check_output('pmm-admin list --json', timeout=30))
    for agent in pmm_admin_list['agent']:
      if agent['agent_type'] == 'MONGODB_EXPORTER':
         agent_id = agent['agent_id']
         agent_port = agent['port']
         break

    url = f'http://pmm-client:{agent_port}/metrics'
    try:
        response = requests.get(url, auth=('pmm', agent_id), timeout=5)
        assert response.status_code == 200, f"Request for metrics failed with status code {response.status_code}"
        pattern = r'mongodb_up (\d+)'
        result = re.search(pattern, response.text)
        assert result is not None, "MongoDB related data isn't exported"
    except requests.exceptions.ConnectionError:
        pytest.fail(f"Connection to {url} failed")

    one_minute_ago = datetime.datetime.now() - datetime.timedelta(seconds=30)
    logs = docker_pmm_client_host.logs(since=one_minute_ago).decode('utf-8')
    error_pattern = re.compile(r'.*(ERR|ERRO|error).*\b(cannot(?=.*(?:connect|get|retrieve|decode|load|create)))\b.*(mongodb_exporter).*', re.IGNORECASE)
    error_logs = '\n'.join(filter(error_pattern.search, logs.split('\n')))
    assert error_logs == '', f"Found error logs: {error_logs}"

def test_simple_auth():
     run_test('pmm-admin add mongodb psmdbserver --username=pmm_mongodb --password="5M](Q%q/U+YQ<^m" '\
              '--host psmdbserver --port 27017')

def test_simple_auth_tls():
     run_test('pmm-admin add mongodb psmdbserver --username=pmm_mongodb --password="5M](Q%q/U+YQ<^m" '\
              '--host psmdbserver --port 27017 '\
              '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt')

def test_x509_auth():
    run_test('pmm-admin add mongodb psmdbserver --host=psmdbserver --port 27017 '\
             '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt '\
             '--authentication-mechanism=MONGODB-X509 --authentication-database=\'$external\'')

def test_ldap_auth():
    run_test('pmm-admin add mongodb psmdbserver --username="CN=pmm-test" --password=password1 '\
             '--host=psmdbserver --port 27017 '\
             '--authentication-mechanism=PLAIN --authentication-database=\'$external\'')

def test_ldap_auth_tls():
    run_test('pmm-admin add mongodb psmdbserver --username="CN=pmm-test" --password=password1 '\
             '--host=psmdbserver --port 27017 '\
             '--authentication-mechanism=PLAIN --authentication-database=\'$external\' '\
             '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt')

@pytest.mark.skipif(
    any(not os.environ.get(var) for var in env_vars),
    reason=f"One or more of {env_vars} not defined")
def test_aws_auth():
    run_test('pmm-admin add mongodb psmdbserver --username='+ os.environ.get('AWS_ACCESS_KEY_ID') +' '\
             '--password='+ os.environ.get('AWS_SECRET_ACCESS_KEY') +' '\
             '--host=psmdbserver --port 27017 '\
             '--authentication-mechanism=MONGODB-AWS --authentication-database=\'$external\'')

@pytest.mark.skipif(
    any(not os.environ.get(var) for var in env_vars),
    reason=f"One or more of {env_vars} not defined")
def test_aws_auth_tls():
    run_test('pmm-admin add mongodb psmdbserver --username='+ os.environ.get('AWS_ACCESS_KEY_ID') +' '\
             '--password='+ os.environ.get('AWS_SECRET_ACCESS_KEY') +' '\
             '--host=psmdbserver --port 27017 '\
             '--authentication-mechanism=MONGODB-AWS --authentication-database=\'$external\' '\
             '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt')
