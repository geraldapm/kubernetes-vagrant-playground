# Tutorial to provision k8s cluster from scratch using Vagrant.

This repository contains a step-by-step tutorial to provision a Kubernetes cluster from scratch using Vagrant and VirtualBox. The tutorial is designed for educational purposes and aims to help users understand the inner workings of Kubernetes by building a cluster manually.

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
- Generate All Kubernetes & ETCD Certificate. For convenience, we are using scripts to expand the variables and generating those certs. Please Change the Environment Variable with corresponding Hostname and IP. The scripts are in [../setup-scripts/gencert.sh](../setup-scripts/gencert.sh).

```
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