#!/bin/sh

while [ ! -f /certs/domain.crt ]; do sleep 1; done

trap "pkill -f registry" term

/entrypoint.sh /etc/docker/registry/config.yml & wait
