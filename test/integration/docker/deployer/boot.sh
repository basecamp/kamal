#!/bin/bash

dockerd --max-concurrent-downloads 1 &

exec sleep infinity
