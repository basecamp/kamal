#!/bin/bash

cd $1 && cp -f config/deploy_renamed_roles.yml config/deploy.yml && git commit -am 'Rename roles'
