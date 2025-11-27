# Tutorial to provision k8s cluster from scratch using Vagrant.

This repository contains a step-by-step tutorial to provision a Kubernetes cluster from scratch using Vagrant and VirtualBox. The tutorial is designed for educational purposes and aims to help users understand the inner workings of Kubernetes by building a cluster manually. 

Reference: https://github.com/kelseyhightower/kubernetes-the-hard-way

*NOTE: Requires linux system to follow this tutorial :)*

## Provision VM using vagrant
- Included scripts to initial provision VM and setup crio as CRI manually
- Included scripts to install keepalived as floating IP to adapt multi-node control-plane nodes

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