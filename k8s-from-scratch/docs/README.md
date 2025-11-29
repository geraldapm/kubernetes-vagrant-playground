# Tutorial to provision k8s cluster from scratch using Vagrant.

This repository contains a step-by-step tutorial to provision a Kubernetes cluster from scratch using Vagrant and VirtualBox. The tutorial is designed for educational purposes and aims to help users understand the inner workings of Kubernetes by building a cluster MANUALLY. 

Reference: https://github.com/kelseyhightower/kubernetes-the-hard-way

*NOTE: Requires linux system to follow this tutorial :)*

## Provision VM using vagrant
- Included scripts to initial provision VM and setup crio as CRI manually
- Included scripts to install keepalived as floating IP to adapt multi-node control-plane nodes
- It is recommended to use bastion host that has provisioned using vagrant. Run below command on the directory where Vagrantfile is located
```
vagrant up
```

## Define Control Plane and Worker Hostname & IPs
- We are using below configurations with POD IP range 10.244.0.0/16 and Service IP range 10.96.0.0/12. Make sure that /etc/hosts on each node server is identical to ease the installation.
- Make sure that each hostname resolution does not resolve to localhost! Check this problem https://github.com/kubernetes/kubernetes/issues/114073
```
# BAD
127.0.1.1 gpmrawk8s-controlplane1 gpmrawk8s-controplane1.vagrant.gpm.my.id
```
```
# Good
127.0.1.1 localhost
192.168.56.151 gpmrawk8s-controlplane1 gpmrawk8s-controlplane1.vagrant.gpm.my.id
```

```
192.168.56.151 gpmrawk8s-controlplane1 gpmrawk8s-controlplane1.vagrant.gpm.my.id
192.168.56.152 gpmrawk8s-controlplane2 gpmrawk8s-controlplane2.vagrant.gpm.my.id
192.168.56.153 gpmrawk8s-controlplane3 gpmrawk8s-controlplane3.vagrant.gpm.my.id
192.168.56.161 gpmrawk8s-worker1 gpmrawk8s-worker1.vagrant.gpm.my.id
192.168.56.162 gpmrawk8s-worker2 gpmrawk8s-worker2.vagrant.gpm.my.id
192.168.56.199 floating
```

## Provision CA Cert and underlying certificates (Very Important)
Initial CA configs are available on [../setup-configs/ca.conf](../setup-configs/ca.conf). Change the "10.96.0." depending on desired kubernetes service subnet range (defaults to 10.96.0.0/12).

- Generate CA certificates, used for all kubernetes component and etcd CA cert
```
{
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -sha512 -noenc \
    -key ca.key -days 3653 -subj "/CN=KUBERNETES-CA" \
    -config ca.conf \
    -out ca.crt
}
```
- Analyze CA cert
```
openssl x509 -noout -text -in ca.crt | grep -A4 -i issuer
```
- Generate All Kubernetes & ETCD Certificate. For convenience, we are using scripts to expand the variables and generating those certs. Please Change the Hostname and IP inside the script. The scripts are in [../setup-scripts/gencert.sh](../setup-scripts/gencert.sh).

- Verify generated certificates
```
for cert in $(ls *.crt); do openssl x509 -noout -text -in $cert | grep -A1 -iE "Subject:|Subject Alternative Name"; done
```
- Setup Copy file to each kubernetes nodes (requires passwordless login on origin server). NOTE: Change "gpmrawk8s" with hostname prefix for easy identifying and have those lists stored on /etc/hosts.
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  ssh root@${host} mkdir /var/lib/kubelet/
  scp ca.crt root@${host}:/var/lib/kubelet/
  scp ${host}.crt root@${host}:/var/lib/kubelet/kubelet.crt
  scp ${host}.key root@${host}:/var/lib/kubelet/kubelet.key
done
```
- Then copy kubernetes components certs into each of kubernetes control-planes
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /etc/kubernetes/pki
  scp \
    ca.key ca.crt \
    kube-apiserver.key kube-apiserver.crt \
    kube-apiserver-kubelet-client.key kube-apiserver-kubelet-client.crt \
    kube-apiserver-etcd-client.key kube-apiserver-etcd-client.crt \
    front-proxy-client.key front-proxy-client.crt \
    service-accounts.key service-accounts.crt \
    kube-etcd.key kube-etcd.crt \
    root@${host}:/etc/kubernetes/pki
done
```

