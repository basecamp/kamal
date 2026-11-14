#!/bin/bash

while [ ! -f /root/.ssh/authorized_keys ]; do echo "Waiting for ssh keys"; sleep 1; done

service ssh restart

# This dockerd's root is itself an overlay mount, so overlay2 can't nest. Use
# fuse-overlayfs for copy-on-write (vfs, the other option that nests, deep-copies
# every layer). /dev/fuse is available because the container is privileged.
mkdir -p /etc/docker
# Point this inner daemon at the hub-cache pull-through cache so Docker Hub base
# images are fetched at most once per run instead of on every test.
# Keep this daemon's own networks off 172.16.0.0/12, Docker's default address
# pool. The outer daemon allocates its bridge from that pool too, and hands
# containers its bridge gateway as their DNS upstream (resolv.conf ExtServers).
# An inner network landing on the same subnet shadows that address: the route
# stays inside this container, DNS to the outer host silently dies, and only
# name resolution breaks while raw IP traffic keeps working.
cat > /etc/docker/daemon.json <<'EOF'
{
  "storage-driver": "fuse-overlayfs",
  "registry-mirrors": [ "http://hub-cache:5000" ],
  "insecure-registries": [ "hub-cache:5000" ],
  "bip": "10.222.0.1/24",
  "default-address-pools": [ { "base": "10.223.0.0/16", "size": 24 } ]
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
