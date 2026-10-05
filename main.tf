locals {
  # Connect to proxmox host
  proxmox_host              = "192.168.31.2"
  proxmox_port              = 8006
  proxmox_node_name         = "pve"

  proxmox_ssh_key           = "/home/myuser/.ssh/sshkey"
  proxmox_user              = "root"
  proxmox_realm             = "pam"
  proxmox_api_token_id      = "proxmox_token_id" # Token ID after "<user>@<realm>!"
  proxmox_api_token_secret  = "xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Token secret

  # LXC container configs
  lxc_count                 = 3       # set how many lxc container to create
  lxc_base_id               = 2000    # set Proxmox CT ID
  lxc_cpu_arch              = "amd64"
  lxc_cpu_core              = 2       # set lxc container cpu core
  lxc_disk_size             = 8       # set lxc container disk size in GB
  lxc_mem_dedicated         = 2048    # set lxc container mem size in MB
  lxc_mem_swap              = 0       # set lxc container swap size in MB
  lxc_protection            = false   # prevent the container itself and its disk for remove/update operations

  lxc_unprivileged          = true
  lxc_nesting               = true

  lxc_os_template           = "alpine-3.24-default_20260714_amd64.tar.xz" # img should exist in local storage - check with "pvesm list local --content vztmpl | grep alpine"
  lxc_os_type               = "alpine" # alpine, archlinux, centos, debian, devuan, fedora, gentoo, nixos, opensuse, ubuntu, unmanaged #REQUIRED - if not set, network & hostname will facing issue

  # lxc_os_template           = "debian-13-standard_13.6-1_amd64.tar.zst"  
  # lxc_os_type               = "debian"

  # lxc_os_template           = "ubuntu-26.04-standard_26.04-1_amd64.tar.zst"  
  # lxc_os_type               = "ubuntu"

  # lxc_os_template           = "rockylinux-10-default_20251001_amd64.tar.xz"  
  # lxc_os_type               = "centos"

  # lxc_os_template           = "almalinux-10-default_20250930_amd64.tar.xz"  
  # lxc_os_type               = "centos"
  

  lxc_network_iface         = "eth0"
  lxc_network_bridge        = "vmbr0"
  lxc_network_firewall      = true
  lxc_root_password         = "password123" #set root password for container
  lxc_root_public_key       = "/home/myuser/.ssh/sshkey.pub" # PUBLIC KEY. I am using same key as key to connect to proxmox host. You need the private key to connect to container 
  lxc_hostname              = "k3s-master" # will become k3s-master-01, k3s-master-02, k3s-master-03 ...

  # this will make first lxc container become 192.168.31.50...192.168.31.[50 +  lxc_count.index]
  # Kubevip Virtual IP will be the last one. first control-plane IP + lxc_count. 
  # Index started at 0 so 3 lxc containers control-planes (192.168.31.[50+0]), (192.168.31.[50+1]), (192.168.31.[50+2]). Kubevip (192.168.31.[50+3])
  lxc_net_prefix            = "192.168.31"
  lxc_host_address          = 50
  lxc_cidr                  = 24
  lxc_gateway               = "192.168.31.1"


  lxc_k3s_token             = "SECRET123"
  lxc_kubevip_version       = "v1.2.4" # https://github.com/kube-vip/kube-vip/releases
  lxc_kubevip_ip_start      = 90
  lxc_kubevip_ip_end        = 100

  proxmox_url               = "https://${local.proxmox_host}:${local.proxmox_port}"
  proxmox_api_token         = "${local.proxmox_user}@${local.proxmox_realm}!${local.proxmox_api_token_id}=${local.proxmox_api_token_secret}"  
  proxmox_ssh               = "ssh -i ${local.proxmox_ssh_key} -o StrictHostKeyChecking=no ${local.proxmox_user}@${local.proxmox_host}"
  
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.114.0" # Use your appropriate provider version
    }
  }
}

provider "proxmox" {

  endpoint  = local.proxmox_url
  api_token = local.proxmox_api_token
  insecure  = true

  # Required for snippet/script uploads to proxmox host
  ssh {
    username = local.proxmox_user
    agent       = false
    private_key = file(local.proxmox_ssh_key)
  }
}