# Generate kubeconfig for kubernetes components
Change "gpmrawk8s" with hostname prefix for easy identifying and have those lists stored on /etc/hosts.
- Install kubectl on origin server
```
export KUBERNETS_VERSION=1.32
sudo mkdir -p /etc/apt/trusted.gpg.d
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubectl
```
- Generate kubelet kubeconfig. Change floating IP and Change "gpmrawk8s" with hostname prefix for easy identifying and have those lists stored on /etc/hosts.
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  export FLOATING_IP=192.168.56.199
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
  unset FLOATING_IP
done
```
- Generate kube-proxy kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.crt \
    --client-key=kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-proxy.kubeconfig
}
unset FLOATING_IP
```
- Generate kube-controller-manager kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.crt \
    --client-key=kube-controller-manager.key \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-controller-manager.kubeconfig
}
unset FLOATING_IP
```
- Generate kube-scheduler kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.crt \
    --client-key=kube-scheduler.key \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-scheduler.kubeconfig
}
unset FLOATING_IP
```
- Generate kubernetes admin kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default \
    --kubeconfig=admin.kubeconfig
}
unset FLOATING_IP
```
- Copy the kubelet and kube-proxy kubeconfig files
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  ssh root@${host} "mkdir -p /var/lib/{kube-proxy,kubelet}"
  scp kube-proxy.kubeconfig root@${host}:/var/lib/kube-proxy/kubeconfig
  scp ${host}.kubeconfig root@${host}:/var/lib/kubelet/kubeconfig
done
```
- Finally copy the control-plane kubernetes components kubeconfig
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /etc/kubernetes
  scp admin.kubeconfig \
  kube-controller-manager.kubeconfig \
  kube-scheduler.kubeconfig \
    root@${host}:/etc/kubernetes
done
```

## Generate encryption-config
- Generate encryption-config.yaml
```
#!/bin/bash
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat << EOF | tee encryption-config.yaml
kind: EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```
- Copy encryption-config.yaml to each controlplane nodes
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /etc/kubernetes
  scp encryption-config.yaml root@${host}:/etc/kubernetes
done
```

## Bootstrap ETCD Cluster on each controlplane nodes
- Download & Extract etcd releases to /usr/local/bin
```
ETCD_VER=v3.6.6

# choose either URL
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GITHUB_URL}

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1 --no-same-owner
rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

/tmp/etcd-download-test/etcd --version
/tmp/etcd-download-test/etcdctl version
/tmp/etcd-download-test/etcdutl version

for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  scp /tmp/etcd-download-test/{etcd,etcdctl,etcdutl} root@${host}:/usr/local/bin
  ssh root@${host} /usr/local/bin/etcd --version
  ssh root@${host} /usr/local/bin/etcdctl version
  ssh root@${host} /usr/local/bin/etcdutl version
done
```
- Create etcd dir and etcd pki certs dir
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /var/lib/etcd /etc/kubernetes/pki/etcd
  ssh root@${host} useradd -m -s /sbin/nologin -U etcd -u 427
  ssh root@${host} chown -R etcd:etcd /var/lib/etcd
  scp {ca.crt,ca.key,kube-etcd.crt,kube-etcd.key} root@${host}:/etc/kubernetes/pki/etcd
  ssh root@${host} chown -R etcd:etcd /etc/kubernetes/pki/etcd
done
```
- Generate etcd-server systemd definition. Please Change the Hostname and IP inside the script. The scripts are in [../setup-scripts/etcd-systemd.sh](../setup-scripts/etcd-systemd.sh).
- Copy each of etcd-server Script into each controlplane nodes and start them.
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  scp etcd-${host}.service root@${host}:/etc/systemd/system/etcd.service
  ssh root@${host} systemctl daemon-reload
  ssh root@${host} systemctl enable etcd
  ssh root@${host} timeout 10s systemctl start etcd
  ssh root@${host} systemctl status etcd --no-pager
done
```
- Verify etcd member list. Change the TEST_IP env with one of control-plane IP
```
export TEST_IP=192.168.56.151
sudo ETCDCTL_API=3 /tmp/etcd-download-test/etcdctl member list \
  --endpoints=https://${TEST_IP}:2379 \
  --cacert=ca.crt \
  --cert=kube-etcd.crt \
  --key=kube-etcd.key
unset TEST_IP 
```

