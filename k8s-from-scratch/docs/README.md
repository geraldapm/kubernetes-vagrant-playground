# Tutorial to provision k8s cluster from scratch using Vagrant.

This repository contains a step-by-step tutorial to provision a Kubernetes cluster from scratch using Vagrant and VirtualBox. The tutorial is designed for educational purposes and aims to help users understand the inner workings of Kubernetes by building a cluster MANUALLY. 

Reference: https://github.com/kelseyhightower/kubernetes-the-hard-way

*NOTE: Requires linux system to follow this tutorial :)*

## Provision VM using vagrant
- Included scripts to initial provision VM and setup crio as CRI manually
- Included scripts to install keepalived as floating IP to adapt multi-node control-plane nodes

## Define Control Plane and Worker Hostname & IPs
- We are using below configurations with POD IP range 10.244.0.0/16 and Service IP range 10.96.0.0/12. Make sure that /etc/hosts on each node server is identical to ease the installation.
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
for host in $(cat /etc/hosts | grep gpmrawk8s | awk '{print $2}' ); do
  ssh root@${host} mkdir /var/lib/kubelet/

  scp ca.crt root@${host}:/var/lib/kubelet/

  scp ${host}.crt \
    root@${host}:/var/lib/kubelet/kubelet.crt

  scp ${host}.key \
    root@${host}:/var/lib/kubelet/kubelet.key
done
```
- Then copy kubernetes components certs into each of kubernetes control-planes
```
for host in $(cat /etc/hosts | grep gpmrawk8s-controlplane | awk '{print $2}' ); do
  ssh root@${host} mkdir -p /etc/kubernetes/pki
  scp \
    ca.key ca.crt \
    kube-apiserver.key kube-apiserver.crt \
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
sudo apt-get install -y kubelet kubectl kubeadm cri-o jq
```
- Generate kubelet kubeconfig. Change floating IP and Change "gpmrawk8s" with hostname prefix for easy identifying and have those lists stored on /etc/hosts.
```
for host in $(cat /etc/hosts | grep gpmrawk8s | awk '{print $2}' ); do
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
for host in $(cat /etc/hosts | grep gpmrawk8s | awk '{print $2}' ); do
  ssh root@${host} "mkdir -p /var/lib/{kube-proxy,kubelet}"

  scp kube-proxy.kubeconfig \
    root@${host}:/var/lib/kube-proxy/kubeconfig \

  scp ${host}.kubeconfig \
    root@${host}:/var/lib/kubelet/kubeconfig
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
- Verify kubernetes controlplane components is running
```
kubectl cluster-info --kubeconfig admin.kubeconfig
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