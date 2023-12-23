---
author: "Viki Pranata"
title: "Cluster High Availability Kubernetes Part 1"
description : "Membuat cluster HA Kubernetes dengan Kubeadm untuk kebutuhan lab, development, staging maupun production"
date: "2022-11-15"
tags: ["linux", "Kubernetes", "loadbalancer"]
showToc: true
---

# Lab Environment
Membuat instance yang akan dibuat pada [cluster openstack](/posts/openstack-for-lab) yang telah kita bangun sebelumnya dengan spesifikasi berikut :

> Hardware Spec

| Node Name | Processor | RAM | Volumes |Description |
| ---- | ---- | ---- | ---- | ---- |
| k8s-lb-ingress |  1 Core | 1 GB | 10 GB | Ext Load Balancer Node |
| k8s-master01 | 2 Core | 2 GB | 20 GB | Control Plane Node |
| k8s-master02 | 2 Core | 2 GB | 20 GB | Control Plane Node |
| k8s-master03 | 2 Core | 2 GB | 20 GB | Control Plane Node |
| k8s-worker01 | 2 Core | 2 GB | 20 GB | Worker Node |
| k8s-worker02 | 2 Core | 2 GB | 20 GB | Worker Node |
| k8s-worker02 | 2 Core | 2 GB | 20 GB | Worker Node |

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

## Membuat Port Instance
```bash
for i in {1..3}; do openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.1$i k8s-master0$i; done
for i in {1..3}; do openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.2$i k8s-worker0$i; done
openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.100 k8s-lb-ingress
```

## Mengalokasikan Virtual IP
```bash
openstack port create --network int-net01 --fixed-ip subnet=int-subnet01,ip-address=192.168.0.10 k8s-apiserver
for i in {1..3}; do openstack port set --allowed-address ip-address=192.168.0.10 k8s-master0$i; done
```

### Validasi Port
```bash
openstack port list
+--------------------------------------+----------------+-------------------+------------------------------------------------------------------------------+--------+
| ID                                   | Name           | MAC Address       | Fixed IP Addresses                                                           | Status |
+--------------------------------------+----------------+-------------------+------------------------------------------------------------------------------+--------+
| dba325cc-e21c-4bcb-8e79-e6e4a87537c0 | k8s-apiserver  | fa:16:3e:bb:bc:b5 | ip_address='192.168.0.10', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| 0a0030bb-48d1-4d17-83b0-fec22d12b765 | k8s-master01   | fa:16:3e:58:73:bc | ip_address='192.168.0.11', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| 02cff3ca-55e8-490a-b36d-67297d8a200c | k8s-master02   | fa:16:3e:cb:dd:e6 | ip_address='192.168.0.12', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| e0083309-1c28-4f99-ad09-e121c0f75e17 | k8s-master03   | fa:16:3e:fb:33:d8 | ip_address='192.168.0.13', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| 854a3e63-997e-4efd-b6a0-2038a530cde0 | k8s-worker01   | fa:16:3e:c7:32:20 | ip_address='192.168.0.21', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| bd64c6b4-7686-4782-bfc8-68c2b3ac6f2e | k8s-worker02   | fa:16:3e:6b:df:ab | ip_address='192.168.0.22', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| 56b39ed9-4ba5-4093-9f41-ec8ef35b6296 | k8s-worker03   | fa:16:3e:bd:fe:53 | ip_address='192.168.0.23', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e'  | DOWN   |
| ad269256-5f6b-4da8-8c1c-03fd45900b30 | k8s-lb-ingress | fa:16:3e:ea:5b:e6 | ip_address='192.168.0.100', subnet_id='e099dcba-fa06-45f0-a3e2-37e05ff8dd4e' | DOWN   |
+--------------------------------------+----------------+-------------------+------------------------------------------------------------------------------+--------+
```
```bash
for i in {1..3}; do echo k8s-master0$i; openstack port show k8s-master0$i | grep allowed_address_pairs; done

k8s-master01
| allowed_address_pairs   | ip_address='192.168.0.10', mac_address='fa:16:3e:58:73:bc'
k8s-master02
| allowed_address_pairs   | ip_address='192.168.0.10', mac_address='fa:16:3e:cb:dd:e6'
k8s-master03
| allowed_address_pairs   | ip_address='192.168.0.10', mac_address='fa:16:3e:fb:33:d8'
```