## Bootstrap kubernetes controlplane components on each controlplane nodes
This time we only want to provision kubernetes controlplane components only. Later on we can provision those controlplane nodes as workload with worker nodes altogether.
- Download Kubernetes Server binary. Adjust kubernetes versions as necessary
```
export KUBERNETES_VERSION_MINOR=v1.32.10
rm -f /tmp/kubernetes-server-linux-amd64.tar.gz
rm -rf /tmp/kubernetes-server && mkdir -p /tmp/kubernetes-server
curl -L https://dl.k8s.io/${KUBERNETES_VERSION_MINOR}/kubernetes-server-linux-amd64.tar.gz -o /tmp/kubernetes-server-linux-amd64.tar.gz
tar xzvf /tmp/kubernetes-server-linux-amd64.tar.gz -C /tmp/kubernetes-server --strip-components=1 --no-same-owner
rm -f /tmp/kubernetes-server-linux-amd64.tar.gz
```
- Copy Kubernetes Server binary to each kubernetes controlplane nodes.
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  scp /tmp/kubernetes-server/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager,kubelet,kube-proxy,kubectl} root@${host}:/usr/local/bin
  ssh root@${host} kube-apiserver --version
done
```
- Generate kubernetes controlplane systemd definition for each controlplane nodes. Please Change the Hostname and IP inside the script. The scripts are in [../setup-scripts/controlplane-systemd.sh](../setup-scripts/controlplane-systemd.sh).
- Copy kubernetes controlplane systemd definition and configs into each controlplane nodes and start the systemd services.
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  scp kube-apiserver-${host}.service root@${host}:/etc/systemd/system/kube-apiserver.service
  scp kube-controller-manager-${host}.service root@${host}:/etc/systemd/system/kube-controller-manager.service
  scp kube-scheduler-${host}.service root@${host}:/etc/systemd/system/kube-scheduler.service
  scp kube-scheduler.yaml root@${host}:/etc/kubernetes/kube-scheduler.yaml
  ssh root@${host} systemctl daemon-reload
  ssh root@${host} systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  ssh root@${host} timeout 10s systemctl start kube-apiserver kube-controller-manager kube-scheduler
  ssh root@${host} systemctl status kube-apiserver kube-controller-manager kube-scheduler --no-pager
done
```
- Apply kubelet-to-apiserver clusterrole for access authorization
```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```
- Verify kubernetes controlplane components is running
```
export FLOATING_IP=192.168.56.199
kubectl cluster-info --kubeconfig admin.kubeconfig
curl --cacert ca.crt https://${FLOATING_IP}:6443/version
unset FLOATING_IP=192.168.56.199
```

## Bootstrap kubernetes worker components on all nodes
This section will initialize worker components on kubernetes including existng kubernetes controlplane nodes.
- Install required packages for kubernetes port-forward while disabling swap
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
sudo apt-get -y install socat conntrack ipset
sudo swapon --show
sudo swapoff -a
done
```
- Download kubernetes worker components binary files
```
# Downloading kubernetes binary files was skipped because it's already download while provisioning controlplane components
export KUBERNETES_VERSION_MINOR=v1.32.10

export CRICTL_VERSION=v1.32.0
export RUNC_VERSION=v1.4.0
export CNI_PLUGINS_VERSION=v1.8.0

