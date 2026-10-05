# Terraform IaC: Highly Available K3s Cluster on Proxmox LXC

Infrastructure as Code (IaC) project using Terraform to automate the deployment of a highly available K3s Kubernetes cluster on Proxmox LXC containers.

The project automates LXC container provisioning and K3s cluster configuration, including multiple control-plane nodes, kube-vip for a highly available Kubernetes API endpoint and Service LoadBalancer, and embedded etcd for the cluster datastore.

The goal is to provide a reproducible and automated approach to building and managing a K3s HA environment on Proxmox.


## Prerequisites
- Make sure to download the lxc container templates.  
  I have tested    
  **alpine-3.24-default_20260714_amd64.tar.xz**    
  **almalinux-10-default_20250930_amd64.tar.xz**        
  **debian-13-standard_13.6-1_amd64.tar.zst**      
  **rockylinux-10-default_20251001_amd64.tar.xz**     
  **ubuntu-26.04-standard_26.04-1_amd64.tar.zst**

  <img width="760" height="270" alt="image" src="https://github.com/user-attachments/assets/a1b2715f-3ca5-49b7-a50b-7edbcab85691" />


- Create API token from Datacenter - Permissions - API Tokens. Take note **Token ID** and **Secret**
  
  <img width="680" height="250" alt="image" src="https://github.com/user-attachments/assets/db7592e4-c49a-485d-b881-a14453ee41bf" />

  
- Enable snippets from Datacenter - Storage - local
  <img width="750" height="370" alt="image" src="https://github.com/user-attachments/assets/d97700e0-90df-458e-8af1-0b1394201813" />
- In Proxmox host, make sure IP forwarding enable ```net.ipv4.ip_forward = 1```  
  Check using this command
  ```
  sysctl net.ipv4.ip_forward
  ```
  Enable IP forwarding
  ```
  sysctl -w net.ipv4.ip_forward=1
  ```

  **MAKE IT PERMANENT** 
  ```
  echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ip-forward.conf
  sysctl -p /etc/sysctl.d/99-ip-forward.conf
  ```
- From your device
  create ssh key without passphrase for Proxmox user (in this case I am using root) 
  ```
  ssh-keygen -f ~/.ssh/sshkey
  ```
  Upload public key to your Proxmox root user
  ```
  ssh-copy-id -i ~/.ssh/sshkey root@<PROXMOX_HOST>
  ```
  Try to connect to Proxmox host using sshkey. First connect you need to type yes to trust the server
  ```
  ssh -i ~/.ssh/sshkey root@<PROXMOX_HOST>
  ```
## Start
- Clone this repo
  ```
  git clone https://github.com/tobing/kubernetes-iac-proxmox.git
  cd kubernetes-iac-proxmox
  ```
- Open ```main.tf``` and modify these **IMPORTANT** values
  ```
  # Need to connect to Proxmox host and execute commands
  proxmox_host              = "192.168.31.2"
  proxmox_port              = 8006
  proxmox_node_name         = "pve"

  proxmox_ssh_key           = "/home/myuser/.ssh/sshkey"
  proxmox_user              = "root"
  proxmox_realm             = "pam"
  proxmox_api_token_id      = "proxmox_token_id" # Token ID after "<user>@<realm>!"
  proxmox_api_token_secret  = "xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Token secret

  lxc_root_password         = "password123" # set root password for container
  lxc_root_public_key       = "/home/myuser/.ssh/sshkey.pub" # PUBLIC KEY. I am using same key as key to connect to proxmox host. You need the private key to connect to container

  # This will make first lxc container become 192.168.31.50...192.168.31.[50 +  lxc_count.index]
  # Kubevip Virtual IP will be the last one. first control-plane IP + lxc_count. 
  # Index started at 0 so 3 lxc containers control-planes (192.168.31.[50+0]), (192.168.31.[50+1]), (192.168.31.[50+2]). Kubevip (192.168.31.[50+3])
  # Change these according to your network
  lxc_net_prefix            = "192.168.31"
  lxc_host_address          = 50
  lxc_gateway               = "192.168.31.1"

  # IP pool for apps 192.168.31.90-192.168.31.100
  lxc_kubevip_ip_start      = 90
  lxc_kubevip_ip_end        = 100
  ```  
- Run this command, it will install bpg/proxmox provider
  ```
  terraform init
  ``` 
- Validate if any error
  ```
  terraform validate
  ```
- Execute with this command, type ```yes``` to confirm
  ```
  terraform apply
  ```
- Running with Alpine 3.24 lxc container
  <video src="https://github.com/user-attachments/assets/98cb5433-a521-4d67-8648-886ba2f0c479" controls></video>

  Rocky Linux
  <img width="2622" height="405" alt="image" src="https://github.com/user-attachments/assets/98fefe24-3e97-4104-ae6b-41070785760d" />
  

  Debian Linux
  <img width="2615" height="398" alt="image" src="https://github.com/user-attachments/assets/39dfefab-e4df-495f-8d33-3cf339f4917a" />

  Ubuntu Linux
  <img width="2615" height="398" alt="image" src="https://github.com/user-attachments/assets/3d4b408d-3481-4efb-8a6d-a8fedb504636" />


> [!NOTE]
> **Terraform Workflow**
>

<details>
  

- Make lxc containers less restricted

  ```
  cat >> /etc/pve/lxc/<CONTAINER_ID>.conf <<'EOF'
  lxc.apparmor.profile: unconfined
  lxc.mount.auto: proc:rw sys:rw
  lxc.mount.entry: /dev/kmsg dev/kmsg none bind,create=file
  EOF"
  ```
- Run [`update_package_containers.sh`](update_package_containers.sh)

- On the first container prepare kube-vip RBAC and run cluster init for K3s
  ```
  mkdir -p /var/lib/rancher/k3s/server/manifests/ && curl https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml
  /bin/sh -c ' curl -sfL https://get.k3s.io | K3S_TOKEN=${local.lxc_k3s_token} sh -s - server \
      --disable=servicelb \
      --cluster-init \
      --tls-san=${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count} '
  ```
- On the other containers, wait until cluster init done then set up K3s
  ```
  /bin/sh -c ' curl -sfL https://get.k3s.io | K3S_TOKEN=${local.lxc_k3s_token} sh -s - server \
      --disable=servicelb \
      --server https://${local.lxc_net_prefix}.${local.lxc_host_address}:6443 \
      --tls-san=${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count} '
  ```  
- Prepare [`kubevip-daemonset.yaml`](kubevip-daemonset.yaml) and upload to the first node
  ```
  /bin/sh -c 'cat > /etc/rancher/k3s/kubevipdaemonset.yaml'" <<'YAML'
  ${templatefile("${path.module}/kubevip-daemonset.yaml", {
    kubevip_version = local.lxc_kubevip_version
    network_iface   = local.lxc_network_iface
    vip_address     = "${local.lxc_net_prefix}.${local.lxc_host_address + local.lxc_count}"
  })}
  YAML
  ```
- On the first node
  ```
  /usr/local/bin/kubectl apply -f /etc/rancher/k3s/kubevipdaemonset.yaml
  /usr/local/bin/kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
  /usr/local/bin/kubectl create configmap -n kube-system kubevip --from-literal range-global=${local.lxc_net_prefix}.${local.lxc_kubevip_ip_start}-${local.lxc_net_prefix}.${local.lxc_kubevip_ip_end}
  ```

- **!! Check error during deployment !!**    
  <img width="1898" height="741" alt="image" src="https://github.com/user-attachments/assets/ac024f4b-eb25-47c9-8f4a-7294944459c5" />

</details>
