---
author: "Viki Pranata"
title: "Cluster OpenStack dengan Kolla-Ansible"
description : "Membuat cluster openstack dengan Kolla-Ansible untuk kebutuhan lab"
date: "2022-10-31"
tags: ["linux", "openstack", "cloud"]
showToc: true
---

Untuk kebutuhan lab openstack setidaknya memiliki 1 host untuk controller dan 2 host untuk compute baik berupa mesin virtual maupun _baremetal_ untuk spesifikasinya sebagai berikut :
| Node Name | Processor | RAM | Root / Volumes | Cinder Volumes | Ip Address |
| ---- | ---- | ---- | ---- | ---- | ---- |
| openstack-controller | 8 Core | 8 GB | 80 GB (sda)| | 10.79.0.10 |
| openstack-compute01 | 16 Core | 16 GB | 40 GB (sda) | 100 GB (sdb) | 10.79.0.11 |
| openstack-compute02 | 16 Core | 16 GB | 40 GB (sda) | 100 GB (sdb) | 10.79.0.12 |

Lalu untuk kebutuhan jaringan openstack dengan rincian sebagai berikut :
| Name | Network | Virtual IP | Interface |
| ---- | ---- | ---- | ---- |
| Internal | 10.79.0.0/24 | 10.79.0.254 | ens18 |
| Provider | 172.16.0.0/24 |  | ens19 |

Semua node menggunakan sistem operasi `Ubuntu 20.04 Focal` dengan versi `OpenStack Yoga` dengan username setiap node bernama `vq`
> Sesuaikan dengan environment lab anda

## Rancangan Topologi

![image](/assets/images/Topologi-Openstack-Lab.webp)

## Persiapan Cluster
### 1. Membuat dan mendistribusikan ssh public key
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment
```bash
ssh-keygen -t rsa -b 4096 -q -N ""

ssh-copy-id vq@10.79.0.10
ssh-copy-id vq@10.79.0.11
ssh-copy-id vq@10.79.0.12
```

### 2. Memverifikasi koneksi sesi ssh
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment
```bash
for i in {0..2}; do ssh vq@10.79.0.1$i 'echo $(whoami) $(hostname)'; done
```

### 3. Memberikan full privileges sudo tanpa memasukan password
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment, openstack-compute01, dan openstack-compute02
```
echo 'vq ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vq
```

### 4. Menambahkan mapping hosts nama node dan persiapan node
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment, openstack-compute01, dan openstack-compute02
```bash
cat <<EOF | sudo tee -a /etc/hosts
10.79.0.254 vpc.syslog.my.id
10.79.0.10 openstack-controller
10.79.0.11 openstack-compute01
10.79.0.12 openstack-compute02
EOF
```

### 5. Membuat volume group untuk cinder volumes
> Eksekusi perintah pada openstack-compute01, dan openstack-compute02
```bash
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo vgdisplay cinder-volumes
sudo vgs
```