rm -f /tmp/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
rm -rf /tmp/kubernetes-tools && mkdir -p /tmp/kubernetes-tools
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -o /tmp/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
curl -L https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64 -o /tmp/kubernetes-tools/runc
curl -L https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz -o /tmp/kubernetes-tools/cni-plugins.tgz
tar xzvf /tmp/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C /tmp/kubernetes-tools
rm -f /tmp/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
```
- Install crictl, runc, and cni-plugins on all nodes
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  scp /tmp/kubernetes-tools/{crictl,runc} root@${host}:/usr/local/bin
  scp /tmp/kubernetes-server/server/bin/{kubelet,kube-proxy} root@${host}:/usr/local/bin
  scp /tmp/kubernetes-tools/cni-plugins.tgz root@${host}:/tmp/cni-plugins.tgz
  ssh root@${host} chmod +x /usr/local/bin/{crictl,runc}
  ssh root@${host} mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes
  ssh root@${host} sudo tar -xvf /tmp/cni-plugins.tgz -C /opt/cni/bin/
done
```
- Generate CNI default configs and copy to all nodes
```
export POD_CIDR="10.244.0.0/16"
export CNI_VERSION=1.0.0
cat <<EOF | sudo tee 10-bridge.conf
{
    "cniVersion": "${CNI_VERSION}",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF | sudo tee 99-loopback.conf
{
    "cniVersion": "${CNI_VERSION}",
    "name": "lo",
    "type": "loopback"
}
EOF

for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  scp {10-bridge.conf,99-loopback.conf} root@${host}:/etc/cni/net.d/
done
unset POD_CIDR
unset CNI_PLUGINS_VERSION
```
- Setup crio configurations on all nodes
```
cat <<EOF | tee 02-cgroup-manager.conf
[crio.runtime]
conmon_cgroup = "pod"
cgroup_manager = "cgroupfs"
EOF

cat <<EOF | tee 02-pod-management.conf
[crio.runtime]
default_runtime = "runc"

[crio.image]
pause_image="registry.k8s.io/pause:3.10"

[crio.network]
network_dir = "/etc/cni/net.d/"
plugin_dir = "/opt/cni/bin"
EOF

for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  scp {02-cgroup-manager.conf,02-pod-management.conf}  root@${host}:/etc/crio/conf.d/
  ssh root@${host} sudo systemctl restart crio
done
```
- Generate kubelet config and kube-proxy config incluing its systemd definition
```
export SERVICE_CIDR="10.96.0.0/12"
export POD_CIDR="10.244.0.0/16"
cat <<EOF | sudo tee kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: "0.0.0.0"
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubelet/ca.crt"
authorization:
  mode: Webhook
cgroupDriver: systemd
containerRuntimeEndpoint: "unix:///var/run/crio/crio.sock"
enableServer: true
failSwapOn: false
maxPods: 16
memorySwap:
  swapBehavior: NoSwap
clusterDomain: cluster.local
clusterDNS:
  - $(echo "$SERVICE_CIDR" | cut -d'.' -f1-3).10
podCIDR: "${POD_CIDR}"  
port: 10250
resolvConf: "/run/systemd/resolve/resolv.conf"
registerNode: true
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/kubelet.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/kubelet.key"
EOF

cat <<EOF | sudo tee kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${POD_CIDR}"
EOF

cat <<EOF | sudo tee kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=crio.service
Requires=crio.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/kubelet-config.yaml \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

unset SERVICE_CIDR
unset POD_CIDR
```
- Copy those configurations and start kubelet and kube-proxy
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  scp kubelet-config.yaml root@${host}:/var/lib/kubelet/kubelet-config.yaml
  scp kube-proxy-config.yaml root@${host}:/var/lib/kube-proxy/kube-proxy-config.yaml
  scp {kubelet.service,kube-proxy.service} root@${host}:/etc/systemd/system/
  ssh root@${host} systemctl daemon-reload
  ssh root@${host} systemctl enable kubelet kube-proxy
  ssh root@${host} timeout 10s systemctl start kubelet kube-proxy
  ssh root@${host} systemctl status kubelet kube-proxy --no-pager
done
```
- Verify kubernetes nodes status
```
kubectl get node  --kubeconfig admin.kubeconfig

NAME                      STATUS   ROLES    AGE     VERSION
gpmrawk8s-controlplane1   Ready    <none>   10h   v1.32.10
gpmrawk8s-controlplane2   Ready    <none>   10h   v1.32.10
gpmrawk8s-controlplane3   Ready    <none>   10h   v1.32.10
gpmrawk8s-worker1         Ready    <none>   10h   v1.32.10
gpmrawk8s-worker2         Ready    <none>   10h   v1.32.10
```
## Enable admin remote access
- Copy admin.kubeconfig to ~/.kube/config
```
mkdir -p ~/.kube
cp admin.kubeconfig ~/.kube/config
chmod 600 ~/.kube/config
```

## Enable Pod Cluster Networking
You can achieve this by installing Custom CNI or manually add pod routes based on this reference: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/11-pod-network-routes.md

In this tutorial we will use Cilium CNI to enable Pod Cluster Networking.
- Install Cilium CNI
```
### Replace API_SERVER_IP with Floating IP
API_SERVER_IP=192.168.56.199
API_SERVER_PORT=6443

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

