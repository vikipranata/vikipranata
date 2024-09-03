---
title: "Linux Networking"
date: 2024-09-02 09:10:00 +0700
modified: 2024-09-02 09:10:00 +0700
tags: [linux, networking, router]
description: ""
---
# **Configure Linux NAT Forwarding**

Enable kernel parameter  
```bash
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-forwarding.conf
sysctl --system
```

Setup firewalld configuration  
```bash
nmcli connection migrate
nmcli connection modify eth0 connection.zone public
nmcli device modify eth0 connection.zone public
nmcli connection modify eth1 connection.zone internal
nmcli device modify eth1 connection.zone internal

firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --permanent --new-policy NAT-int-to-ext
firewall-cmd --permanent --policy NAT-int-to-ext --add-ingress-zone internal
firewall-cmd --permanent --policy NAT-int-to-ext --add-egress-zone public
firewall-cmd --permanent --policy NAT-int-to-ext --set-target ACCEPT
firewall-cmd --reload
````

Special case for Proxmox Virtual Environment
```bash
auto vmbr0
iface vmbr0 inet manual
        bridge-ports eth0
        bridge-stp off
        bridge-fd 0
        post-up echo 1 > /proc/sys/net/ipv4/conf/vmbr0/forwarding
        post-down echo 0 > /proc/sys/net/ipv4/conf/vmbr0/forwarding
#Public Network
```

Reference:  
- [https://wiki.archlinux.org/title/Firewalld#NAT\_masquerade](https://wiki.archlinux.org/title/Firewalld#NAT_masquerade)  
- [https://serverfault.com/questions/1005682/proxmox-ipv4-inward-routing-not-working](https://serverfault.com/questions/1005682/proxmox-ipv4-inward-routing-not-working)

# **Configure linux simple DNS server for lab purposes**
Installing package dependencies  
```bash
dnf install -y dnsmasq
````

Setup dnsmasq upstream forward server  
```bash
cat <<EOF | tee -a /etc/dnsmasq.conf
server=1.1.1.1
server=1.0.0.1
EOF
```

Setup dnsmasq to rewrite dns request
```bash
cat <<EOF | tee /etc/dnsmasq.d/lab.tworty.id.conf
address=/tworty.id/10.79.80.3
cname=blog.tworty.id,tworty.id
EOF
```