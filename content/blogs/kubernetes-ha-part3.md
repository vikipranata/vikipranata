---
author: "Viki Pranata"
title: "Cluster High Availability Kubernetes Part 3"
description : "Membuat cluster HA Kubernetes dengan Kubeadm untuk kebutuhan lab, development, staging maupun production"
date: "2022-11-15"
tags: ["linux", "Kubernetes", "loadbalancer"]
showToc: true
---
# Lab Environment
Melanjutkan tahap sebelumnya membangun [Kubernetes Cluster High Availability](/posts/kubernetes-ha-part2).

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
### Forwarding ipv4 dan membolehkan iptables melihat traffic bridge
> Menerapkan module overlay dan br_netfilter
```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```
> Untuk memuat modul secara eksplisit
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

> Menambahkan parameter sysctl untuk iptables melihat traffic bridge
```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```
> Menerapkan parameter sysctl tanpa reboot
```bash
sudo sysctl --system
```
### Menambahkan repositori Docker
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
```
### Menambahkan repositori Kubernetes
```bash
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### Menginstall paket yang diperlukan dan mencekah auto upgrade
```bash
sudo apt update && sudo apt install -y kubelet kubeadm kubectl containerd.io
sudo apt-mark hold kubelet kubeadm kubectl containerd.io
```

### Konfigurasi Containerd
```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
```

## Mendeploy cluster kubernetes
### Inisialisasi control plane node atau master nonde
> Jalankan pada node k8s-master01
```bash
sudo kubeadm config images pull
sudo kubeadm init --control-plane-endpoint k8s-apiserver:8443 --upload-certs
```
Akan mendapatkan hasil seperti berikut :
![image](/assets/images/kubeadmsuccessfull.webp)

> Copy credentials kubernetes cluster
```bash
mkdir -p $HOME/.kube
sudo cp -r /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

cat <<EOF | sudo tee >> ~/.profile
source <(kubeadm completion bash)
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF

source ~/.profile
```

> Menerapkan CNI Calico
```bash
kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml
watch kubectl -n kube-system get pod -o wide
```
### Join cluster master node
> Jalankan pada node k8s-master02 dan node k8s-master03
```bash
sudo kubeadm join k8s-apiserver:8443 --token xbvd7t.s891wt8dk17q8y6f \
--discovery-token-ca-cert-hash sha256:b7a659759eed0776bfb94e9da4ac3369de863aaba2d85e88d22db4ba263cded4 \
--control-plane --certificate-key c978c9f0213f31007a9f5f98050503112b051aa0136a05eb27987719fe748e4a
```

### Join cluster worker node
> Jalankan pada worker node
```bash
sudo kubeadm config images pull
sudo kubeadm join k8s-apiserver:8443 --token xbvd7t.s891wt8dk17q8y6f --discovery-token-ca-cert-hash sha256:b7a659759eed0776bfb94e9da4ac3369de863aaba2d85e88d22db4ba263cded4
```

### Mengakses sumber daya kubernetes
> Jalankan pada master node
```bash
# Melihat daftar node
kubectl get node -o wide

# Melihat pod kube-system
kubectl -n kube-system get pod

# Melihat semua service kubernetes
kubectl get svc -A -o wide
```

![image](/assets/images/k8s_resources.webp)

## Sumber Referensi
- https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/change-runtime-containerd
- https://kubernetes.io/docs/setup/production-environment/container-runtimes
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm
- https://docs.docker.com/engine/install/ubuntu/
- https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises
- https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/change-runtime-containerd