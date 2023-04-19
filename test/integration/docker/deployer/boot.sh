#!/bin/bash

cd /mrsk && gem build mrsk.gemspec -o /tmp/mrsk.gem && gem install /tmp/mrsk.gem

dockerd &

trap "pkill -f sleep" term

sleep infinity & wait
