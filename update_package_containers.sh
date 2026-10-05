#!/bin/sh
sleep 10

if command -v apt-get &> /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt update && apt upgrade -y && apt install -y curl iptables
elif command -v dnf &> /dev/null; then
    dnf update -y && dnf install -y curl iptables
    tee /etc/NetworkManager/conf.d/k3s-cni.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:cni0;interface-name:flannel*;interface-name:veth*
EOF
elif command -v yum &> /dev/null; then
    yum update -y && yum install -y curl iptables
    tee /etc/NetworkManager/conf.d/k3s-cni.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:cni0;interface-name:flannel*;interface-name:veth*
EOF
elif command -v apk &> /dev/null; then
    apk update && apk add curl iptables && \

    # moves processes that are currently in the root cgroup /sys/fs/cgroup/cgroup.procs into a child cgroup /sys/fs/cgroup/init/
    cat >> /etc/init.d/cgroups-reparent <<'EOF'
#!/sbin/openrc-run

depend() {
    need cgroups
}

start() {
    # https://github.com/moby/moby/blob/38805f20f9bcc5e87869d6c79d432b166e1c88b4/hack/dind#L30-L34
    # move the processes from the root group to the /init group,
    # otherwise writing subtree_control fails with EBUSY.
    ebegin "Reparent processes for cgroup delegation"
    mkdir -p /sys/fs/cgroup/init
    xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs
    eend 0
}
EOF

    chmod 755 /etc/init.d/cgroups-reparent
    rc-update add cgroups boot
    rc-update add cgroups-reparent boot

fi

# allow kubelet to run inside a Linux user namespace
mkdir -p /etc/rancher/k3s
cat >> /etc/rancher/k3s/config.yaml <<'EOF'
    kubelet-arg:
        - "feature-gates=KubeletInUserNamespace=true"
EOF

reboot