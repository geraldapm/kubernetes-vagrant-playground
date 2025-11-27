def default_s(key, default)
  ENV[key] && ! ENV[key].empty? ? ENV[key] : default
end

def default_i(key, default)
  default_s(key, default).to_i
end

def default_b(key, default)
  default_s(key, default).to_s.downcase == "true"
end

Vagrant.configure("2") do |config|
  VAGRANT_BASEIMG = default_s('VAGRANT_BASEIMG', 'cloud-image/ubuntu-24.04')

  KUBERNETES_VERSION = default_s('KUBERNETES_VERSION', '1.32')
  SUBNET = default_s('SUBNET', '192.168.56')
  VIP_ADDRESS = default_s('VIP_ADDRESS', '192.168.56.199')
  
  # Control Plane and Worker Node Hostnames
  HOSTNAME_FQDNSUFFIX = default_s('HOSTNAME_FQDNSUFFIX', 'vagrant.gpm.my.id')
  CONTROL_PLANE_HOSTNAME_PREFIX = default_s('CONTROL_PLANE_HOSTNAME_PREFIX', 'gpmrawk8s-controlplane')
  WORKER_HOSTNAME_PREFIX = default_s('WORKER_HOSTNAME_PREFIX', 'gpmrawk8s-worker')

  # Control Plane and Worker Node counts
  CONTROL_PLANE_COUNT = default_i('CONTROL_PLANE_COUNT', 3)
  WORKER_COUNT = default_i('WORKER_COUNT', 2)

  # Control Plane and Worker Node Start IPs
  CONTROL_PLANE_START_IP = default_i('CONTROL_PLANE_START_IP', 150)
  WORKER_START_IP = default_i('WORKER_START_IP', 160)

  # vCPUS and Memory for the VMs
  CONTROL_PLANE_CPUS = default_i('CONTROL_PLANE_CPUS', 2)
  CONTROL_PLANE_MEMORY = default_i('CONTROL_PLANE_MEMORY', 2048)
  WORKER_CPUS = default_i('WORKER_CPUS', 2)
  WORKER_MEMORY = default_i('WORKER_MEMORY', 4096)
  VB_GROUP = default_s('VB_GROUP', 'rawk8s')

  # Additional Kubernetes Cluster Settings
  POD_CIDR = default_s('POD_CIDR', '10.244.0.0/16')
  SERVICE_CIDR = default_s('SERVICE_CIDR', '10.96.0.0/12')
  SERVICE_NODE_PORT_RANGE = default_s('SERVICE_NODE_PORT_RANGE', '8000-32767')

  config.vm.box = "#{VAGRANT_BASEIMG}"

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = false
    vb.customize ["modifyvm", :id, "--groups", "/" + VB_GROUP]
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  # Include ssh key
  config.vm.provision "shell", privileged: true do |s|
    ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip
    s.inline = <<-SHELL
      useradd -m -s /bin/bash -U gerald -u 666
      cp -pr /home/vagrant/.ssh /home/gerald/
      chown -R gerald:gerald /home/gerald
      echo "%gerald ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/gerald
      echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
      echo #{ssh_pub_key} >> /home/gerald/.ssh/authorized_keys
      echo #{ssh_pub_key} >> /root/.ssh/authorized_keys
      echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
      sed -i \
        's/^#*PermitRootLogin.*/PermitRootLogin yes/' \
        /etc/ssh/sshd_config
      systemctl restart ssh
    SHELL
  end

  # Add all nodes to each other's /etc/hosts
  config.vm.provision "shell",
    env: { "SUBNET" => SUBNET, 
      "CONTROL_PLANE_START_IP" => CONTROL_PLANE_START_IP,
      "WORKER_START_IP" => WORKER_START_IP,
      "CONTROL_PLANE_COUNT" => CONTROL_PLANE_COUNT,
      "WORKER_COUNT" => WORKER_COUNT,
      "CONTROL_PLANE_HOSTNAME_PREFIX" => CONTROL_PLANE_HOSTNAME_PREFIX,
      "WORKER_HOSTNAME_PREFIX" => WORKER_HOSTNAME_PREFIX,
      "HOSTNAME_FQDNSUFFIX" => HOSTNAME_FQDNSUFFIX
    },
    privileged: true,
    inline: <<-SHELL
      for i in `seq 1 ${CONTROL_PLANE_COUNT}`; do
        echo "$SUBNET.$((CONTROL_PLANE_START_IP+i)) $CONTROL_PLANE_HOSTNAME_PREFIX${i} $CONTROL_PLANE_HOSTNAME_PREFIX${i}.$HOSTNAME_FQDNSUFFIX" >> /etc/hosts
      done
      for i in `seq 1 ${WORKER_COUNT}`; do
        echo "$SUBNET.$((WORKER_START_IP+i)) $WORKER_HOSTNAME_PREFIX${i} $WORKER_HOSTNAME_PREFIX${i}.$HOSTNAME_FQDNSUFFIX" >> /etc/hosts
      done
    SHELL

