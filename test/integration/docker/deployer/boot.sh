#!/bin/bash

# Use VFS storage driver locally to avoid overlayfs-on-overlayfs issues
# Skip on GitHub Actions where the outer Docker is configured differently
if [ -z "$GITHUB_ACTIONS" ]; then
  mkdir -p /etc/docker
  echo '{"storage-driver": "vfs"}' > /etc/docker/daemon.json
fi

dockerd --max-concurrent-downloads 1 &

exec sleep infinity
