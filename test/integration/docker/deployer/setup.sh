#!/bin/bash

install_kamal() {
  cd /kamal && gem build kamal.gemspec -o /tmp/kamal.gem && gem install /tmp/kamal.gem
}

# Push the images to a persistent volume on the registry container
# This is to work around docker hub rate limits
push_image_to_registry_4443() {
  # Check if the image is in the registry without having to pull it
  if ! stat /registry/docker/registry/v2/repositories/$1/_manifests/tags/$2/current/link > /dev/null; then
    hub_tag=$1:$2
    registry_4443_tag=registry:4443/$1:$2
    docker pull $hub_tag
    docker tag $hub_tag $registry_4443_tag
    docker push $registry_4443_tag
  fi
}

install_kamal
push_image_to_registry_4443 nginx 1-alpine-slim
push_image_to_registry_4443 busybox 1.36.0

# .ssh is on a shared volume that persists between runs. Clean it up as the
# churn of temporary vm IPs can eventually create conflicts.
rm -f /root/.ssh/known_hosts