resource "proxmox_virtual_environment_container" "lxc_provisioning" {
  count       = local.lxc_count
  description = "<div align='center'><img src='https://avatars.githubusercontent.com/u/761456?s=120&v=4' alt='Logo' style='width:81px;height:112px;'/><h2>Managed by Terraform</h2> <a href='https://github.com/tobing/kubernetes-iac-proxmox'><img src='https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white' alt='GitHub'></a></div>"
  node_name   = local.proxmox_node_name
  vm_id       = local.lxc_base_id + count.index
  protection  = local.lxc_protection

  # newer linux distributions require unprivileged user namespaces
  unprivileged = local.lxc_unprivileged
  features {
    nesting = local.lxc_nesting
  }

  initialization {
    hostname = "${local.lxc_hostname}-${ format("%02d", count.index + 1) }"
    ip_config {
      ipv4 {
        # Dynamically increment the final octet: 192.168.1.50, 192.168.1.51
        # address = "${local.lxc_net_prefix}.${50 + count.index}/24"
        address = "${local.lxc_net_prefix}.${local.lxc_host_address + count.index}/${local.lxc_cidr}"
        gateway = "${local.lxc_gateway}"
      }
    }
    user_account {
      password = "${local.lxc_root_password}"
      keys = [trimspace(file(local.lxc_root_public_key))]
    }
  }

  cpu {
    cores = local.lxc_cpu_core
    architecture = local.lxc_cpu_arch
  } 

  memory {
    dedicated = local.lxc_mem_dedicated
    swap      = local.lxc_mem_swap
  }

  operating_system {
    template_file_id = "local:vztmpl/${local.lxc_os_template}"
    type             = local.lxc_os_type
  }

  disk {
    datastore_id = "local-lvm"
    size         = local.lxc_disk_size
  }

  network_interface {
    name      = local.lxc_network_iface
    bridge    = local.lxc_network_bridge
    firewall  = local.lxc_network_firewall
  }
}

# Upload the script as a snippet to Proxmox host
resource "proxmox_virtual_environment_file" "upload_script" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.proxmox_node_name
  source_raw {
    data      = file("${path.module}/update_package_containers.sh")
    file_name = "update_package_containers.sh"
  }

}


