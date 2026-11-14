#!/bin/bash

# Fail loudly: a failed gem install here otherwise surfaces much later as a
# confusing "kamal: executable file not found in $PATH".
set -euo pipefail

install_kamal() {
  cd /kamal && gem build kamal.gemspec -o /tmp/kamal.gem && gem install /tmp/kamal.gem
}

install_kamal

# Seed the private registry with the proxy image (fetched once via the hub_cache
# mirror) so the proxy.run.registry option stays exercised by the suite — see
# app_with_roles, which pulls its proxy from registry:4443 rather than the Hub.
docker pull basecamp/kamal-proxy:v0.9.2
docker tag basecamp/kamal-proxy:v0.9.2 registry:4443/basecamp/kamal-proxy:v0.9.2
docker push registry:4443/basecamp/kamal-proxy:v0.9.2

# .ssh is on a shared volume that persists between runs. Clean it up as the
# churn of temporary vm IPs can eventually create conflicts.
rm -f /root/.ssh/known_hosts
