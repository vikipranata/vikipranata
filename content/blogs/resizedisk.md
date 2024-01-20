---
author: "Viki Pranata"
title: "Memperbesar Kapasitas Partisi di Linux"
description : "Cara Memperbesar Kapasitas Partisi di Linux"
date: "2022-10-09"
tags: ["linux", "tools", "storage"]
categories: ["archives"]
---

Masalah utama dalam penggunaan data adalah kapasitas, dalam linux ada beberapa perintah yang memudahkan kita untuk menaikan kapasitas penyimpanan.

Setelah menaikan kapasitas penyimpanan dari sisi host mesin virtual server, tinggal kita update dari sisi host yang akan di tingkatkan dengan bantuan tools berikut :

> growpart - extend a partition in a partition table to fill available space <cite>[^1]</cite>
[^1]: Dikutip dari laman [ubuntu manual pages](https://manpages.ubuntu.com/manpages/bionic/man1/growpart.1.html)


### Partisi Tanpa LVM
Meningkatkan kapasitas partisi _root_ dengan perintah    
```
growpart /dev/xxx 1
```

Lalu gunakan perintah berikut untuk mengisi semua ruang partisi _root_    
```
resize2fs /dev/xxx1
```

### Partisi dengan LVM
Meningkatkan kapasitas partisi lvm dengan perintah    
```
pvresize /dev/xxx1
```

Lalu gunakan perintah berikut untuk mengisi semua ruang partisi lvm yang tersedia    
```
lvresize --extents +100%FREE --resizefs /dev/xxx/root
```

Jika ingin menggunakan hanya 20GB saja bisa menggunakan perintah berikut    
```
lvresize --size +20G --resizefs /dev/xxx/root
```    

### Verifikasi
Lalu verifikasi penyimpanan apakah sudah sesuai atau belum    
```
df -H
```

### Catatan tambahan 
jika menemukan kondisi dimana _no space left on the block device_, bisa menggunakan perintah berikut:    
```
mount -o size=10M,rw,nodev,nosuid -t tmpfs tmpfs /tmp
```

Pada beberapa kondisi disk yang sudah di naikan kapasitasnya pada level virtualization host tidak terbaca pada VM Guest, maka bisa melakukan perintah berikut

```
## List semua hardisk yang terpasang
ls /sys/class/scsi_device/

## Lalu scan semua disk dengan berintah ini
echo 1 > /sys/class/scsi_device/<SCSI_ID>/device/rescan

## Contoh
echo 1 > /sys/class/scsi_device/0\:0\:0\:0/device/rescan
```

### Memformat disk
```bash
wipefs -af /dev/xxx
```


#### Referensi
- https://www.redhat.com/sysadmin/resize-lvm-simple
- https://communities.vmware.com/t5/vSphere-Hypervisor-Discussions/Expand-Space-without-Rebooting-VM/td-p/923809