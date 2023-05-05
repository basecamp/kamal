#!/bin/bash

git commit -am 'Update rev' --amend
git rev-parse HEAD > version
