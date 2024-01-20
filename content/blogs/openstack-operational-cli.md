---
author: "Viki Pranata"
title: "Mengoperasikan OpenStack Lewat CLI"
description : "Mengoperasikan OpenStack lewat command line yang bisa digunakan untuk persiapan COA (Certified OpenStack Administrator)"
date: "2022-10-31"
tags: ["linux", "openstack", "cloud"]
showToc: true
---

Artikel ini adalah lanjutan dari [Membuat cluster OpenStack dengan Kolla-Ansible untuk kebutuhan lab](/posts/openstack-for-lab) dan [Cluster OpenStack dengan Ceph Storage](/posts/openstack-integrating-ceph)

Untuk mengoperasikan openstack ada beberapa langkah sebagai berikut ini :
## Mengakses Cluster
### Menggunakan OpenStack RC File
RC file ini adalah kumpulan variable yang akan digunakan untuk mengakses openstack dengan user maupun project tertentu.
![image](/assets/images/openstack-lab-1.webp)
```bash
source ~/admin-openrc.sh
```

### Membuat Project
```bash
openstack project create --enable --description "project for kubernetes" kubernetes
openstack project list --long
```

### Membuat User dan Project Role
```bash
openstack user create --project admin --email viki@syslog.my.id --password p@ssw0rd viki
openstack user create --project kubernetes --email k8s@syslog.my.id --password-promt k8s
openstack user set viki --project kubernetes
```

```bash
# Verification
for i in {viki,k8s}; do openstack user show $i; done
```

```bash
openstack role add --user viki --project admin admin
openstack role add --user viki --project kubernetes member
openstack role add --user k8s --project kubernetes admin
```

```bash
# Verification
for i in {viki,k8s}; do openstack role assignment list --user $i --names; done
```

Referensi <cite>[^1][^2][^3]</cite>
[^1]: https://docs.openstack.org/python-openstackclient/latest/cli/command-objects/project-v2.html#project-create
[^2]: https://docs.openstack.org/python-openstackclient/latest/cli/command-objects/user-v2.html#user-create
[^3]: https://docs.openstack.org/keystone/rocky/admin/cli-manage-projects-users-and-roles.html

### Membuat Project Quota
```bash
openstack quota set --core 24 --ram 20480 --instances 10 --volumes 10 --floating-ips 6 --secgroups 2 kubernetes
```

### Membuat Images
Downlaoad terlebih dahulu file cloud image
```bash
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
curl -LO https://download.cirros-cloud.net/0.6.1/cirros-0.6.1-x86_64-disk.img
```
Lalu memngimport image yang sudah didownload tadi ke openstack dengan perintah berikut :
```bash
openstack image create --public --disk-format qcow2 --file cirros-0.6.1-x86_64-disk.img cirros-test
openstack image create --public --disk-format qcow2 --file focal-server-cloudimg-amd64.img ubuntu20-focal
openstack image list
```

### Membuat Flavor
Flavor disini adalah spesifikasi sebuah instance yang akan kita terapkan. Untuk membuatnya sebagai contoh _1 VCPU_ dan _1GB RAM_ dengan _10GB Disk_ dengan perintah berikut :
```bash
openstack flavor create --project kubernetes --private --vcpu 2 --ram 2048 --disk 2 n1-kubemaster
openstack flavor create --project kubernetes --private --vcpu 4 --ram 4096 --disk 4 n2-kubeworker
openstack flavor list --all
```

### Membuat SSH Keypair
Keypair  disini adalah ssh keypair dimana kita biasa membuat nya dengan perintah `ssh-keygen` yang akan mendapatkan dua buah file public key dan private key, hal ini akan membantu cloudinit untuk memasukan public key ke dalam instance. Untuk membuat keypair gunakan perintah berikut :
```bash
openstack keypair create --public-key ~/.ssh/id_rsa.pub controller-key
openstack keypair create --public-key ~/.ssh/k8s.pub k8s-key
```

### Membuat Security Group
Security group  adalah sebuah firewall pada level instance. Untuk membuatnya sebagai contoh kita akan menerapkan koneksi masuk _ingress_ dari port ssh tcp 22 dan port web service tcp 80,443 serta protocol icmp dengan perintah berikut :
```bash
openstack security group create kubesecgroup
openstack security group rule create --ingress --protocol icmp
openstack security group rule create --ingress --protocol tcp --dst-port 22 --description ssh
openstack security group rule create --ingress --protocol tcp --dst-port 80 --description http
openstack security group rule create --ingress --protocol tcp --dst-port 443 --description https
openstack security group rule create --ingress --protocol tcp --dst-port 6443 --description api-service
openstack security group rule create --ingress --protocol tcp --dst-port 8443 --description ha-api-service
openstack security group show kubesecgroup
```

