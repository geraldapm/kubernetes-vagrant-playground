#!/bin/bash
# Setup Keepalived for High Availability on Control Plane Nodes and listen for 6443 port. Find a way to get the primary network interface dynamically.
set -euxo pipefail

sudo apt-get update
sudo apt-get install -y keepalived

cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state MASTER
    interface $(ip route | grep $SUBNET | awk '{print $3'} | head -n 1) 

    virtual_router_id 51
    priority 101
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass keepalivedpassword
    }
    virtual_ipaddress {
        $VIP_ADDRESS
    }
    track_script {
        chk_kube_apiserver
    }
}  
vrrp_script chk_kube_apiserver {
    script "curl -s --insecure https://localhost:6443/healthz || exit 1"
    interval 2
    weight -20
}
EOF

sudo systemctl enable keepalived
sudo systemctl start keepalived
echo "Keepalived setup completed on Control Plane Node"
