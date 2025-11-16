#!/bin/bash
#
# Setup for Remaining Control Plane Node servers

set -euxo pipefail

sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"

config_path="/vagrant/configs"

# /bin/bash $config_path/controlplane-join.sh -v

# Join the remaining control-plane with advertise address
echo "$(cat /vagrant/configs/controlplane-join.sh) -v=5 --apiserver-advertise-address $CONTROL_IP" | sudo bash

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
sudo chmod 600 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
sudo cp /vagrant/configs/kubernetes-ca.crt /usr/local/share/ca-certificates/kubernetes-ca.crt
sudo update-ca-certificates
EOF

echo "Remaining Control Plane Node Setup Completed"