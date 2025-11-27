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
#/usr/local/bin/cilium install --version 1.18.4 --set ipam.operator.clusterPoolIPv4PodCIDRList="{\"${POD_CIDR}\", \"10.0.84.0/28\"}"

/usr/local/bin/cilium install --version 1.18.4 --set ipam.operator.clusterPoolIPv4PodCIDRList="{\"${POD_CIDR}\"}"