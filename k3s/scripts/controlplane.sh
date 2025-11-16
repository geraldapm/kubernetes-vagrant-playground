#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)
local_interface=$(ip route | grep $SUBNET | awk '{print $3'} | head -n 1)

curl -sfL https://get.k3s.io | K3S_TOKEN=K3SSECRET sh -s - server \
    --cluster-init \
    --advertise-address $CONTROL_IP \
    --node-ip $CONTROL_IP\
    --cluster-cidr=$POD_CIDR \
    --service-cidr=$SERVICE_CIDR \
    --tls-san=$VIP_ADDRESS \
    --flannel-backend=none --disable-network-policy \
    --flannel-iface=$local_interface

# Make sure kubectl is set up for the vagrant user
sudo mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube/config

sed -i 's/127.0.0.1/$VIP_ADDRESS/' /home/vagrant/.kube/config

echo "First Control Plane Setup Completed"