## Membuat Persistent Volume Instance
```bash
for i in {1..3}; do openstack volume create --size 20 --image ubuntu-focal-20.04 k8s-master0$i; done
for i in {1..3}; do openstack volume create --size 20 --image ubuntu-focal-20.04 k8s-worker0$i; done
openstack volume create --size 10 --image ubuntu-focal-20.04 k8s-lb-ingress
watch openstack volume list --long
```
```bash
openstack volume list
+--------------------------------------+----------------+-----------+------+-------------+
| ID                                   | Name           | Status    | Size | Attached to |
+--------------------------------------+----------------+-----------+------+-------------+
| cdbbc700-d9ae-4a0e-9522-c1904e7863c2 | k8s-worker01   | available |   20 |             |
| 172628db-f139-44ef-9e72-dfe511607608 | k8s-worker02   | available |   20 |             |
| 309f3e53-f76d-4ab2-9104-248847f8266f | k8s-worker03   | available |   20 |             |
| 5f7f395d-e53a-4603-9de9-cf20b27036a7 | k8s-master01   | available |   20 |             |
| f748b31a-e09f-4514-a9cd-7ced49f80f21 | k8s-master02   | available |   20 |             |
| 9299bd6c-1ee2-44c5-8ba8-c6e7310b3540 | k8s-master03   | available |   20 |             |
| 543d9739-5a14-4e6c-b689-ea899be21536 | k8s-lb-ingress | available |   10 |             |
+--------------------------------------+----------------+-----------+------+-------------+
```

## Membuat Security Group
```bash
openstack security group create secg-kubernetes --description 'Kubernetes environment'
openstack security group rule create --protocol icmp secg-kubernetes
for i in {22,80,443,6443}; do openstack security group rule create --protocol tcp --ingress --dst-port $i secg-kubernetes; done
```

## Membuat Flavor
```bash
openstack flavor create --vcpus 2 --ram 2048 --disk 15 --public c2-standard-01
```

## Membuat Instance
```bash
for i in {1..3}; do openstack server create --flavor c2-standard-01 \
  --key-name controllerkey \
  --security-group secg-kubernetes \
  --volume k8s-master0$i \
  --port k8s-master0$i --wait \
  k8s-master0$i; sleep 60s; done

for i in {1..3}; do openstack server create --flavor c2-standard-01 \
  --key-name controllerkey \
  --security-group secg-kubernetes \
  --volume k8s-worker0$i \
  --port k8s-worker0$i --wait \
  k8s-worker0$i; sleep 60s; done

openstack server create --flavor c1-standard-01 \
  --key-name controllerkey \
  --security-group secg-kubernetes \
  --volume k8s-lb-ingress \
  --port k8s-lb-ingress --wait \
  k8s-lb-ingress
```
```bash
openstack server list
+--------------------------------------+--------------+--------+------------------------+-------+----------------+
| ID                                   | Name         | Status | Networks               | Image | Flavor         |
+--------------------------------------+--------------+--------+------------------------+-------+----------------+
| 07cd4701-b365-4f6f-a4e5-eb0feb0f2021 | k8s-worker03 | ACTIVE | int-net01=192.168.0.23 |       | c2-standard-01 |
| 3a92b4cc-c149-449b-a9a1-1aa4b578fc37 | k8s-worker02 | ACTIVE | int-net01=192.168.0.22 |       | c2-standard-01 |
| c322b7e6-bb05-4f11-ab13-38db5a5ca11c | k8s-worker01 | ACTIVE | int-net01=192.168.0.21 |       | c2-standard-01 |
| f0acc658-dca1-4010-9794-893adcfb7549 | k8s-master03 | ACTIVE | int-net01=192.168.0.13 |       | c2-standard-01 |
| 04b5f74f-7148-4030-81a1-ea0b8dd80e22 | k8s-master02 | ACTIVE | int-net01=192.168.0.12 |       | c2-standard-01 |
| dc23ff03-e092-4e56-8a91-146e67bd28af | k8s-master01 | ACTIVE | int-net01=192.168.0.11 |       | c2-standard-01 |
+--------------------------------------+--------------+--------+------------------------+-------+----------------+
```

