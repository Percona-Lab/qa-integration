#!/bin/bash

# Read passed values.
for arg in "$@"
do
  case $arg in
    server_ip=*)
      server_ip="${arg#*=}"
      ;;
  esac
done

echo "The server IP is: $server_ip"
# Now you can use $server_ip anywhere in your script

echo "Set correct pmm server port, 8443 for docker image. 443 for ip address"
if [[ $server_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    export PMM_SERVER_PORT=443
else
    export PMM_SERVER_PORT=8443
fi

echo "Detect OS"
export OS_INFO=$(cat /etc/os-release)

echo $OS_INFO
echo $server_ip
echo $PMM_SERVER_PORT
