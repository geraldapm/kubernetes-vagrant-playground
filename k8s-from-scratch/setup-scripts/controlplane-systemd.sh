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

export SERVICE_CIDR="10.96.0.0/12"
export POD_CIDR="10.244.0.0/16"

### controlplane1 
export NODENAME=$HOSTNAME_CP1
export NODEIP=$IP_CP1 

# kube-scheduler-yaml-generate
cat <<EOF | sudo tee kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/etc/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

# kube-apiserver
cat <<EOF | sudo tee kube-apiserver-$NODENAME.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${NODEIP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt \\
  --etcd-certfile=/etc/kubernetes/pki/etcd/kube-etcd.crt \\
  --etcd-keyfile=/etc/kubernetes/pki/etcd/kube-etcd.key \\
  --etcd-servers=https://${IP_CP1}:2379,https://${IP_CP2}:2379,https://${IP_CP3}:2379 \\
  --event-ttl=1h \\
  --max-requests-inflight=1200 \\
  --max-mutating-requests-inflight=600 \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/etc/kubernetes/pki/etcd/ca.crt \\
  --kubelet-client-certificate=/etc/kubernetes/pki/kube-apiserver.crt \\
  --kubelet-client-key=/etc/kubernetes/pki/kube-apiserver.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=/etc/kubernetes/pki/service-accounts.crt \\
  --service-account-signing-key-file=/etc/kubernetes/pki/service-accounts.key \\
  --service-account-issuer=https://${FLOATINGIP}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/etc/kubernetes/pki/kube-apiserver.crt \\
  --tls-private-key-file=/etc/kubernetes/pki/kube-apiserver.key \\
  --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt \\
  --proxy-client-key-file /etc/kubernetes/pki/front-proxy-client.key \\
  --requestheader-client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# kube-controller-manager
cat <<EOF | sudo tee kube-controller-manager-$NODENAME.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt \\
  --cluster-signing-key-file=/etc/kubernetes/pki/ca.key \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/etc/kubernetes/pki/ca.crt \\
  --service-account-private-key-file=/etc/kubernetes/pki/service-accounts.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# kube-scheduler
cat <<EOF | sudo tee kube-scheduler-$NODENAME.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF




### controlplane2
export NODENAME=$HOSTNAME_CP2
export NODEIP=$IP_CP2

# kube-apiserver
cat <<EOF | sudo tee kube-apiserver-$NODENAME.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${NODEIP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt \\
  --etcd-certfile=/etc/kubernetes/pki/kube-apiserver-etcd-client.crt \\
  --etcd-keyfile=/etc/kubernetes/pki/kube-apiserver-etcd-client.key \\
  --etcd-servers=https://${IP_CP1}:2379,https://${IP_CP2}:2379,https://${IP_CP3}:2379 \\
  --event-ttl=1h \\
  --max-requests-inflight=1200 \\
  --max-mutating-requests-inflight=600 \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/etc/kubernetes/pki/etcd/ca.crt \\
  --kubelet-client-certificate=/etc/kubernetes/pki/kube-apiserver-kubelet-client.crt \\
  --kubelet-client-key=/etc/kubernetes/pki/kube-apiserver-kubelet-client.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=/etc/kubernetes/pki/service-accounts.crt \\
  --service-account-signing-key-file=/etc/kubernetes/pki/service-accounts.key \\
  --service-account-issuer=https://${FLOATINGIP}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/etc/kubernetes/pki/kube-apiserver.crt \\
  --tls-private-key-file=/etc/kubernetes/pki/kube-apiserver.key \\
  --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt \\
  --proxy-client-key-file /etc/kubernetes/pki/front-proxy-client.key \\
  --requestheader-client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# kube-controller-manager
cat <<EOF | sudo tee kube-controller-manager-$NODENAME.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt \\
  --cluster-signing-key-file=/etc/kubernetes/pki/ca.key \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/etc/kubernetes/pki/ca.crt \\
  --service-account-private-key-file=/etc/kubernetes/pki/service-accounts.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# kube-scheduler
cat <<EOF | sudo tee kube-scheduler-$NODENAME.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF




### controlplane3
export NODENAME=$HOSTNAME_CP3
export NODEIP=$IP_CP3

# kube-apiserver
cat <<EOF | sudo tee kube-apiserver-$NODENAME.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${NODEIP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt \\
  --etcd-certfile=/etc/kubernetes/pki/etcd/kube-etcd.crt \\
  --etcd-keyfile=/etc/kubernetes/pki/etcd/kube-etcd.key \\
  --etcd-servers=https://${IP_CP1}:2379,https://${IP_CP2}:2379,https://${IP_CP3}:2379 \\
  --event-ttl=1h \\
  --max-requests-inflight=1200 \\
  --max-mutating-requests-inflight=600 \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/etc/kubernetes/pki/etcd/ca.crt \\
  --kubelet-client-certificate=/etc/kubernetes/pki/kube-apiserver.crt \\
  --kubelet-client-key=/etc/kubernetes/pki/kube-apiserver.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=/etc/kubernetes/pki/service-accounts.crt \\
  --service-account-signing-key-file=/etc/kubernetes/pki/service-accounts.key \\
  --service-account-issuer=https://${FLOATINGIP}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/etc/kubernetes/pki/kube-apiserver.crt \\
  --tls-private-key-file=/etc/kubernetes/pki/kube-apiserver.key \\
  --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt \\
  --proxy-client-key-file /etc/kubernetes/pki/front-proxy-client.key \\
  --requestheader-client-ca-file=/etc/kubernetes/pki/ca.crt \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# kube-controller-manager
cat <<EOF | sudo tee kube-controller-manager-$NODENAME.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt \\
  --cluster-signing-key-file=/etc/kubernetes/pki/ca.key \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/etc/kubernetes/pki/ca.crt \\
  --service-account-private-key-file=/etc/kubernetes/pki/service-accounts.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# kube-scheduler
cat <<EOF | sudo tee kube-scheduler-$NODENAME.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/kube-scheduler.yaml \\
  --v=2
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
unset SERVICE_CIDR
unset POD_CIDR