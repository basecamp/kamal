#!/bin/sh

while [ ! -f /certs/domain.crt ]; do sleep 1; done

exec /entrypoint.sh /etc/distribution/config.yml
