#!/bin/bash

dockerd --max-concurrent-downloads 1 --insecure-registry registry:4443 &

exec sleep infinity
