---
author: "Viki Pranata"
title: "Cluster OpenStack dengan Ceph Storage"
description : "Membuat cluster openstack dengan Kolla-Ansible serta mengintegrasikan dengan ceph storage untuk kebutuhan lab"
date: "2022-12-11"
tags: ["linux", "openstack", "ceph", "storage", "cloud"]
showToc: true
---
## Persiapan Lab
### Topologi
![image](/assets/images/ceph/openstack_ceph_topology.webp)

### Spesifikasi
> **Harware**

| Node Name | Ip Address | Processor | RAM | Root Disk |
| ---- | ---- | ---- | ---- | ---- |
| os-controller | 10.79.0.10 | 16 Core | 16 GB | (sda) 40 GB |
| os-compute01 | 10.79.0.11 | 24 Core | 24 GB | (sda) 40 GB |
| os-compute02 | 10.79.0.12 | 24 Core | 24 GB | (sda) 40 GB |

> **Storage**

| Nodee Name | Swift | Ceph OSD1 | Ceph OSD2 | Ceph OSD3 |
| --- | --- | --- | --- | --- |
| os-compute01 | (sdb) 10 GB | (sdc) 50 GB | (sdd) 50 GB | (sde) 50 GB |
| os-compute02 | (sdb) 10 GB | (sdc) 50 GB | (sdd) 50 GB | (sde) 50 GB |

> **Network**

| Virtual IP | Domain | Description |
| ---- | ---- | ---- |
| 10.79.0.254 | vpc.syslog.my.id | Internal API |

| Name | Network | Interface |
| ---- | ---- | ---- |
| Provider Network | 172.16.0.0/24 | ens18 |
| Internal Network | 10.79.0.0/24 | ens19 |
| Selfservice Network | 10.79.10.0/24 | vlan19 |
| Ceph Public | 10.10.0.0/24 | ens20 |
| Cepb Cluster | 10.20.0.0/24 | vlan20 |

### Mapping Hostname
> Eksekusi perintah pada os-controller, os-compute01, dan os-compute02
```bash
cat << EOF | sudo tee -a /etc/hosts
10.79.0.254 vpc.syslog.my.id
10.79.0.10  os-controller
10.79.0.11  os-compute01
10.79.0.12  os-compute02

10.10.0.10  ceph-public-mon
10.10.0.11  ceph-public-node01
10.10.0.12  ceph-public-node02

10.20.0.10  ceph-cluster-mon
10.20.0.11  ceph-cluster-node01
10.20.0.12  ceph-cluster-node02
EOF
```
Disable network update dacomputeri cloud init dan setting timezone
```bash
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo timedatectl set-timezone Asia/Jakarta
```
Konfigurasi netplan mengikuti [contoh ini](/assets/manifests/netplan-ceph-openstack.yaml)

## Deploy Ceph Quincy
### Memasang dependensi yang dibutuhkan oleh ceph
> Eksekusi perintah pada os-controller dengan Kolla virtual environment
```bash
sudo apt install -y gcc libffi-dev libssl-dev python3-dev python3-selinux python3-setuptools python3-pip python3-venv
python3 -m venv ceph
source ceph/bin/activate
```
![image](/assets/images/ceph/kolla_activate.webp)

