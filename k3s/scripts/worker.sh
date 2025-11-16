#!/bin/bash
#
# Setup for Worker Node servers

set -euxo pipefail

local_interface=$(ip route | grep $SUBNET | awk '{print $3'} | head -n 1)

curl -sfL https://get.k3s.io | K3S_TOKEN=K3SSECRET sh -s - agent --server https://$VIP_ADDRESS:6443 \
        --node-ip $CONTROL_IP \
        --flannel-iface=$local_interface