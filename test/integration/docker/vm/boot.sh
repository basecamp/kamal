#!/bin/bash

while [ ! -f /root/.ssh/authorized_keys ]; do echo "Waiting for ssh keys"; sleep 1; done

service ssh restart

# On hosts using nftables, Docker can't create netfilter rules from inside a container.
# iptables-legacy uses an older kernel interface that doesn't have this limitation.
update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

dockerd --max-concurrent-downloads 1 &

exec sleep infinity
