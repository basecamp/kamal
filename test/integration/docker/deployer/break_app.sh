#!/bin/bash

cd $1 && echo "bad nginx config" > default.conf && git commit -am 'Broken'
