#!/bin/bash

install_mrsk() {
  cd /mrsk && gem build mrsk.gemspec -o /tmp/mrsk.gem && gem install /tmp/mrsk.gem
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

install_mrsk
push_image_to_registry_4443 nginx 1-alpine-slim
push_image_to_registry_4443 traefik v2.9
push_image_to_registry_4443 busybox 1.36.0
