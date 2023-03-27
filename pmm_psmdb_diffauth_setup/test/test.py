import docker
import pytest
import testinfra
import re
import datetime
import time

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
    one_minute_ago = datetime.datetime.now() - datetime.timedelta(minutes=1)
    logs = docker_pmm_client_host.logs(since=one_minute_ago).decode('utf-8')
    error_pattern = re.compile(r'.*(error).*Cannot connect to MongoDB.*', re.IGNORECASE)
    error_logs = '\n'.join(filter(error_pattern.search, logs.split('\n')))
    assert error_logs == '', f"Found error logs: {error_logs}"

def test_simple_auth():
     run_test('pmm-admin add mongodb psmdbserver --username=pmm_mongodb --password=password '\
              '--host psmdbserver --port 27017')

def test_simple_auth_tls():
     run_test('pmm-admin add mongodb psmdbserver --username=pmm_mongodb --password=password '\
              '--host psmdbserver --port 27017 '\
              '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt')

def test_x509_auth():
    run_test('pmm-admin add mongodb psmdbserver --host=psmdbserver --port 27017 '\
             '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt '\
             '--authentication-mechanism=MONGODB-X509 --authentication-database=\'$external\'')

def test_ldap_auth():
    run_test('pmm-admin add mongodb psmdbserver --username="cn=user01,ou=users,dc=example,dc=org" --password=password1 '\
             '--host=psmdbserver --port 27017 '\
             '--authentication-mechanism=PLAIN --authentication-database=\'$external\'')

def test_ldap_auth_tls():
    run_test('pmm-admin add mongodb psmdbserver --username="cn=user01,ou=users,dc=example,dc=org" --password=password1 '\
             '--host=psmdbserver --port 27017 '\
             '--authentication-mechanism=PLAIN --authentication-database=\'$external\' '\
             '--tls --tls-certificate-key-file=/pmm_data/certs/client.pem --tls-ca-file=/pmm_data/certs/ca.crt')