## Membuat Floating IP
```bash
for i in {1..3}; do openstack floating ip create --floating-ip-address 172.16.0.2$i ext-net01; done
openstack floating ip create --floating-ip-address 172.16.0.100 ext-net01
```
```bash
openstack floating ip list
+--------------------------------------+---------------------+------------------+--------------------------------------+--------------------------------------+----------------------------------+
| ID                                   | Floating IP Address | Fixed IP Address | Port                                 | Floating Network                     | Project                          |
+--------------------------------------+---------------------+------------------+--------------------------------------+--------------------------------------+----------------------------------+
| 2d7cafca-4f64-45c0-b2e3-ff98133e9211 | 172.16.0.21         | 192.168.0.21     | 2a346f6b-c037-4e1b-8a0c-900ba6b90f0a | 1d6db61c-2736-423e-b05d-01f380fb2daa | 75ee0b5ff3f14e35909d6ee880732a19 |
| 5004efff-99de-4ce4-8f0e-2ae9ae632f03 | 172.16.0.100        | 192.168.0.100    | 961b2295-e820-40e3-ba5d-9465707e5409 | 1d6db61c-2736-423e-b05d-01f380fb2daa | 75ee0b5ff3f14e35909d6ee880732a19 |
| 761e5d74-6c2c-411a-90a5-987246ca4d92 | 172.16.0.22         | 192.168.0.22     | 015ed9d0-3da3-413d-90e4-8489d6b46b22 | 1d6db61c-2736-423e-b05d-01f380fb2daa | 75ee0b5ff3f14e35909d6ee880732a19 |
| ccb009d7-1221-4244-8e00-4b9fd0fb5477 | 172.16.0.23         | 192.168.0.23     | bbad00e2-d750-4464-9e79-426aa3b1da2d | 1d6db61c-2736-423e-b05d-01f380fb2daa | 75ee0b5ff3f14e35909d6ee880732a19 |
+--------------------------------------+---------------------+------------------+--------------------------------------+--------------------------------------+----------------------------------+
```
### Memasang Floating IP Pada Worker Node
```bash
for i in {1..3}; do openstack server add floating ip k8s-worker0$i 172.16.0.2$i; done
openstack server add floating ip k8s-lb-ingress 172.16.0.100
```
```bash
openstack server list -c Name -c Networks
+----------------+---------------------------------------+
| Name           | Networks                              |
+----------------+---------------------------------------+
| k8s-worker03   | int-net01=192.168.0.23, 172.16.0.23   |
| k8s-worker02   | int-net01=192.168.0.22, 172.16.0.22   |
| k8s-worker01   | int-net01=192.168.0.21, 172.16.0.21   |
| k8s-master03   | int-net01=192.168.0.13                |
| k8s-master02   | int-net01=192.168.0.12                |
| k8s-master01   | int-net01=192.168.0.11                |
| k8s-lb-ingress | int-net01=192.168.0.100, 172.16.0.100 |
+----------------+---------------------------------------+
```
Tahap selanjutnya dalam membangun [Kubernetes Cluster High Availability](/posts/kubernetes-ha-part2).