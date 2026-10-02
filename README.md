# kubernetes-iac-proxmox

Terraform automation for deploying a highly available K3s cluster on Proxmox LXC with kube-vip, embedded etcd, and automated container provisioning.

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

  **PERMANENT** 
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

- sa





