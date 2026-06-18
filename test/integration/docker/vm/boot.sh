#!/bin/bash

while [ ! -f /root/.ssh/authorized_keys ]; do echo "Waiting for ssh keys"; sleep 1; done

service ssh restart

# Use the fuse-overlayfs storage driver: this dockerd runs inside a container whose
# root is itself an overlay mount, and native overlay2-on-overlay fails on modern
# Docker/kernels. fuse-overlayfs gives copy-on-write layering over the overlay root
# (unlike vfs, which deep-copies every layer), so builds/pulls/container-creates are
# far cheaper. Needs /dev/fuse, available because the container is privileged.
mkdir -p /etc/docker
# Point this inner daemon at the hub-cache pull-through cache so Docker Hub base
# images are fetched at most once per run instead of on every test.
cat > /etc/docker/daemon.json <<'EOF'
{
  "storage-driver": "fuse-overlayfs",
  "registry-mirrors": [ "http://hub-cache:5000" ],
  "insecure-registries": [ "hub-cache:5000" ]
}
EOF

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
