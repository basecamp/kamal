#!/bin/bash

# Use the VFS storage driver: this dockerd runs inside a container whose root is
# itself an overlay mount, and overlay-on-overlay fails on modern Docker/kernels.
# VFS nests safely.
mkdir -p /etc/docker
echo '{"storage-driver": "vfs"}' > /etc/docker/daemon.json

# Docker needs an iptables backend that can initialize the nat table against the
# host kernel. Legacy works on hosts with the legacy ip_tables modules loaded;
# nft works on nftables-only hosts (where the legacy nat table is unavailable).
# Probe for the first backend that can read the nat table and use it.
for backend in legacy nft; do
  if iptables-$backend -t nat -L >/dev/null 2>&1; then
    update-alternatives --set iptables /usr/sbin/iptables-$backend 2>/dev/null || true
    update-alternatives --set ip6tables /usr/sbin/ip6tables-$backend 2>/dev/null || true
    break
  fi
done

dockerd --max-concurrent-downloads 1 &

exec sleep infinity
