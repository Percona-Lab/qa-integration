import docker
import pytest
import testinfra
import re
import time
import os
import json

env_vars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_USERNAME']

client = docker.from_env()
docker_pmm_client = testinfra.get_host('docker://psmdb-server')


def run_test(add_db_command):
    try:
        docker_pmm_client.check_output('pmm-admin remove mongodb psmdb-server', timeout=30)
    except AssertionError:
        pass
    try:
        docker_pmm_client.check_output(add_db_command, timeout=30)
    except AssertionError:
        pytest.fail("Fail to add MongoDB to pmm-admin")
    time.sleep(30)

    pmm_admin_list = json.loads(docker_pmm_client.check_output('pmm-admin list --json', timeout=30))
    for agent in pmm_admin_list['agent']:
        if agent['agent_type'] == 'MONGODB_EXPORTER':
            agent_id = agent['agent_id']
            agent_port = agent['port']
            break

    url = f'http://localhost:{agent_port}/metrics'
    try:
        response = docker_pmm_client.check_output(f"curl --request GET --url {url} --header 'Content-Type: "
                                                  f"application/json' --user 'pmm:{agent_id}'")
        pattern = r'mongodb_up (\d+)'
        result = re.search(pattern, response)
        assert result is not None, "MongoDB related data isn't exported"
    except AssertionError:
        pytest.fail(f"Connection to {url} failed")

def test_simple_auth_wo_tls():
    run_test('pmm-admin add mongodb psmdb-server --username=pmm_mongodb --password="5M](Q%q/U+YQ<^m" ''--host '
             'psmdb-server --port 27017')


def test_simple_auth_tls():
    run_test('pmm-admin add mongodb psmdb-server --username=pmm_mongodb --password="5M](Q%q/U+YQ<^m" '
             '--host psmdb-server --port 27017 '
             '--tls --tls-certificate-key-file=/mongodb_certs/client.pem --tls-ca-file=/mongodb_certs/ca-certs.pem '
             '--cluster=mycluster')


def test_x509_auth():
    run_test('pmm-admin add mongodb psmdb-server --host=psmdb-server --port 27017 '
             '--tls --tls-certificate-key-file=/mongodb_certs/client.pem --tls-ca-file=/mongodb_certs/ca-certs.pem '
             '--authentication-mechanism=MONGODB-X509 --authentication-database=\'$external\' '
             '--cluster=mycluster')


def test_ldap_auth_wo_tls():
    run_test('pmm-admin add mongodb psmdb-server --username="CN=pmm-test" --password=password1 '
             '--host=psmdb-server --port 27017 '
             '--authentication-mechanism=PLAIN --authentication-database=\'$external\' '
             '--cluster=mycluster')


def test_ldap_auth_tls():
    run_test('pmm-admin add mongodb psmdb-server --username="CN=pmm-test" --password=password1 '
             '--host=psmdb-server --port 27017 '
             '--authentication-mechanism=PLAIN --authentication-database=\'$external\' '
             '--tls --tls-certificate-key-file=/mongodb_certs/client.pem --tls-ca-file=/mongodb_certs/ca-certs.pem '
             '--cluster=mycluster')


@pytest.mark.skipif(
    any(not os.environ.get(var) for var in env_vars) or os.environ.get('SKIP_AWS_TESTS') == 'true',
    reason=f"One or more of AWS env var isn't defined or SKIP_AWS_TESTS is set to true")
def test_aws_auth_wo_tls():
    run_test('pmm-admin add mongodb psmdb-server --username=' + os.environ.get('AWS_ACCESS_KEY_ID') + ' ' \
                                                                                                      '--password=' + os.environ.get(
        'AWS_SECRET_ACCESS_KEY') + ' ' \
                                   '--host=psmdb-server --port 27017 ' \
                                   '--authentication-mechanism=MONGODB-AWS --authentication-database=\'$external\' ' \
                                   '--cluster=mycluster')


@pytest.mark.skipif(
    any(not os.environ.get(var) for var in env_vars) or os.environ.get('SKIP_AWS_TESTS') == 'true',
    reason=f"One or more of AWS env var isn't defined or SKIP_AWS_TESTS is set to true")
def test_aws_auth_tls():
    run_test('pmm-admin add mongodb psmdb-server --username=' + os.environ.get('AWS_ACCESS_KEY_ID') + ' ' \
                                                                                                      '--password=' + os.environ.get(
        'AWS_SECRET_ACCESS_KEY') + ' ' \
                                   '--host=psmdb-server --port 27017 ' \
                                   '--authentication-mechanism=MONGODB-AWS --authentication-database=\'$external\' ' \
                                   '--tls --tls-certificate-key-file=/mongodb_certs/client.pem --tls-ca-file=/mongodb_certs/ca-certs.pem ' \
                                   '--cluster=mycluster')
