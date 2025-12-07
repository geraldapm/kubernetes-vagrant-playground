#!/bin/bash

#!/bin/bash
#
# Please change Below variables accordingly

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


# controlplane1 
export NODENAME=$HOSTNAME_CP1
export NODEIP=$IP_CP1 
cat <<EOF | sudo tee etcd-$NODENAME.service
[Unit]
Description=etcd-server
Documentation=https://github.com/coreos

[Service]
Type=notify
User=etcd
Group=etcd
ExecStart=/usr/local/bin/etcd \\
  --name ${NODENAME} \\
  --cert-file=/etc/kubernetes/pki/etcd/kube-etcd.crt \\
  --key-file=/etc/kubernetes/pki/etcd/kube-etcd.key \\
  --peer-cert-file=/etc/kubernetes/pki/etcd/kube-etcd-peer.crt \\
  --peer-key-file=/etc/kubernetes/pki/etcd/kube-etcd-peer.key \\
  --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${NODEIP}:2380 \\
  --listen-peer-urls https://${NODEIP}:2380 \\
  --listen-client-urls https://${NODEIP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${NODEIP}:2379 \\
  --initial-cluster-token gpmrawk8s-etcd-token \\
  --initial-cluster ${HOSTNAME_CP1}=https://${IP_CP1}:2380,${HOSTNAME_CP2}=https://${IP_CP2}:2380,${HOSTNAME_CP3}=https://${IP_CP3}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# controlplane2
export NODENAME=$HOSTNAME_CP2
export NODEIP=$IP_CP2
cat <<EOF | sudo tee etcd-$NODENAME.service
[Unit]
Description=etcd-server
Documentation=https://github.com/coreos

[Service]
Type=notify
User=etcd
Group=etcd
ExecStart=/usr/local/bin/etcd \\
  --name ${NODENAME} \\
  --cert-file=/etc/kubernetes/pki/etcd/kube-etcd.crt \\
  --key-file=/etc/kubernetes/pki/etcd/kube-etcd.key \\
  --peer-cert-file=/etc/kubernetes/pki/etcd/kube-etcd-peer.crt \\
  --peer-key-file=/etc/kubernetes/pki/etcd/kube-etcd-peer.key \\
  --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${NODEIP}:2380 \\
  --listen-peer-urls https://${NODEIP}:2380 \\
  --listen-client-urls https://${NODEIP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${NODEIP}:2379 \\
  --initial-cluster-token gpmrawk8s-etcd-token \\
  --initial-cluster ${HOSTNAME_CP1}=https://${IP_CP1}:2380,${HOSTNAME_CP2}=https://${IP_CP2}:2380,${HOSTNAME_CP3}=https://${IP_CP3}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# controlplane3
export NODENAME=$HOSTNAME_CP3
export NODEIP=$IP_CP3
cat <<EOF | sudo tee etcd-$NODENAME.service
[Unit]
Description=etcd-server
Documentation=https://github.com/coreos

[Service]
Type=notify
User=etcd
Group=etcd
ExecStart=/usr/local/bin/etcd \\
  --name ${NODENAME} \\
  --cert-file=/etc/kubernetes/pki/etcd/kube-etcd.crt \\
  --key-file=/etc/kubernetes/pki/etcd/kube-etcd.key \\
  --peer-cert-file=/etc/kubernetes/pki/etcd/kube-etcd-peer.crt \\
  --peer-key-file=/etc/kubernetes/pki/etcd/kube-etcd-peer.key \\
  --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${NODEIP}:2380 \\
  --listen-peer-urls https://${NODEIP}:2380 \\
  --listen-client-urls https://${NODEIP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${NODEIP}:2379 \\
  --initial-cluster-token gpmrawk8s-etcd-token \\
  --initial-cluster ${HOSTNAME_CP1}=https://${IP_CP1}:2380,${HOSTNAME_CP2}=https://${IP_CP2}:2380,${HOSTNAME_CP3}=https://${IP_CP3}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


unset NODENAME
unset NODEIP

unset HOSTNAME_CP1
unset HOSTNAME_CP2
unset HOSTNAME_CP3
unset IP_CP1
unset IP_CP2
unset IP_CP3
unset FLOATINGIP