---
author: "Viki Pranata"
title: "Metal as a Services (MaaS) for Lab"
description : "Membuat MaaS untuk provisioner kebutuhan lab"
date: "2022-12-08"
tags: ["linux", "MaaS", "cloud"]
showToc: true
---

MAAS atau Metal as a Service adalah layanan yang memperlakukan server fisik seperti mesin virtual (instance) di cloud. 

## Persiapan
| Node Name | Processor | RAM | Volumes | Network | Interface |
| ---- | ---- | ---- | ---- | ---- | ---- |
| maas-provisioner | 4 Core | 4 GB | 20 GB | 10.79.0.100/24 | ens18 |
| | | | | 172.16.0.100/24 | ens19 |

### Pemasangan paket yang dibutuhkan
```bash
sudo apt-add-repository ppa:maas/3.2

sudo apt-get install -y maas maas-region-controller maas-rack-controller jq
```

### Membuat user maas dan ssh keypair untuk maas commisioning
```bash
sudo maas createadmin
```
Output :
>Username: admin   
Password: _[input password]_    
Again: _[input password again]_   
Email: _[input your email]_   
Import SSH keys [] (lp:user-id or gh:user-id): _[launchpad or github User ID]_   


```bash
sudo chsh -s /bin/bash maas
```

Lalu masuk ke user maas dan buat ssh keypair
```
sudo su - maas
ssh-keygen -t rsa -c -N ""
cat .ssh/id_rsa.pub
```
> Salin ssh public key dari file id_rsa.pub untuk kita upload pada user admin

### MAAS Dashboard
Akses url [http://10.79.0.100:5240/MAAS/](http://10.79.0.100:5240/MAAS/r/intro) dan ikuti langkah-langkah dibawah ini
![image](/assets/images/maas/maas-setup1.webp)
![image](/assets/images/maas/maas-setup2.webp)
![image](/assets/images/maas/maas-setup3.webp)
![image](/assets/images/maas/maas-finish-setup.webp)

Import ssh public key yang kita buat di user maas
![image](/assets/images/maas/maas-user-setup.webp)

Kita bisa menambahkan ssh public key di user admin dengan cara ini :   
![image](/assets/images/maas/maas-user-setup-ssh.webp)

## MAAS networking setup
Akses url [http://10.79.0.100:5340/MAAS/r/networks](http://10.79.0.100:5240/MAAS/r/networks)   

**Skema konfigurasi**
| Interface | Network | DHCP Servers | Fabric | Space |
| ---- | ---- | ---- | ---- | ---- | ---- |
| ens18 | 10.79.0.0/24 | external | fabric-0 | internal |
| ens19 | 172.16.0.0/24 | internal | fabric-1 | external |

### Membuat Space
buka dashborad lalu ikuti arahan ini:
- Subnets -> Add -> Space -> Name (internal)
- Subnets -> Add -> Space -> Name (external)

### Menambahkan Space pada VLAN
- Subnets -> klik vlan (untagged) -> edit -> space (pilih space)
![image](/assets/images/maas/maas-network-dhcp-setup1.webp)

### Mengalokasikan ip statis dan dinamis
- Subnets -> klik vlan (untagged) -> Reserve Range    
![image](/assets/images/maas/maas-network-dhcp-setup2.webp)

### Membuat dhcp relay fabric-0
Tambahkan beberapa konfigurasi pada external dhcp server dengan parameter berikut:
- dhcp option code `67`
- dhcp next server `10.79.0.100`
- dhcp boot file `http://10.79.0.100:5248/ipxe.cfg`

### Membuat dhcp server fabric-1
- klik vlan (untagged) -> configure DHCP    
![image](/assets/images/maas/maas-network-dhcp-setup3.webp)

**Summary**
![image](/assets/images/maas/maas-network-setup1.webp)

### Menambahkan Mesin
MAAS bisa digunakan untuk mendeploy mesin bare metal maupun mesin virtual seperti yang terlihat pada opsi _Power type_ dibawah ini:
![image](/assets/images/maas/maas-add-machine.webp)

untuk selanjutnya sesuaikan dengan environment lab.

## Referensi
- https://maas.io/docs/how-to-install-ma
- https://maas.io/tutorials/create-kvm-pods-with-maas
- https://www.experts-exchange.com/articles/2978/PXEClient-dhcp-options-60-66-and-67-what-are-they-for-Can-I-use-PXE-without-it.html
- https://supportportal.juniper.net/s/article/DHCP-option-150-and-DHCP-option-66?language=en_US
- https://jhodysekardono.notion.site/Install-OpenStack-Yoga-With-Juju-MAAS-cd8f05bacf8043f5a82a39c05f852d0b