/usr/local/bin/cilium install  --version 1.18.4 \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=${API_SERVER_IP} \
    --set k8sServicePort=${API_SERVER_PORT} \
    --set ipam.operator.clusterPoolIPv4PodCIDRList="10.244.0.0/16"
```
- Verify Cilium CNI installation
```
cilium status --wait
# CTRL+C to abort
cilium connectivity test
```

## Enable local DNS resolution with coreDNS
Apply following YAML with modified POD CIDR (important!)
```
export SERVICE_CIDR=10.96.0.0/12
cat <<EOF | tee coredns.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
rules:
  - apiGroups:
    - ""
    resources:
    - endpoints
    - services
    - pods
    - namespaces
    verbs:
    - list
    - watch
  - apiGroups:
    - discovery.k8s.io
    resources:
    - endpointslices
    verbs:
    - list
    - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf {
          max_concurrent 1000
        }
        cache 30
        #loop
        reload
        loadbalance
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: "CoreDNS"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      priorityClassName: system-cluster-critical
      serviceAccountName: coredns
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      nodeSelector:
        kubernetes.io/os: linux
      affinity:
         podAntiAffinity:
           requiredDuringSchedulingIgnoredDuringExecution:
           - labelSelector:
               matchExpressions:
               - key: k8s-app
                 operator: In
                 values: ["kube-dns"]
             topologyKey: kubernetes.io/hostname
      containers:
      - name: coredns
        image: coredns/coredns:1.9.4
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8181
            scheme: HTTP
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.96.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
  - name: metrics
    port: 9153
    protocol: TCP
EOF

kubectl apply -f coredns.yaml
```
- Verify DNS resolution
```
kubectl run --rm -it --image=busybox -- nslookup kubernetes.default.svc.cluster.local
```

## Final test: Sonobuoy conformance testing
This testing is intended to check if the newly-created kubernetes cluster from scratch is production-ready :D
Refer to this link: https://blog.yangjerry.tw/k8s-conformance-sonobuoy-en/
- Download sonobuoy and start the testing
```
curl -sfL -O https://github.com/vmware-tanzu/sonobuoy/releases/download/v0.57.2/sonobuoy_0.57.2_linux_amd64.tar.gz
tar -xzvf sonobuoy_0.57.2_linux_amd64.tar.gz
./sonobuoy run --mode=certified-conformance \
    --sonobuoy-image=docker.io/sonobuoy/sonobuoy:v0.57
    --systemd-logs-image=docker.io/sonobuoy/systemd-logs
```
- Check for around 2 hours check periodically with this command:
```
root@kube-1:~# ./sonobuoy status
         PLUGIN     STATUS   RESULT   COUNT                                PROGRESS
            e2e    running                1   Passed:  0, Failed:  0, Remaining:402
   systemd-logs   complete                3

### Completed sonobuoy
14:10:07 Sonobuoy has completed. Use `sonobuoy retrieve` to get results.
```
- Get current sonobuoy test result
```
 ./sonobuoy retrieve
```
- You can extract the file to get full logs and ensuring that the tests is succeeded. Now we have a production-ready kubernetes cluster :D
```
rm -rf results
mkdir results
outfile=$(sonobuoy retrieve)
tar xvzf $outfile -C results
cat results/plugins/e2e/results/global/e2e.log

# Eaxmple output
Ran 411 of 6624 Specs in 10397.268 seconds
SUCCESS! -- 411 Passed | 0 Failed | 0 Pending | 6213 Skipped
PASS

