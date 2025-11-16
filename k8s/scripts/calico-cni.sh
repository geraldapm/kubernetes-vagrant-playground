#!/bin/bash
#
# Install Calico CNI Network Plugin with tigera operator
set -euxo pipefail

# install Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.1/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.1/manifests/tigera-operator.yaml

# install Calico ebpf custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.1/manifests/custom-resources-bpf.yaml

# Get current subnet interface
local_interface=$(ip route | grep $SUBNET | awk '{print $3'} | head -n 1)

cat <<EOF | kubectl apply -f -
# This section includes base Calico installation configuration.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    linuxDataplane: BPF

### Select the main subnet IP interface because vagrant has 2 distict network interfaces
    nodeAddressAutodetectionV4:
      interface: "${local_interface}"

    bpfNetworkBootstrap: Enabled
    kubeProxyManagement: Enabled
    ipPools:
      - name: default-ipv4-ippool
        blockSize: 26
        cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()

---
# This section configures the Calico API server.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}

---
# Configures the Calico Goldmane flow aggregator.
apiVersion: operator.tigera.io/v1
kind: Goldmane
metadata:
  name: default

---
# Configures the Calico Whisker observability UI.
apiVersion: operator.tigera.io/v1
kind: Whisker
metadata:
  name: default
EOF

# curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml -O
# kubectl apply -f calico.yaml

# Install Metrics Server
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
