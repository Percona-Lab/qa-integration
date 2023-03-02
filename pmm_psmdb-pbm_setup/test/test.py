import requests
import docker
import pytest
import testinfra
import time
import json

docker_rs101 = testinfra.get_host('docker://rs101')
docker_rs102 = testinfra.get_host('docker://rs102')
docker_rs103 = testinfra.get_host('docker://rs103')
testinfra_hosts = ['docker://rs101','docker://rs102','docker://rs103']

pytest.location_id = ''
pytest.service_id = ''
pytest.artifact_id = ''
pytest.artifact_name = ''
pytest.pbm_backup_name = ''
pytest.restore_id = ''

def test_pmm_services():
    req = requests.post('https://pmm-server/v1/inventory/Services/List',json={},headers = {"authorization": "Basic YWRtaW46cGFzc3dvcmQ="},verify=False)
    print('\nGetting all mongodb services:')
    mongodb = req.json()['mongodb']
    print(mongodb)
    assert mongodb
    assert "service_id" in mongodb[0]['service_id']
    for service in mongodb:
        assert "rs" or "mongos" in service['service_name']
        if not "mongos" in service['service_name']:
             pytest.service_id = service['service_id']
    print('This service_id will be used in the next steps')
    print(pytest.service_id)

def test_pmm_add_location():
    data = {
        'name': 'test',
        'description': 'test',
        's3_config': {
          'endpoint': 'http://minio:9000',
          'access_key': 'minio1234',
          'secret_key': 'minio1234',
          'bucket_name': 'bcp'
          }
        }
    req = requests.post('https://pmm-server/v1/management/backup/Locations/Add',json=data,headers = {"authorization": "Basic YWRtaW46cGFzc3dvcmQ="},verify=False)
    print('\nAdding new location:')
    print(req.json())
    assert "location_id" in req.json()['location_id']
    pytest.location_id = req.json()['location_id']

def test_pmm_logical_backup():
    data = {
        'service_id': pytest.service_id,
        'location_id': pytest.location_id,
        'name': 'test',
        'description': 'test',
        'retries': 0,
        'data_model': 'LOGICAL'
        }
    req = requests.post('https://pmm-server/v1/management/backup/Backups/Start',json=data,headers = {"authorization": "Basic YWRtaW46cGFzc3dvcmQ="},verify=False)
    print('\nCreating logical backup:')
    print(req.json())
    assert "artifact_id" in req.json()['artifact_id']
    pytest.artifact_id = req.json()['artifact_id']

def test_pmm_artifact():
    backup_complete = False
    for i in range(600):
        done = False
        req = requests.post('https://pmm-server/v1/management/backup/Artifacts/List',json={},headers = {"authorization": "Basic YWRtaW46cGFzc3dvcmQ="},verify=False)
        assert req.json()['artifacts']
        for artifact in req.json()['artifacts']:
            if artifact['artifact_id'] == pytest.artifact_id:
                print('\nChecking artifact status')
                print(artifact['status'])
                if artifact['status'] == "BACKUP_STATUS_SUCCESS":
                    done = True
                    print('Artifact data:')
                    print(artifact)
                    pytest.artifact_name = artifact['name']
                    break
        if done:
            backup_complete = True
            break
        else:
            time.sleep(1)
    assert backup_complete

def test_pbm_artifact():
    status = docker_rs101.check_output('pbm status --out json')
    parsed_status = json.loads(status)
    print('\nChecking if the backup is completed in pbm status')
    print(parsed_status)
    assert pytest.artifact_name in parsed_status['backups']['path']
    assert parsed_status['backups']['snapshot'][0]['status'] == "done"
    pytest.pbm_backup_name = parsed_status['backups']['snapshot'][0]['name']

def test_pmm_start_restore():
    data = {
        'service_id': pytest.service_id,
        'artifact_id': pytest.artifact_id
        }
    req = requests.post('https://pmm-server/v1/management/backup/Backups/Restore',json=data,headers = {"authorization": "Basic YWRtaW46cGFzc3dvcmQ="},verify=False)
    print('\nRestoring logical backup:')
    print(req.json())
    assert "restore_id" in req.json()['restore_id']
    pytest.restore_id = req.json()['restore_id']

def test_pmm_restore():
    restore_complete = False
    for i in range(600):
        done = False
        req = requests.post('https://pmm-server/v1/management/backup/RestoreHistory/List',json={},headers = {"authorization": "Basic YWRtaW46cGFzc3dvcmQ="},verify=False)
        assert req.json()['items']
        for item in req.json()['items']:
            if item['restore_id'] == pytest.restore_id:
                print('\nChecking restore status')
                print(item['status'])
                if item['status'] == "RESTORE_STATUS_SUCCESS":
                    done = True
                    print('Restore data:')
                    print(item)
                    break
        if done:
            restore_complete = True
            break
        else:
            time.sleep(1)
    assert restore_complete

def test_pbm_restore():
    restore_list = docker_rs101.check_output('pbm list --restore --out json')
    parsed_restore_list = json.loads(restore_list)
    print('\nChecking if the restore is completed in pbm status')
    print(parsed_restore_list)
    restore_complete = False
    for restore in parsed_restore_list:
        if restore['snapshot'] == pytest.pbm_backup_name:
            assert restore['status'] == "done"
            restore_complete = True

    assert restore_complete
