#!/bin/sh

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi

  shift
done

docker stop alertmanager && docker rm -fv alertmanager
sleep 10
docker run -d -p 9093:9093 --name alertmanager prom/alertmanager:latest
sleep 20
docker network connect pmm-qa alertmanager
