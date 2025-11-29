#!/bin/bash
#
# Please change Below variables accordingly. Any additional workers can be added 

set -euxo pipefail

HOSTNAME_CP1="gpmrawk8s-controlplane1"
HOSTNAME_CP2="gpmrawk8s-controlplane2"
HOSTNAME_CP3="gpmrawk8s-controlplane3"
IP_CP1=192.168.56.151
IP_CP2=192.168.56.152
IP_CP3=192.168.56.153

HOSTNAME_WK1=gpmrawk8s-worker1
HOSTNAME_WK2=gpmrawk8s-worker2
IP_WK1=192.168.56.161
IP_WK2=192.168.56.162

FLOATINGIP=192.168.56.199

export HOSTNAME_CP1=$HOSTNAME_CP1
export HOSTNAME_CP2=$HOSTNAME_CP2
export HOSTNAME_CP3=$HOSTNAME_CP3
export IP_CP1=$IP_CP1
export IP_CP2=$IP_CP2
export IP_CP3=$IP_CP3
export FLOATINGIP=$FLOATINGIP

### Begin Generating all kubernetes node individual certs
# controlplane1 
export NODENAME=$HOSTNAME_CP1
export NODEIP=$IP_CP1 
openssl genrsa -out "$NODENAME.key" 4096
openssl req -new -key "$NODENAME.key" -sha256 \
    -config "ca.conf" -section allnode \
    -out "$NODENAME.csr"
openssl x509 -req -days 3653 -in "$NODENAME.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "$NODENAME.crt"

# controlplane2
export NODENAME=$HOSTNAME_CP2
export NODEIP=$IP_CP2
openssl genrsa -out "$NODENAME.key" 4096
openssl req -new -key "$NODENAME.key" -sha256 \
    -config "ca.conf" -section allnode \
    -out "$NODENAME.csr"
openssl x509 -req -days 3653 -in "$NODENAME.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "$NODENAME.crt"

# controlplane3
export NODENAME=$HOSTNAME_CP3
export NODEIP=$IP_CP3
openssl genrsa -out "$NODENAME.key" 4096
openssl req -new -key "$NODENAME.key" -sha256 \
    -config "ca.conf" -section allnode \
    -out "$NODENAME.csr"
openssl x509 -req -days 3653 -in "$NODENAME.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "$NODENAME.crt"

# worker1
export NODENAME=$HOSTNAME_WK1
export NODEIP=$IP_WK1
openssl genrsa -out "$NODENAME.key" 4096
openssl req -new -key "$NODENAME.key" -sha256 \
    -config "ca.conf" -section allnode \
    -out "$NODENAME.csr"
openssl x509 -req -days 3653 -in "$NODENAME.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "$NODENAME.crt"

# worker2
export NODENAME=$HOSTNAME_WK2
export NODEIP=$IP_WK2
openssl genrsa -out "$NODENAME.key" 4096
openssl req -new -key "$NODENAME.key" -sha256 \
    -config "ca.conf" -section allnode \
    -out "$NODENAME.csr"
openssl x509 -req -days 3653 -in "$NODENAME.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "$NODENAME.crt"

unset NODENAME
unset NODEIP
### END Generating all kubernetes node individual certs

### Begin Kubernetes Components Cert Generation
kubecerts=(
  "admin"
  "kube-proxy"
  "kube-scheduler"
  "kube-controller-manager"
  "kube-apiserver"
  "service-accounts"
  "kube-etcd"
  "kube-apiserver-kubelet-client"
  "kube-apiserver-etcd-client"
  "front-proxy-client"
)

for i in ${kubecerts[*]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
  openssl x509 -noout -text -in "${i}.crt" | grep -A1 -iE "Subject:|Subject Alternative Name"
done

unset HOSTNAME_CP1
unset HOSTNAME_CP2
unset HOSTNAME_CP3
unset IP_CP1
unset IP_CP2
unset IP_CP3
unset FLOATINGIP

### END Kubernetes Components Cert Generation
