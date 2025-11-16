# Kubernetes Vagrant Playground

A small collection of Vagrant configurations to provision disposable Ubuntu VMs for experimenting with different Kubernetes deployments.

Includes:
- Generic Kubernetes (kubeadm) on Ubuntu
- k3s on Ubuntu

Prerequisites:
- Vagrant
- Shared folder support (e.g., VirtualBox Guest Additions) or NFS or SMB.

Note: These setups are intended for learning, testing, and rapid prototyping. They are not production-ready configurations.

SMB Configuration example (if needed) -> edit on ~/.vagrant.d/Vagrantfile:
```vagrant
DEFAULT_SMB_USERNAME="pc-hostname\\username"
DEFAULT_SMB_PASSWORD="password"

Vagrant.configure("2") do |config|
    # setting this synced folder is not required, btw. The variables above 
    # will be accessible anywhere as long as it gets loaded by Vagrant
    config.vm.synced_folder ".", "/vagrant", smb_username: DEFAULT_SMB_USERNAME,
        smb_password: DEFAULT_SMB_PASSWORD
end
```

Quick start:
1. Open the example directory: examples/<k8s|k3s>
2. Edit the Vagrantfile as needed (e.g., adjust VM count, resources, networking)
3. Run: `vagrant up` (requires Vagrant and a provider like VirtualBox)

Purpose: learning, testing and rapid prototyping of cluster setups. Adjust provisioning and networking per-example as needed.# Create a brief summary that this project is a playground vagrant files for various kubernetes deployments.