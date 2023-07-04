#!/bin/bash

#Fetch PMM-QA Repo, this contains pmm-framework script, playbook required for the tests
#$PS_VERSION Variable will be fetched from the github actions env variable.

echo $PS_VERSION

PS_TARBALL_PATH=https://downloads.percona.com/downloads/TESTING/ps-$PS_VERSION/Percona-Server-$PS_VERSION-Linux.x86_64.glibc2.28.tar.gz

# Delete if the Repo already checkedout
sudo rm -r pmm-qa || true 

git clone -b master https://github.com/percona/pmm-qa/

# Give write perimssion to the bash script
chmod +x ./pmm-tests/pmm-framework.sh
        
#Run the pmm container in backgrounds
docker run --detach --restart always --publish 443:443 --name pmm-server $PMM_IMAGE

#Change directory to pmm-tests
cd pmm-tests

#Run for ms version and ms client 1
./pmm-framework.sh --ms-version $PS_VERSION --addclient=ms,1 --pmm2 --ps_tarball_url=$PS_TARBALL_PATH

#Run for ps version and ps client 1
./pmm-framework.sh --ps-version $PS_VERSION --addclient=ps,1 --pmm2 --ps_tarball_url=$PS_TARBALL_PATH