***Membuat Apps Security Group***
```bash
openstack security group create app-secgroup
openstack security group rule create --ingress --protocol tcp --dst-port 30080 --description http-ingress
openstack security group rule create --ingress --protocol tcp --dst-port 30443 --description https-ingress
```

### Membuat External Network
External network digunakan untuk komunikasi keluar instance lewat external provider, untuk membuatnya kita perlu mengetahui _provider physical network_ nya terlebih dahulu dengan perintah berikut :
```bash
sudo cat /etc/kolla/neutron-server/ml2_conf.ini | grep flat_network | awk '{print $3}'
```
lalu mendefinisikan network dan subnet dengan menggunakan perintah berikut :
```bash
openstack network create --project admin --external --provider-network-type flat --provider-physical-network physnet1 ext-net
openstack subnet create --network ext-net --subnet-range 172.16.1.0/24 --gateway 172.16.1.1 --dns-nameserver 172.16.1.1 --allocation-pool start=172.16.1.242,end=172.16.1.254 --no-dhcp ext-subnet
openstack network list --long
openstack subnet list --long
```

### Membuat Internal Network
Internal network digunakan untuk komunikasi antar instance lewat jaringan internal, untuk membuatnya kita perlu mendefinisikan network dan subnet dengan menggunakan perintah berikut :
```bash
openstack network create --internal kubenet
openstack subnet create --network kubenet --subnet-range 10.1.0.0/24 --gateway 10.1.0.1 kubesubnet
openstack network list --long
openstack subnet list --long
```

### Membuat Router
Router pada openstack berfungsi untuk menghubungkan antara traffic internal ke external baik koneksi masuk _ingress_ maupun koneksi keluar _egress_, untuk membuat router gunakan perintah berikut :
```bash
openstack router create kuberouter
openstack router set --external-gateway ext-net kuberouter
openstack router add subnet kuberouter kubesubnet
openstack router show kuberouter
```

### Membuat Instance
Setelah persiapan langkah diatas sudah diterapkan, barulah kita bisa membuat instance dengan perintah berikut :
```bash
openstack server create --flavor n1-kubemaster --network kubenet --key-name k8s-key --image ubuntu20-focal --security-group kubesecgroup k8s-master01
openstack server create --flavor n2-kubeworker --network kubenet --key-name k8s-key --image ubuntu20-focal --security-group kubesecgroup k8s-worker01
```

### Mambuat Floating IP
Floating IP difungsikan sebagai NAT untuk diterapkan ke internal ip pada instance, untuk membuat floating ip gunakan perintah berikut :
```bash
openstack floating ip create --floating-ip 172.16.1.244 ext-net
openstack floating ip create --floating-ip 172.16.1.245 ext-net
openstack floating ip list
openstack server add floating ip k8s-master01 172.16.1.244
openstack server add floating ip k8s-worker01 172.16.1.245
openstack server list
```

### Membuat Volume
Volume digunakan sebagai persistent disk pada instance berupa block storage, untuk membuat volume dan memasangkannya pada instance gunakan perintah berikut :
```bash
openstack volume create --size 1 mvolume
openstack server add volume k8s-master01 mvolume
```

***Memperbesar Volume***
```bash
openstack server remove volume k8s-master01 mvolume
openstack volume set --size 2 mvolume
openstack volume list
openstack server add volume k8s-master01 mvolume
openstack server show k8s-master01
```

### Instance Persistent Storage
Untuk membuat persistent storage pada partisi root pada saat instance dibuat, gunakan perintah berikut :
```bash
openstack volume create --size 10 --image ubuntu20-focal web-server-ubuntu02
openstack server create --flavor c1-standard-01 \
  --key-name controllerkey \
  --security-group secg-basic-web \
  --network int-net01 \
  --volume web-server-ubuntu02 --wait \
  web-server-ubuntu02
```

### Upgrade Instance dengan Flavor
Semakin berjalannya waktu spesifikasi instance yang kita buat terkadang perlu di upgrade untuk memenuhi kebutuhan sumber daya yang akan digunakan, untuk menerapkan nya ikuti perintah berikut :
```bash
openstack flavor create --vcpus 2 --ram 2048 --disk 15 --public c2-standard-01
openstack server resize --flavor c2-standard-01 web-server-ubuntu01
openstack server list | grep web-server-ubuntu01
openstack server resize confirm web-server-ubuntu01
```

## Referensi
- https://docs.openstack.org/python-openstackclient/latest/cli/