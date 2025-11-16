#!/bin/bash
#
# Setup for Worker Node servers

set -euxo pipefail

config_path="/vagrant/configs"

/bin/bash $config_path/worker-join.sh -v

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
sudo chmod 600 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker

sudo cp /vagrant/configs/kubernetes-ca.crt /usr/local/share/ca-certificates/kubernetes-ca.crt
sudo update-ca-certificates
EOF