Clone repositori ceph-ansible dan checkout versi stable-7.0 lalu install depndensi yang dibutuhkan
```bash
git clone https://github.com/ceph/ceph-ansible.git
cd ceph-ansible
git checkout stable-7.0
pip3 install -U pip
pip3 install -r requirements.txt
ansible-galaxy install -r requirements.yml
```
### Konfigurasi ceph-ansible
> copy sample file
```bash
cp site.yml.sample site.yml
cp group_vars/{all.yml.sample,all.yml}
cp group_vars/{mons.yml.sample,mons.yml}
cp group_vars/{osds.yml.sample,osds.yml}
```
edit file `group_vars/all.yml` dan sesuaikan beberapa parameter dibawah ini
```yaml
---
dummy:
ntp_daemon_type: chronyd
ceph_origin: repository
ceph_repository: community
ceph_stable_release: quincy
monitor_interface: ens20
monitor_address: 10.10.0.100
monitor_address_block: 10.10.0.0/24
public_network: 10.10.0.0/24
cluster_network: 10.20.0.0/24
osd_objectstore: bluestore
dashboard_enabled: false
---
```
Untuk memverifikasi gunakan perintah berikut :
```bash
cat group_vars/all.yml | grep -v "#" |  tr -s [:space:]
```
lalu edit file `group_vars/osds.yml` dan tambahkan daftar hardisk ke osd
```yaml
dummy:
devices:
  - /dev/sdc
  - /dev/sdd
  - /dev/sde
osd_auto_discovery: false
```
untuk memverifikasi gunakan perintah berikut :
```bash
cat group_vars/osds.yml | grep -v "#" | tr -s [:space:]
```
Menambahkan daftar node ke file invertory `hosts`
```bash
cat <<EOF | tee hosts
[mons]
ceph-public-mon

[mgrs]
ceph-public-mon

[osds]
ceph-public-node01
ceph-public-node02
EOF
```
Verifikasi koneksi ansible ke daftar file `hosts`
```bash
ansible -i hosts -m ping all
```
Deploy ceph dengan ansible-playbook
```bash
ansible-playbook -i hosts site.yml
```

