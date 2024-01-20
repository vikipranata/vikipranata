---
author: "Viki Pranata"
title: "Cluster High Availability Kubernetes Part 2"
description : "Membuat cluster HA Kubernetes dengan Kubeadm untuk kebutuhan lab, development, staging maupun production"
date: "2022-11-15"
tags: ["linux", "Kubernetes", "loadbalancer"]
showToc: true
---
# Lab Environment
Melanjutkan tahap sebelumnya membangun [Kubernetes Cluster High Availability](/posts/kubernetes-ha-part1) jika berjalan diatas openstack cluster.
Namun kita bisa menerapkan ini pada environment virtual machine, cloud, maupun baremetal dengan melewati part 1.

> Software Spec

| Software | Version | Description |
| ---- | ---- | ---- |
| Ubuntu | 20.04 | Operating System |
| Keepalived | latest | High Availability System |
| HAProxy | latest | High Availability System |
| Kubernetes | latest | Container Orchestration |
| Containerd | latest | Container Runtime Interface |
| Calico | latest | Container Network Interface |

> Networking Spec

| Node Name | IP Address | Floating IP | Description |
| ---- | ---- | ---- | ---- | ---- |
| k8s-apiserver | 192.168.0.10 | | Int Load Balance Virtual IP |
| k8s-master01 | 192.168.0.11 | | Int Net |
| k8s-master02 | 192.168.0.12 | | Int Net |
| k8s-master03 | 192.168.0.13 | | Int Net |
| k8s-master01 | 192.168.0.21 | 172.16.0.21 | Int & Ext Net |
| k8s-master02 | 192.168.0.22 | 172.16.0.22 | Int & Ext Net |
| k8s-master03 | 192.168.0.23 | 172.16.0.23 | Int & Ext Net |

## Rancangan Topologi
![image](/assets/images/k8s_kubernetes_ha.webp)

## Inisialisasi cluster Kubernetes pada semua node
> Membuat dan mendistribusikan ssh public key
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -qN ""
for i in {11,12,13,21,22,23}; do ssh-copy-id ubuntu@192.168.0.$i; done
```

### Mapping hostname
> Memetakan alamat ip dengan hostname node
```bash
cat <<EOF | sudo tee -a /etc/hosts
192.168.0.10 k8s-apiserver
192.168.0.11 k8s-master01
192.168.0.12 k8s-master02
192.168.0.13 k8s-master03

192.168.0.100 k8s-lb-ingress
192.168.0.21 k8s-worker01
192.168.0.22 k8s-worker02
192.168.0.23 k8s-worker03
EOF
```

### Menginstall paket untuk kebutuhan High Availability
```bash
sudo apt update && sudo apt install -y haproxy keepalived
```
## Menerapkan HAProxy untuk sistem internal load balancer k8s-apiserver
### Mengkonfigurasi HAproxy pada semua master node
```bash
cat <<EOF | sudo tee -a /etc/haproxy/haproxy.cfg
frontend k8s-apiserver
        bind *:8443
        mode tcp
        option tcplog
        default_backend k8s-apiserver

backend k8s-apiserver
        mode tcp
        option tcp-check
        balance roundrobin
        default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
        server k8s-master01 192.168.0.11:6443 check
        server k8s-master02 192.168.0.12:6443 check
        server k8s-master03 192.168.0.13:6443 check
EOF
```
Lakukan penguijan konfigurasi dengan perintah `sudo haproxy -f /etc/haproxy/haproxy.cfg -c` jika tidak ada pesan error bisa langsung diterapkan konfiruasi yang baru dengan perintah berikut :

```bash
sudo systemctl restart haproxy
```

## Menerapkan keepalived untuk sistem failover
### Mengkonfigurasi check script pada semua master node
```bash
cat <<EOF | sudo tee /etc/keepalived/check_apiserver.sh
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q 192.168.0.10; then
    curl --silent --max-time 2 --insecure https://k8s-apiserver:8443/ -o /dev/null || errorExit "Error GET https://k8s-apiserver:8443/"
fi
EOF
```

```bash
sudo chmod +x /etc/keepalived/check_apiserver.sh
```
### Mengkonfigurasi keepalived pada k8s-master01
```bash
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
global_defs {
    router_id LVS_DEVEL
    enable_script_security
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 2
  weight 2
  rise 3
  fall 3
}

vrrp_instance k8s-apiserver {
    state BACKUP
    nopreempt
    interface ens3
    virtual_router_id 69
    priority 102
    authentication {
        auth_type PASS
        auth_pass R@hasiaD0n9
    } 
    unicast_src_ip 192.168.0.11
    unicast_peer {
      192.168.0.12
      192.168.0.13
    }
    virtual_ipaddress {
      192.168.0.10/24
    }
    track_script {
        check_apiserver
    }
}
EOF
```
```bash
sudo systemctl restart keepalived
```

### Mengkonfigurasi keepalived pada k8s-master02
```bash
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
global_defs {
    router_id LVS_DEVEL
    enable_script_security
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 2
  weight 2
  rise 3
  fall 3
}

vrrp_instance k8s-apiserver {
    state BACKUP
    nopreempt
    interface ens3
    virtual_router_id 69
    priority 101
    authentication {
        auth_type PASS
        auth_pass R@hasiaD0n9
    } 
    unicast_src_ip 192.168.0.12
    unicast_peer {
      192.168.0.13
      192.168.0.11
    }
    virtual_ipaddress {
      192.168.0.10/24
    }
    track_script {
        check_apiserver
    }
}
EOF
```
```bash
sudo systemctl restart keepalived
```

### Mengkonfigurasi keepalived pada k8s-master03
```bash
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
global_defs {
    router_id LVS_DEVEL
    enable_script_security
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 2
  weight 2
  rise 3
  fall 3
}

vrrp_instance k8s-apiserver {
    state BACKUP
    nopreempt
    interface ens3
    virtual_router_id 69
    priority 100
    authentication {
        auth_type PASS
        auth_pass R@hasiaD0n9
    } 
    unicast_src_ip 192.168.0.13
    unicast_peer {
      192.168.0.12
      192.168.0.11
    }
    virtual_ipaddress {
      192.168.0.10/24
    }
    track_script {
        check_apiserver
    }
}
EOF
```
```bash
sudo systemctl restart keepalived
```
Tahap selanjutnya dalam membangun [Kubernetes Cluster High Availability](/posts/kubernetes-ha-part3).

# Sumber Referensi
- https://kubesphere.io/docs/v3.3/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy
- https://github.com/sandervanvugt/cka/blob/master/check_apiserver.sh