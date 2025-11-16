#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)

sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"


# Save Configs to shared /Vagrant location

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

# Initialize the Control Plane with custom pod and service CIDR and node-port range
kubeadm init --control-plane-endpoint=$VIP_ADDRESS --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP,$VIP_ADDRESS --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
sudo chmod 600 "$HOME"/.kube/config

# Create control plane join script
touch $config_path/controlplane-join.sh
chmod +x $config_path/controlplane-join.sh
kubeadm token create --print-join-command --certificate-key "$(kubeadm init phase upload-certs --upload-certs | tail -n 1)" > $config_path/controlplane-join.sh

# Create worker join script and save admin kubeconfig
cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/worker-join.sh
chmod +x $config_path/worker-join.sh
kubeadm token create --print-join-command > $config_path/worker-join.sh

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
sudo chmod 600 /home/vagrant/.kube/config

sudo cp /etc/kubernetes/pki/ca.crt /usr/local/share/ca-certificates/kubernetes-ca.crt
sudo cp /etc/kubernetes/pki/ca.crt /vagrant/configs/kubernetes-ca.crt
sudo update-ca-certificates
EOF

echo "First Control Plane Setup Completed"

