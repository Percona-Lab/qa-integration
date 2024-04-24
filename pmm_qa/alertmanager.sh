#!/bin/sh

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi

  shift
done

docker stop alert-manager && docker rm -fv alert-manager
sleep 10
docker run -d -p 9093:9093 --name alert-manager prom/alertmanager:latest
sleep 20
