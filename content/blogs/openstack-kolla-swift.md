---
author: "Viki Pranata"
title: "OpenStack Swift via Kolla Ansible"
description : "Menambahkan layanan swift object storage pada openstack kolla ansible"
date: "2022-12-07"
tags: ["linux", "openstack", "storage", "cloud"]
showToc: true
---

Menambahkan layanan swift object storage pada openstack yang dideploy dengan kolla ansible pada postingan [openstack for lab](/posts/openstack-for-lab)

## Persiapan
openstack swift membutuhkan block storage untuk media penyimpanan.Tambahkan 1 hardisk pada tiap node untuk di khususkan sebagai storage swift.
| Node Name | Ip Address | Swift Volume | Disk |
| ---- | ---- | ---- | ---- |
| openstack-controller | 10.79.0.10 | 10GB | /dev/sdb |
| openstack-compute01 | 10.79.0.11 | 10GB | /dev/sdb |
| openstack-compute02 | 10.79.0.12 | 10GB | /dev/sdb |


> jalankan pada semua node
```bash
# <WARNING ALL DATA ON DISK will be LOST!>
index=0
for disk in sdb; do
    sudo parted /dev/${disk} -s -- mklabel gpt mkpart KOLLA_SWIFT_DATA 1 -1
    sudo mkfs.xfs -f -L d${index} /dev/${disk}1
    (( index++ ))
done
```

Verifikasi block storage yang sudah di format
```bash
lsblk -f
```

Sebelum menjalankan layanan openstack swift, kita perlu membuat _Object Ring, Account ring, dan Container Ring_ yang berfungsi untuk memberi tahu berbagai layanan Swift di mana data berada di kluster.
```bash
nano ~/swift-rings.sh
#!/usr/bin/bash
STORAGE_NODES=(10.79.0.10 10.79.0.11 10.79.0.12)
KOLLA_SWIFT_BASE_IMAGE="kolla/centos-source-swift-base:4.0.0"

mkdir -p /etc/kolla/config/swift

# Object ring
docker run \
  --rm \
  -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
  $KOLLA_SWIFT_BASE_IMAGE \
  swift-ring-builder \
    /etc/kolla/config/swift/object.builder create 10 3 1

for node in ${STORAGE_NODES[@]}; do
    for i in {0..2}; do
      docker run \
        --rm \
        -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
        $KOLLA_SWIFT_BASE_IMAGE \
        swift-ring-builder \
          /etc/kolla/config/swift/object.builder add r1z1-${node}:6000/d${i} 1;
    done
done

# Account ring
docker run \
  --rm \
  -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
  $KOLLA_SWIFT_BASE_IMAGE \
  swift-ring-builder \
    /etc/kolla/config/swift/account.builder create 10 3 1

for node in ${STORAGE_NODES[@]}; do
    for i in {0..2}; do
      docker run \
        --rm \
        -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
        $KOLLA_SWIFT_BASE_IMAGE \
        swift-ring-builder \
          /etc/kolla/config/swift/account.builder add r1z1-${node}:6001/d${i} 1;
    done
done

# Container ring
docker run \
  --rm \
  -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
  $KOLLA_SWIFT_BASE_IMAGE \
  swift-ring-builder \
    /etc/kolla/config/swift/container.builder create 10 3 1

for node in ${STORAGE_NODES[@]}; do
    for i in {0..2}; do
      docker run \
        --rm \
        -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
        $KOLLA_SWIFT_BASE_IMAGE \
        swift-ring-builder \
          /etc/kolla/config/swift/container.builder add r1z1-${node}:6002/d${i} 1;
    done
done

for ring in object account container; do
  docker run \
    --rm \
    -v /etc/kolla/config/swift/:/etc/kolla/config/swift/ \
    $KOLLA_SWIFT_BASE_IMAGE \
    swift-ring-builder \
      /etc/kolla/config/swift/${ring}.builder rebalance;
done
```

tambahkan permission exec pada file ~/swift-rings.sh dan jalankan dengan user sudo
```bash
chown +x ~/swift-rings.sh
sudo ~/swift-rings.sh
```

## Deploy openstack Swift
Aktivasi kolla python virtual environment
```bash
source ~/kolla/bin/activate
```

Lalu edit konfigurasi `nano /etc/kolla/globals.yml`
```bash
enable_swift: "yes"
enable_swift_s3api: "yes"
glance_backend_file: "yes"
glance_backend_swift: "no"
swift_devices_name: "KOLLA_SWIFT_DATA"
```

Selanjutnya deploy layanan swift dengan perintah:
```bash
kolla-ansible -i ~/multinode deploy
```

Setelah selesai semua `deactivate` kolla python virtual environment lalu install swift cli client
```bash
sudo apt instll -y python3-swiftclient
```

Verifikasi hasil pemasangan layanan openstack swift
> Membuat bucket

```bash
openstack container create swiftbucket
+---------------------------------------+-------------+------------------------------------+
| account                               | container   | x-trans-id                         |
+---------------------------------------+-------------+------------------------------------+
| AUTH_0f7a4e704061426881f33429923f99a9 | swiftbucket | txb4b14cf2042646d5b9e1a-0063953f60 |
+---------------------------------------+-------------+------------------------------------+
```

> Mengupload file object ke bucket

```bash
openstack object create swiftbucket ansible.log 
+-------------+-------------+----------------------------------+
| object      | container   | etag                             |
+-------------+-------------+----------------------------------+
| ansible.log | swiftbucket | a462184e9f31307bee7d91a48ad46d54 |
+-------------+-------------+----------------------------------+
```

> Mendeskripsikan bucket

```bash
openstack container show swiftbucket          
+----------------+---------------------------------------+
| Field          | Value                                 |
+----------------+---------------------------------------+
| account        | AUTH_0f7a4e704061426881f33429923f99a9 |
| bytes_used     | 1012373                               |
| container      | swiftbucket                           |
| object_count   | 1                                     |
| storage_policy | Policy-0                              |
+----------------+---------------------------------------+
```

## Sumber Referensi
- https://docs.openstack.org/kolla-ansible/yoga/reference/storage/swift-guide.html
- https://docs.openstack.org/swift/latest/development_saio.html