Ginkgo ran 1 suite in 2h53m49.05468171s
Test Suite Passed
```
- Cleanup sonobuoy tests
```
./sonobuoy delete
```


## Day-to-Day Operation 
To add new worker nodes, just follow the same steps as in "Bootstrap kubernetes worker components on all nodes" section.

## Renew kubernetes certificates
- Generate new certificates for all components. Please Change the Hostname and IP inside the script. The scripts are in [../setup-scripts/gencert.sh](../setup-scripts/gencert.sh).
- Verify generated certificates
```
for cert in $(ls *.crt); do openssl x509 -noout -text -in $cert | grep -A1 -iE "Subject:|Subject Alternative Name"; done
```
- Setup Copy file to each kubernetes nodes (requires passwordless login on origin server). NOTE: Change "gpmrawk8s" with hostname prefix for easy identifying and have those lists stored on /etc/hosts.
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  ssh root@${host} mkdir /var/lib/kubelet/
  scp ca.crt root@${host}:/var/lib/kubelet/
  scp ${host}.crt root@${host}:/var/lib/kubelet/kubelet.crt
  scp ${host}.key root@${host}:/var/lib/kubelet/kubelet.key
done
```
- Then copy kubernetes components certs into each of kubernetes control-planes
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /etc/kubernetes/pki
  scp \
    ca.key ca.crt \
    kube-apiserver.key kube-apiserver.crt \
    kube-apiserver-kubelet-client.key kube-apiserver-kubelet-client.crt \
    kube-apiserver-etcd-client.key kube-apiserver-etcd-client.crt \
    front-proxy-client.key front-proxy-client.crt \
    service-accounts.key service-accounts.crt \
    kube-etcd.key kube-etcd.crt \
    root@${host}:/etc/kubernetes/pki
done
```
- Generate kubelet kubeconfig. Change floating IP and Change "gpmrawk8s" with hostname prefix for easy identifying and have those lists stored on /etc/hosts.
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  export FLOATING_IP=192.168.56.199
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
  unset FLOATING_IP
done
```
- Generate kube-proxy kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.crt \
    --client-key=kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-proxy.kubeconfig
}
unset FLOATING_IP
```
- Generate kube-controller-manager kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.crt \
    --client-key=kube-controller-manager.key \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-controller-manager.kubeconfig
}
unset FLOATING_IP
```
- Generate kube-scheduler kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.crt \
    --client-key=kube-scheduler.key \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default \
    --kubeconfig=kube-scheduler.kubeconfig
}
unset FLOATING_IP
```
- Generate kubernetes admin kubeconfig
```
export FLOATING_IP=192.168.56.199
{
  kubectl config set-cluster gpmrawk8s \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${FLOATING_IP}:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=gpmrawk8s \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default \
    --kubeconfig=admin.kubeconfig
}
unset FLOATING_IP
```
- Copy the kubelet and kube-proxy kubeconfig files
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  ssh root@${host} "mkdir -p /var/lib/{kube-proxy,kubelet}"
  scp kube-proxy.kubeconfig root@${host}:/var/lib/kube-proxy/kubeconfig
  scp ${host}.kubeconfig root@${host}:/var/lib/kubelet/kubeconfig
done
```
- Finally copy the control-plane kubernetes components kubeconfig
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /etc/kubernetes
  scp admin.kubeconfig \
  kube-controller-manager.kubeconfig \
  kube-scheduler.kubeconfig \
    root@${host}:/etc/kubernetes
done
```
- Restart all controlplane components
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} systemctl daemon-reload
  ssh root@${host} timeout 10s systemctl restart kube-apiserver kube-controller-manager kube-scheduler etcd
  ### We are using keepalived to host the floating IP so it's need to be restarted
  ssh root@${host} timeout 10s systemctl restart keepalived
  ssh root@${host} systemctl status etcd --no-pager
done
```
- Restart all worker components
```
for host in $(cat /etc/hosts | grep "gpmrawk8s-" | awk '{print $2}' ); do
  ssh root@${host} systemctl daemon-reload
  ssh root@${host} timeout 10s systemctl restart kubelet kube-proxy
done
```

## Additional Notes:
- You should restart Cilium Pods and Cilium Operator when restarting kube-apiserver for coordinated sync.
```
kubectl rollout restart ds -n kube-system cilium
kubectl rollout restart deploy -n kube-system cilium-operator
```
- Currenty unfixed conformance tests error (FIXED with addition of front-proxy-client certs)
```
# Reproduce Error:
./sonobuoy run --plugin=e2e --e2e-focus="Sample API Server using the current Aggregator"  --sonobuoy-image=docker.io/sonobuoy/sonobuoy --systemd-logs-image=docker.io/sonobuoy/systemd-logs

Summarizing 1 Failure:
  [FAIL] [sig-api-machinery] Aggregator [It] Should be able to support the 1.17 Sample API Server using the current Aggregator [Conformance] [sig-api-machinery, Conformance]
  k8s.io/kubernetes/test/e2e/apimachinery/aggregator.go:419
```