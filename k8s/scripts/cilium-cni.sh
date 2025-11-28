#!/bin/bash
#
# Install Cilium CNI Network Plugin
set -euxo pipefail

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

### Example if needed more than one subnet range
#/usr/local/bin/cilium upgrade --version 1.18.4 --set ipam.operator.clusterPoolIPv4PodCIDRList="1${POD_CIDR} 10.245.0.0/16"

#API_SERVER_IP=$FLOATING_IP
API_SERVER_IP=192.168.56.99
API_SERVER_PORT=6443

/usr/local/bin/cilium install --version 1.18.4 \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=${API_SERVER_IP} \
    --set k8sServicePort=${API_SERVER_PORT} \
    --set ipam.operator.clusterPoolIPv4PodCIDRList=${POD_CIDR}