#!/bin/bash

# Use VFS storage driver locally to avoid overlayfs-on-overlayfs issues
# Skip on GitHub Actions where the outer Docker is configured differently
if [ -z "$GITHUB_ACTIONS" ]; then
  mkdir -p /etc/docker
  echo '{"storage-driver": "vfs"}' > /etc/docker/daemon.json
fi

# On hosts using nftables, Docker can't create netfilter rules from inside a container.
# iptables-legacy uses an older kernel interface that doesn't have this limitation.
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

dockerd --max-concurrent-downloads 1 &

exec sleep infinity