# Define First master node
  config.vm.define "#{CONTROL_PLANE_HOSTNAME_PREFIX}1" do |controlplane|
    controlplane.vm.hostname = "#{CONTROL_PLANE_HOSTNAME_PREFIX}1.#{HOSTNAME_FQDNSUFFIX}"
    ip = CONTROL_PLANE_START_IP + 1
    ip_addr = "#{SUBNET}.#{ip}"
    controlplane.vm.network :private_network, nic_type: "virtio", ip: ip_addr
    controlplane.vm.provider :virtualbox do |vb|
        vb.name = "#{CONTROL_PLANE_HOSTNAME_PREFIX}1"
        vb.memory = CONTROL_PLANE_MEMORY
        vb.cpus = CONTROL_PLANE_CPUS
      end
    controlplane.vm.provision "shell", privileged: true, path: "scripts/common.sh", 
      env: { "KUBERNETES_VERSION" => "#{KUBERNETES_VERSION}",
        "SUBNET" => "#{SUBNET}"
      }
    controlplane.vm.provision "shell", privileged: true, path: "scripts/keepalived.sh", 
      env: { "VIP_ADDRESS" => "#{VIP_ADDRESS}",
        "SUBNET" => "#{SUBNET}"
     }
  end

# Define Remaining master node (3 nodes for high availability) Starting from 2nd control plane
  (2..CONTROL_PLANE_COUNT).each do |i|
    config.vm.define "#{CONTROL_PLANE_HOSTNAME_PREFIX}#{i}" do |controlplane|
      controlplane.vm.hostname = "#{CONTROL_PLANE_HOSTNAME_PREFIX}#{i}.#{HOSTNAME_FQDNSUFFIX}"
      ip = CONTROL_PLANE_START_IP + i
      ip_addr = "#{SUBNET}.#{ip}"
      controlplane.vm.network :private_network, nic_type: "virtio", ip: ip_addr
      
      controlplane.vm.provider :virtualbox do |vb|
        vb.name = "#{CONTROL_PLANE_HOSTNAME_PREFIX}#{i}"
        vb.memory = CONTROL_PLANE_MEMORY
        vb.cpus = CONTROL_PLANE_CPUS
      end

      controlplane.vm.provision "shell", privileged: true, path: "scripts/common.sh", 
        env: { "KUBERNETES_VERSION" => "#{KUBERNETES_VERSION}",
          "SUBNET" => "#{SUBNET}"
        }
      controlplane.vm.provision "shell", privileged: true, path: "scripts/keepalived.sh", 
        env: { "VIP_ADDRESS" => "#{VIP_ADDRESS}",
          "SUBNET" => "#{SUBNET}"
        }
    end
  end

 # Define your worker nodes (add more if needed)
  (1..WORKER_COUNT).each do |i|
    config.vm.define "#{WORKER_HOSTNAME_PREFIX}#{i}" do |worker|
      worker.vm.hostname = "#{WORKER_HOSTNAME_PREFIX}#{i}.#{HOSTNAME_FQDNSUFFIX}"
      ip = WORKER_START_IP + i
      ip_addr = "#{SUBNET}.#{ip}"
      worker.vm.network :private_network, nic_type: "virtio", ip: ip_addr
      
      worker.vm.provider :virtualbox do |vb|
        vb.name = "#{WORKER_HOSTNAME_PREFIX}#{i}"
        vb.memory = WORKER_MEMORY
        vb.cpus = WORKER_CPUS
      end
      worker.vm.provision "shell", privileged: true, path: "scripts/common.sh", 
        env: { "KUBERNETES_VERSION" => "#{KUBERNETES_VERSION}",
          "SUBNET" => "#{SUBNET}"
        }
    end
  end
end