### Membuat osd pool dan ceph auth
Menghitung PG (Placement Group) dengan bantuan [pgcalc](https://old.ceph.com/pgcalc/)
![image](/assets/images/ceph/pg-calc.webp)
Karena kita hanya memiliki 2 node compute dengan total 6 storage maka parameter pada gambar diatas diterapkan pada perintah berikut:
```bash
sudo ceph osd pool create backups 64
sudo ceph osd pool set backups size 2

sudo ceph osd pool create volumes 128
sudo ceph osd pool set volumes size 2

sudo ceph osd pool create images 64
sudo ceph osd pool set images size 2

sudo ceph osd pool create vms 32
sudo ceph osd pool set vms size 2
```
```bash
sudo rbd pool init backups
sudo rbd pool init volumes
sudo rbd pool init images
sudo rbd pool init vms
```

Lalu buat authentikasi untuk cinder, cinder, glance, dan nova pada masing-masing pool yang sudah dibuat
```bash
sudo ceph auth get-or-create client.cinder \
mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=backups, allow rwx pool=images' \
-o /etc/ceph/ceph.client.cinder.keyring

sudo ceph auth get-or-create client.glance \
mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' \
-o /etc/ceph/ceph.client.glance.keyring

sudo ceph auth get-or-create client.nova \
mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=vms, allow rx pool=images' \
-o /etc/ceph/ceph.client.nova.keyring
```

Untuk melihat data authentikasi yang sudah dibuat gunakan perintah `sudo ceph auth list` atau seperti gambar dibawah ini:
![image](/assets/images/ceph/ceph_auth.webp)

Tambahkan konfigurasi berikut pada file `ceph.conf`
```bash
cat <<EOF | sudo tee -a /etc/ceph/ceph.conf
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
EOF
```

Buat direktori yang diperlukan dan distribusikan file `ceph.conf` serta `ceph keyring` pada semua node dengan hasil akhir seperti berikut :
```txt
tree /etc/kolla/config
├── cinder
│   ├── ceph.conf
│   ├── cinder-backup
│   │   └── ceph.client.cinder.keyring
│   └── cinder-volume
│       └── ceph.client.cinder.keyring
├── glance
│   ├── ceph.client.glance.keyring
│   └── ceph.conf
└── nova
    ├── ceph.client.cinder.keyring
    ├── ceph.client.nova.keyring
    └── ceph.conf
```

Jalankan dengan perintah berikut :
```bash
for i in {10..12}; do
ssh 10.79.0.$i sudo mkdir -p /etc/kolla/config/cinder/cinder-backup
ssh 10.79.0.$i sudo mkdir -p /etc/kolla/config/cinder/cinder-volume
ssh 10.79.0.$i sudo mkdir -p /etc/kolla/config/glance
ssh 10.79.0.$i sudo mkdir -p /etc/kolla/config/nova

cat /etc/ceph/ceph.conf | ssh 10.79.0.$i sudo tee /etc/kolla/config/cinder/ceph.conf
cat /etc/ceph/ceph.conf | ssh 10.79.0.$i sudo tee /etc/kolla/config/glance/ceph.conf
cat /etc/ceph/ceph.conf | ssh 10.79.0.$i sudo tee /etc/kolla/config/nova/ceph.conf

sudo ceph auth get-or-create client.cinder | ssh 10.79.0.$i sudo tee /etc/kolla/config/cinder/cinder-backup/ceph.client.cinder.keyring
sudo ceph auth get-or-create client.cinder | ssh 10.79.0.$i sudo tee /etc/kolla/config/cinder/cinder-volume/ceph.client.cinder.keyring
sudo ceph auth get-or-create client.glance | ssh 10.79.0.$i sudo tee /etc/kolla/config/glance/ceph.client.glance.keyring
sudo ceph auth get-or-create client.cinder | ssh 10.79.0.$i sudo tee /etc/kolla/config/nova/ceph.client.cinder.keyring
sudo ceph auth get-or-create client.nova | ssh 10.79.0.$i sudo tee /etc/kolla/config/nova/ceph.client.nova.keyring
done
```

### Memverifikasi layanan ceph
- Cek status ceph dengan peringah `sudo ceph -s`
- Cek config osd ceph dengan perintah `sudo ceph config dump`
- Cek disk usage osd ceph dengan perintah `sudo ceph osd df`
- Cek detail pool osd degan perintah `sudo ceph osd pool ls detail`
- Cek daftar authentikaai pool osd dengan perintah `sudo ceph auth ls`  

![image](/assets/images/ceph/ceph_finish.webp)
[Click for detail](/assets/images/ceph/ceph_finish.webp)

Nonaktifkan ceph virtual environment dengan perintah `deactivate`
![image](/assets/images/ceph/ceph_deactivate.webp)

## Deploy Openstack Yoga
### Memasang dependensi yang dibutuhkan oleh kolla-ansible
Membuat dan mengaktifkan virtual environment kolla
```bash
python3 -m venv kolla
source ~/kolla/bin/activate
```
![image](/assets/images/ceph/kolla_activate.webp)

Update pip dan install dependensi kolla-ansible
```bash
pip install -U pip
pip install 'ansible>=4,<6'
pip install kolla-ansible
kolla-ansible install-deps
```

Membuat ansible config
```bash
cat <<EOF | tee ansible.cfg
[defaults]
host_key_checking=False
pipelining=True
forks=100
log_path=$HOME/ansible.log
EOF
```

### Konfigurasi kolla-ansible
Buat direktori yang dibutuhkan kolla-ansible
```bash
sudo mkdir /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla/share/kolla-ansible/etc_examples/kolla/passwords.yml /etc/kolla
cp -r ~/kolla/share/kolla-ansible/etc_examples/kolla/globals.yml /etc/kolla
cp -r ~/kolla/share/kolla-ansible/ansible/inventory/* ~/
```

Edit file /etc/kolla/globals.yaml dan sesuaikan beberapa parameter dibawah ini
```yaml
---
kolla_base_distro: "ubuntu"
kolla_install_type: "source"
openstack_release: "yoga"
kolla_internal_vip_address: "10.79.0.254"
kolla_internal_fqdn: "vpc.syslog.my.id"
network_interface: "ens19"
tunnel_interface: "vlan10"
neutron_external_interface: "ens18"
neutron_plugin_agent: "ovn"
enable_openstack_core: "yes"
enable_cinder: "yes"
enable_cinder_backup: "yes"
enable_fluentd: "no"
enable_neutron_provider_networks: "yes"
enable_swift: "yes"
enable_swift_s3api: "yes"
ceph_glance_keyring: "ceph.client.glance.keyring"
ceph_glance_user: "glance"
ceph_glance_pool_name: "images"
ceph_cinder_keyring: "ceph.client.cinder.keyring"
ceph_cinder_user: "cinder"
ceph_cinder_pool_name: "volumes"
ceph_cinder_backup_keyring: "ceph.client.cinder.keyring"
ceph_cinder_backup_user: "cinder"
ceph_cinder_backup_pool_name: "backups"
ceph_nova_keyring: "ceph.client.nova.keyring"
ceph_nova_user: "nova"
ceph_nova_pool_name: "vms"
glance_backend_ceph: "yes"
glance_backend_swift: "no"
cinder_backend_ceph: "yes"
nova_backend_ceph: "yes"
neutron_ovn_distributed_fip: "yes"
swift_devices_name: "KOLLA_SWIFT_DATA"
```
Untuk memverifikasi gunakan perintah berikut :
```bash
cat /etc/kolla/globals.yml | grep -v "#" |  tr -s [:space:]
```
Generate password untuk setiap service di openstack
```bash
kolla-genpwd
nano /etc/kolla/passwords.yml
```
> untuk menubah password admin edit value dari key `keystone_admin_password`

Sesuaikan isi file ~/multinode untuk ansible inventory seperti berikut
```yaml
# These initial groups are the only groups required to be modified. The
# additional groups are for more control of the environment.
[control]
os-controller      ansible_connection=local

[network]
os-controller      ansible_connection=local

[compute]
os-compute01
os-compute02

[monitoring]
os-controller      ansible_connection=local

[storage]
os-compute01
os-compute02

[deployment]
localhost        ansible_connection=local
## Apart from this, there are no changes below!
```
### Setup swift object storage
Ikuti langkah persiapan untuk membuat openstack swift pada tautan [ini](/posts/openstack-kolla-swift/#persiapan) 

> Deploy openstack yoga
```bash
ansible -i ~/multinode all -m ping
    # if no error detect, next step
kolla-ansible -i ~/multinode bootstrap-servers
    # if no error detect, next step
kolla-ansible -i ~/multinode prechecks
    # if no error detect, next step
kolla-ansible -i ~/multinode deploy
    # if no error detect, next step
kolla-ansible -i ~/multinode post-deploy
cp -r /etc/kolla/admin-openrc.sh ~/
```

### Memverifikasi layanan openstack
Nonaktifkan kolla virtual environment dengan perintah `deactivate`
![image](/assets/images/ceph/kolla_deactivate.webp)
```bash
sudo apt install -y python3-openstackclient python3-swiftclient
source ~/admin-openrc.sh
```

Verifikasi dengan perintah berikut :
![image](/assets/images/ceph/openstack_ceph_service.webp)
[Click for detail](/assets/images/ceph/openstack_ceph_service.webp)

# Destroy Cluster
> Ceph
```bash
ansible-playbook -i hosts infrastructure-playbooks/purge-cluster.yml
```
> OpenStack
```bash
kolla-ansible -i ./multinode destroy --yes-i-really-really-mean-it
```

# Referensi
- https://old.ceph.com/pgcalc/
- https://github.com/ceph/ceph-ansible
- https://docs.ceph.com/projects/ceph-ansible/en/stable-7.0
- https://medium.com/opsops/how-to-remove-a-pool-in-ceph-without-resarting-mons-820cd5f5841
- https://www.suse.com/support/kb/doc/?id=000019960
- https://ceph.io/en/news/blog/2015/ceph-loves-jumbo-frames 