#!/bin/bash

while [ ! -f /root/.ssh/authorized_keys ]; do echo "Waiting for ssh keys"; sleep 1; done

service ssh restart

dockerd --max-concurrent-downloads 1 &

exec sleep infinity
