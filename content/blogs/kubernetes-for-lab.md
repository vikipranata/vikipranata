---
author: "Viki Pranata"
title: "Cluster Kubernetes for Lab"
description : "Membuat cluster Kubernetes untuk kebutuhan lab"
date: "2022-11-15"
tags: ["linux", "Kubernetes"]
showToc: true
---

## Lab Environment
Spesifikasi instance yang akan dibuat pada [cluster openstack](/posts/openstack-for-lab) yang telah kita bangun sebelumnya.
Namun kita bisa menerapkan ini pada environment virtual machine, cloud, maupun baremetal dengan langsung menuju langkah [inisialisasi cluster kubernetes.](/posts/kubernetes-for-lab/#inisialisasi-cluster-kubernetes-pada-semua-node)

### Software
| Software | Version | Description |
| ---- | ---- | ---- |
| Ubuntu | 20.04 | Operating System |
| Kubernetes | v1.20.0 | Container Orchestration |
| Docker | latest | Container Runtime Interface |
| Calico | v3.20 | Container Network Interface |

### Hardware
| Node Name | Processor | RAM | Volumes |Description |
| ---- | ---- | ---- | ---- | ---- |
| k8s-master-node | 2 Core | 2 GB | 15 GB | Control Plane Node |
| k8s-worker-node01 | 2 Core | 2 GB | 15 GB | Worker Node |
| k8s-worker-node02 | 2 Core | 2 GB | 15 GB | Worker Node |

### Networking
| Node Name | IP Address | Description |
| ---- | ---- | ---- | ---- |
| k8s-master-node | 192.168.0.101 | Int & External Network |
| k8s-worker-node01 | 192.168.0.102 | Internal Network |
| k8s-worker-node02 | 192.168.0.103 | Internal Network |

### Topologi
![img](/assets/images/kube-lab.webp)

## Inisialisasi VM OpenStack
### Membuat Port
```bash
openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.101 k8s-master-node
openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.102 k8s-worker-node01
openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.103 k8s-worker-node02
```
### Membuat Persistent Volume
```bash
openstack volume create --size 15 --image ubuntu-focal-20.04 --wait k8s-master-node
openstack volume create --size 15 --image ubuntu-focal-20.04 --wait k8s-worker-node01
openstack volume create --size 15 --image ubuntu-focal-20.04 --wait k8s-worker-node02
```
### Membuat Security Group
```bash
openstack security group create secg-kubernetes --description 'Kubernetes environment'
openstack security group rule create --protocol icmp secg-kubernetes
for i in {22,80,443,6443}; do openstack security group rule create --protocol tcp --ingress --dst-port $i secg-kubernetes
```
### Membuat Flavor
```bash
openstack flavor create --vcpus 2 --ram 2048 --disk 15 --public c2-standard-01
```

### Membuat Instance
```bash
openstack server create --flavor c2-standard-01 --key-name controllerkey --security-group secg-kubernetes --volume k8s-master-node --port k8s-master-node --wait k8s-master-node
openstack server create --flavor c2-standard-01 --key-name controllerkey --security-group secg-kubernetes --volume k8s-worker-node01 --port k8s-worker-node01 --wait k8s-worker-node01
openstack server create --flavor c2-standard-01 --key-name controllerkey --security-group secg-kubernetes --volume k8s-worker-node02 --port k8s-worker-node02 --wait k8s-worker-node02
```

## Inisialisasi cluster Kubernetes pada semua node
> Membuat dan mendistribusikan ssh public key
```bash
ssh-keygen -t rsa -b 4096
ssh-copy-id ubuntu@192.168.0.101
ssh-copy-id ubuntu@192.168.0.102
ssh-copy-id ubuntu@192.168.0.103
```

### Mapping hostname
> Memetakan alamat ip dengan hostname node
```bash
cat <<EOF | sudo tee -a /etc/hosts
192.168.0.101 k8s-master-node
192.168.0.102 k8s-worker-node01
192.168.0.103 k8s-worker-node02
EOF
```

### Disable swap
> Agar kubelet bekerja dengan baik perlu mendisable swap pada node
```bash
sudo nano /etc/fstab
sudo swapoff -a
```

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
### Menambahkan repositori Docker dan Kubernetes
```bash
# Download GPG key dari repositori
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add –
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```
```bash
# Tambahkan repository
echo "deb https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### Menginstall paket yang diperlukan dan mencegah auto upgrade
```bash
sudo apt update && sudo apt install -y kubeadm=1.20.0-00 kubelet=1.20.0-00 kubectl=1.20.0-00 docker-ce
sudo apt-mark hold kubelet kubeadm kubectl docker-ce
```

### Konfigurasi Docker
> Menerapkan cgroup driver systemd dan beberapa parameter
```bash
cat <<EOF | sudo tee /etc/docker/daemon.json
{
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
      "max-size": "100m"
      },
      "storage-driver": "overlay2"
}
EOF
```
> Menerapkan konfigurasi docker
```bash
sudo systemctl restart docker.service
```

## Mendeploy cluster master node
> Jalankan pada master node
```bash
sudo kubeadm config images pull
sudo kubeadm init --control-plane-endpoint k8s-master-node:6443 --upload-certs --pod-network-cidr=10.244.0.0/16
```
Akan mendapatkan hasil seperti berikut :
![image](/assets/images/kubeadmsuccessfull.webp)

> Copy credentials kubernetes cluster
```bash
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

> Menerapkan CNI Flannel
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
watch kubectl -n kube-system get pod -o wide
```

### Join cluster worker node
> Jalankan pada worker node
```bash
sudo kubeadm config images pull
sudo kubeadm join k8s-master-node:6443 --token fou63o.wy0331rpp3313lsa --discovery-token-ca-cert-hash sha256:0472c1c9354548501c42028ff72a6dfc4bffe3a225e3a31fe40cec814fa6eef2
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

## Sumber Referensi
- https://kubernetes.io/docs/setup/production-environment/container-runtimes
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm
- https://docs.docker.com/engine/install/ubuntu/
- https://github.com/flannel-io/flannel