### 6. Memasang dependensi yang dibutuhkan oleh kolla-ansible
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y gcc libffi-dev libssl-dev python3-dev python3-selinux python3-setuptools python3-venv python3-pip net-tools
```

Membuat dan mengaktifkan virtual environment kolla
```bash
python3 -m venv kolla
source ~/kolla/bin/activate
```
![image](/assets/images/kolla-activate.webp)

Update pip dan install dependensi kolla-ansible
```bash
pip install -U pip
pip install 'ansible>=4,<6'
pip install kolla-ansible
kolla-ansible install-deps
```
```bash
sudo mkdir /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla/share/kolla-ansible/etc_examples/kolla/passwords.yml /etc/kolla
cp -r ~/kolla/share/kolla-ansible/etc_examples/kolla/globals.yml /etc/kolla
cp -r ~/kolla/share/kolla-ansible/ansible/inventory/* ~/
```
> **Catatan: untuk selanjutnya harus selalu menjalankan perintah pada virtual environment kolla yang sudah di aktifkan**

### 7. Konfigurasi Ansible
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment
```bash
sudo mkdir /etc/ansible && sudo nano /etc/ansible/ansible.cfg
[defaults]
host_key_checking=False
pipelining=True
forks=100
```

### 8. Persiapan Menggunakan Kolla-Ansible
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment

Sesuaikan isi file ~/multinode seperti berikut

```yaml
# These initial groups are the only groups required to be modified. The
# additional groups are for more control of the environment.
[control]
openstack-controller       ansible_connection=local

[network]
openstack-controller       ansible_connection=local

[compute]
openstack-compute01
openstack-compute02

[storage]
openstack-compute01
openstack-compute02

[monitoring]
openstack-controller       ansible_connection=local

[deployment]
localhost                  ansible_connection=local
## Apart from this, there are no changes below!
```

Sesuaikan isi file /etc/kolla/globals.yaml seperti berikut
```yaml
nano /etc/kolla/globals.yaml
kolla_base_distro: "ubuntu"
kolla_install_type: "source"
openstack_release: "yoga"
kolla_internal_vip_address: "10.79.0.254"
kolla_internal_fqdn: "vpc.syslog.my.id"
network_interface: "ens18"
neutron_external_interface: "ens19"
neutron_plugin_agent: "openvswitch"
enable_openstack_core: "yes"
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
enable_neutron_provider_networks: "yes"
enable_neutron_trunk: "yes"
```
Verifikasi hasil konfigurasi globals.yaml
```bash
cat /etc/kolla/globals.yml | grep -v "#" |  tr -s [:space:]
```

Generate password untuk cluster openstack
```bash
kolla-genpwd
```
Verifikasi hasil generate password
```bash
cat /etc/kolla/passwords.yml
```

### 9. Deployment OpenStack
> Eksekusi perintah pada openstack-controller dengan Kolla virtual environment
```bash
ansible -i ~/multinode all -m ping
    # if no error detect, next step
kolla-ansible -i ~/multinode bootstrap-servers
    # if no error detect, next step
kolla-ansible -i ~/multinode prechecks
    # if no error detect, next step
kolla-ansible -i ~/multinode pull
    # if no error detect, next step
kolla-ansible -i ~/multinode deploy
    # if no error detect, next step
kolla-ansible -i ~/multinode post-deploy
cp -r /etc/kolla/admin-openrc.sh ~/
```

### 10. Mengkases Cluster OpenStack
> Eksekusi perintah pada openstack-controller

menonaktifkan kolla virtual environment
```bash
deactivated
```
![image](/assets/images/kolla-deactivate.webp)

#### Menggunakan CLI OpenStack client
```bash
sudo apt install -y python3-openstackclient
source ~/admin-openrc.sh
openstack compute service list && openstack service list
```

```yaml
+----+----------------+----------------+----------+---------+-------+----------------------------+
| ID | Binary         | Host           | Zone     | Status  | State | Updated At                 |
+----+----------------+----------------+----------+---------+-------+----------------------------+
|  1 | nova-scheduler | openstack-controller | internal | enabled | up    | 2022-11-02T06:11:04.000000 |
|  1 | nova-conductor | openstack-controller | internal | enabled | up    | 2022-11-02T06:11:04.000000 |
|  5 | nova-compute   | openstack-compute01    | nova     | enabled | up    | 2022-11-02T06:11:11.000000 |
|  6 | nova-compute   | openstack-compute02    | nova     | enabled | up    | 2022-11-02T06:11:12.000000 |
+----+----------------+----------------+----------+---------+-------+----------------------------+
+----------------------------------+-------------+----------------+
| ID                               | Name        | Type           |
+----------------------------------+-------------+----------------+
| 14c4d8549cb3412db1a9cd15918a26e2 | cinderv3    | volumev3       |
| 1c68696f28124cebad86c51aeed4c659 | heat-cfn    | cloudformation |
| 46324c57d2b244188531c7eccaa21239 | heat        | orchestration  |
| 5ae2c6cc726c475bbeca0da99a20de36 | nova_legacy | compute_legacy |
| a6c1793399ea43f6a4dc138e81633a55 | glance      | image          |
| c694e26fb0b84cbb8e9e9ae7ebb7fd40 | nova        | compute        |
| d99e29796266455c85d9a0833cb62d14 | placement   | placement      |
| eda384c5f3ba4132a9f8dcbfd76f250d | keystone    | identity       |
| f6d629464f20413182ceed7b1b3cd72a | neutron     | network        |
+----------------------------------+-------------+----------------+
```

#### Menggunakan GUI OpenStack
Melihat kredensial username dan password pada file admin-openrc.sh
![image](/assets/images/openstack-lab-1.webp)
![image](/assets/images/openstack-lab-2.webp)

Selanjutnya untuk tahap [mengoperasikan openstack via CLI](/posts/openstack-operational-cli)

## Sumber Referensi
- https://docs.openstack.org/kolla-ansible/latest/
- https://docs.openstack.org/kolla-ansible/latest/user/operating-kolla.html
- https://docs.openstack.org/kolla-ansible/latest/reference/deployment-and-bootstrapping/bootstrap-servers.html