#!/bin/bash

cp -r * /shared

trap "pkill -f sleep" term

sleep infinity & wait