# Deploy lxc containers
resource "terraform_data" "lxc_containers" {
  count      = local.lxc_count
  depends_on = [proxmox_virtual_environment_container.lxc_provisioning]

  provisioner "local-exec" {
    command = <<-EOT


    # Requirements setup in Proxmox host    
    ${local.proxmox_ssh} "cat >> /etc/pve/lxc/${local.lxc_base_id + count.index}.conf <<'EOF'
lxc.apparmor.profile: unconfined
lxc.mount.auto: proc:rw sys:rw
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,create=file
EOF"


    # Run packages update for each container
    printf "\033[92m"'Update packages & install curl iptables for ${proxmox_virtual_environment_container.lxc_provisioning[count.index].initialization[0].hostname}'"\033[0m"
    ${local.proxmox_ssh} "pct exec ${local.lxc_base_id + count.index} -- /bin/sh < /var/lib/vz/snippets/update_package_containers.sh"

    
    # Set up k3s after reboot
    sleep 10
    if [ ${local.lxc_base_id} -eq ${local.lxc_base_id + count.index} ]; then

      # Prepare kube-vip RBAC manifest
      ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- /bin/sh -c '
        set -e

        mkdir -p /var/lib/rancher/k3s/server/manifests/

        if ! curl -fsSL --retry 2 --retry-delay 3 https://kube-vip.io/manifests/rbac.yaml \
            -o /var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml; then
          printf \"\033[31mFailed to download kube-vip RBAC manifest\033[0m\n\"
          exit 1
        fi
      '"

      # Set up the first container for cluster-init
      printf "\033[92m"'Setup K3s for cluster-init ${proxmox_virtual_environment_container.lxc_provisioning[count.index].initialization[0].hostname}'"\033[0m"
      ${local.proxmox_ssh} "pct exec ${local.lxc_base_id + count.index} -- /bin/sh -c ' curl -sfL https://get.k3s.io | K3S_TOKEN=${local.lxc_k3s_token} sh -s - server \
      --write-kubeconfig-mode=644 \
      --disable=servicelb \
      --cluster-init \
      --tls-san=${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count} '"

    else
      # Join other control plane
      until ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- curl -ksS https://127.0.0.1:6443/version" >/dev/null 2>&1; do
          sleep 15
          printf "\033[92m"'Waiting cluster-init ready for K3s setup on ${proxmox_virtual_environment_container.lxc_provisioning[count.index].initialization[0].hostname}'"\033[0m"
      done

      ${local.proxmox_ssh} "pct exec ${local.lxc_base_id + count.index} -- /bin/sh -c ' curl -sfL https://get.k3s.io | K3S_TOKEN=${local.lxc_k3s_token} sh -s - server \
      --write-kubeconfig-mode=644 \
      --disable=servicelb \
      --server https://${local.lxc_net_prefix}.${local.lxc_host_address}:6443 \
      --tls-san=${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}   '"
    fi


    # Set up kube-vip daemon set 
    ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- /bin/sh -c 'cat > /etc/rancher/k3s/kubevipdaemonset.yaml'" <<'YAML'
${templatefile("${path.module}/kubevip-daemonset.yaml", {
  kubevip_version = local.lxc_kubevip_version
  network_iface   = local.lxc_network_iface
  vip_address     = "${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}"
})}
YAML


    until ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- curl -ksS https://127.0.0.1:6443/version" >/dev/null 2>&1; do
        sleep 15
        printf "\033[92m"'Waiting cluster-init ${proxmox_virtual_environment_container.lxc_provisioning[0].initialization[0].hostname} ready for kube-vip setup'"\033[0m"
    done

    # Apply kube-vip daemon set from one node
    if [ ${local.lxc_base_id + count.index} -eq ${local.lxc_base_id} ]; then
      printf "\033[92m"'Prepare kube-vip daemon set'"\033[0m"      
      ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- /bin/sh -c '
        if ! /usr/local/bin/kubectl apply -f /etc/rancher/k3s/kubevipdaemonset.yaml; then
          printf \"\033[31mFailed to apply kube-vip daemon set\033[0m\n\"
          exit 1
        fi
      '"

      printf "\033[92m"'Prepare kube-vip cloud controller'"\033[0m"
      ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- /bin/sh -c '
        if ! curl -fsSL --retry 2 --retry-delay 3 https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml \
            -o /tmp/kube-vip-cloud-controller.yaml; then
          printf \"\033[31mFailed to download kube-vip-cloud-controller manifest\033[0m\n\"
          exit 1
        fi

        if ! /usr/local/bin/kubectl apply -f /tmp/kube-vip-cloud-controller.yaml; then
          printf \"\033[31mFailed to apply kube-vip-cloud-controller manifest\033[0m\n\"
          exit 1
        fi
      '"

      printf "\033[92m"'Prepare kube-vip IP pool ${local.lxc_net_prefix}.${local.lxc_kubevip_ip_start}-${local.lxc_net_prefix}.${local.lxc_kubevip_ip_end}'"\033[0m"
      ${local.proxmox_ssh} "pct exec ${local.lxc_base_id} -- /bin/sh -c '
        if ! /usr/local/bin/kubectl create configmap -n kube-system kubevip --from-literal range-global=${local.lxc_net_prefix}.${local.lxc_kubevip_ip_start}-${local.lxc_net_prefix}.${local.lxc_kubevip_ip_end}; then
          printf \"\033[31mFailed to apply kube-vip configmap range-global=${local.lxc_net_prefix}.${local.lxc_kubevip_ip_start}-${local.lxc_net_prefix}.${local.lxc_kubevip_ip_end}\033[0m\n\"
          exit 1
        fi
      '"

      sleep 60
      printf "\033[92m"'Waiting pods and services ready'"\033[0m"
      sleep 30
      
      printf "\033[92m"'==================== CHECKLIST & VERIFICATION ===================='"\033[0m\n\n\n"
      printf "\033[92m"'Wait for 1-2 minutes then from one node check with this command. It should show 3 nodes'"\033[0m"
      printf "\033[92m"' and service/traefik EXTERNAL-IP coming from lxc_kubevip_ip_start - lxc_kubevip_ip_end '"\033[0m\n"
      printf "\033[92m"'kubectl --server=https://${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}:6443 get nodes,svc -A'"\033[0m\n\n\n"

      printf "\033[92m"'Run this command to test Virtual IP (VIP) & HA, ignore error 401. Power off the node one by one from node 1. '"\033[0m\n"
      printf "\033[92m"'while true; do curl -k --fail --max-time 0.3 https://${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}:6443; sleep 1s; done'"\033[0m\n\n\n"
      
      printf "\033[92m"'Try to deploy nginx with this command.'"\033[0m\n"
      printf "\033[92m"'kubectl create deployment nginx-deployment --image=nginx:stable-alpine-slim && kubectl expose deployment nginx-deployment --port=80 --type=LoadBalancer --name=nginx'"\033[0m\n\n"

      printf "\033[92m"'Check service/nginx EXTERNAL-IP with this command, then open with your browser http://EXTERNAL-IP '"\033[0m\n"
      printf "\033[92m"'kubectl --server=https://${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}:6443 get svc -A'"\033[0m\n\n\n"
      printf "\033[92m"'==================== CHECKLIST & VERIFICATION ===================='"\033[0m\n\n\n"     


      printf "\033[31m"'==================== JOINING NEW NODE ===================='"\033[0m\n"
      printf "\033[31m"'To join other control plane (master node) to the cluster, use this command. Make sure curl and iptables installed '"\033[0m\n"
      printf "\033[31m"'curl -sfL https://get.k3s.io | K3S_TOKEN=${local.lxc_k3s_token} sh -s - server --disable=servicelb --write-kubeconfig-mode=644 --server https://${local.lxc_net_prefix}.${local.lxc_host_address}:6443 --tls-san=${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count} '"\033[0m\n\n\n"

      printf "\033[31m"'To join a worker node to the cluster, use this command. Make sure curl and iptables installed '"\033[0m\n"
      printf "\033[31m"'curl -sfL https://get.k3s.io | K3S_TOKEN=${local.lxc_k3s_token} K3S_URL=https://${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}:6443 sh - '"\033[0m\n"
      printf "\033[31m"'==================== JOINING NEW NODE ===================='"\033[0m\n\n\n"

      printf "\033[92m"'============================================================='"\033[0m\n"
      printf "\033[92m"'${local.lxc_count} ${local.lxc_hostname} \t ${local.lxc_net_prefix}.${local.lxc_host_address}-${local.lxc_net_prefix}.${local.lxc_host_address + (local.lxc_count - 1)}'"\033[0m\n"
      printf "\033[92m"'kubevip-IP \t ${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}'"\033[0m\n"
      printf "\033[92m"'============================================================='"\033[0m\n"  
    
    fi   

    EOT
  }



  
}
