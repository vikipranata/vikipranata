---
title: "Operating OpenStack via CLI"
date: 2025-03-17 00:00:00 +0700
modified: 2025-03-17 00:00:00 +0700
tags: [linux, openstack, cloud]
description: "Operating OpenStack via the command line, which can be used for preparing COA (Certified OpenStack Administrator)"
---
After we finish building the openstack cluster with kolla ansible in the [previous post](../openstack-kolla-ansible-2024.2), to operate OpenStack with CLI there are several steps as follows:

## Accessing the Cluster
### Using the OpenStack RC File
The RC file contains a collection of variables used to access OpenStack with specific users or projects.
```bash
source ~/admin-openrc.sh
```

## Creating a Project
```bash
openstack project create --enable --description "project for kubernetes" kubernetes
openstack project list --long --fit-width
```

## Creating a User 
```bash
openstack user create --project admin --email viki@syslog.my.id --password p@ssw0rd viki
openstack user create --project kubernetes --email k8s@syslog.my.id --password-prompt k8s
openstack user set viki --project kubernetes
```
Verification
```bash
for i in {viki,k8s}; do
    openstack user show $i;
done
```

## Project Role
```bash
openstack role add --user viki --project admin admin
openstack role add --user viki --project kubernetes member
openstack role add --user k8s --project kubernetes admin
```
Verification
```bash
for i in {viki,k8s}; do
    openstack role assignment list --user $i --names;
done
```

## Creating a Project Quota
```bash
openstack quota set --core 24 --ram 20480 --instances 10 --volumes 10 --floating-ips 6 --secgroups 2 kubernetes
```

## Creating Images
Download the cloud image file first:
```bash
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
curl -LO https://download.cirros-cloud.net/0.6.1/cirros-0.6.1-x86_64-disk.img
```

Then import the downloaded image into OpenStack using the following command:
```bash
openstack image create --public --disk-format qcow2 --file cirros-0.6.1-x86_64-disk.img cirros-test
openstack image create --public --disk-format qcow2 --file focal-server-cloudimg-amd64.img ubuntu20-focal
openstack image list
```

## Creating a Flavor
A flavor defines the specifications of an instance. For example, creating a flavor with 1 VCPU, 1GB RAM, and 10GB Disk can be done with the following command:
```bash
openstack flavor create --project kubernetes --private --vcpu 2 --ram 2048 --disk 2 n1-kubemaster
openstack flavor create --project kubernetes --private --vcpu 4 --ram 4096 --disk 4 n2-kubeworker
openstack flavor list --all
```

## Creating an SSH Keypair
A keypair in this context refers to an SSH keypair that we usually create with the `ssh-keygen` command, which generates a public key and private key file. This helps cloud-init to insert the public key into the instance. To create a keypair, use the following command:
```bash
openstack keypair create --public-key ~/.ssh/id_rsa.pub controller-key
openstack keypair create --public-key ~/.ssh/k8s.pub k8s-key
```

## Creating a Security Group
A security group acts as a firewall at the instance level. For example, we can set up incoming ingress connections on SSH (TCP port 22), web services (TCP ports 80, 443), and ICMP protocol with the following commands:

Creating _kubesecgroup_ security group
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

Creating _app-secgroup_ security group
```bash
openstack security group create app-secgroup
openstack security group rule create --ingress --protocol tcp --dst-port 30080 --description http-ingress
openstack security group rule create --ingress --protocol tcp --dst-port 30443 --description https-ingress
```

## Creating an External Network
An external network is used for communication out of the instance via an external provider. To create one, we need to know the provider physical network first with the following command:
```bash
sudo cat /etc/kolla/neutron-server/ml2_conf.ini | grep flat_network | awk '{print $3}'
```
Then, define the network and subnet with these commands:
```bash
openstack network create --project admin --external --provider-network-type flat --provider-physical-network physnet1 ext-net
openstack subnet create --network ext-net \
--subnet-range 172.16.1.0/24 --gateway 172.16.1.1 --dns-nameserver 172.16.1.1 \
--allocation-pool start=172.16.1.242,end=172.16.1.254 --no-dhcp ext-subnet

openstack network list --long --fit-width
openstack subnet list --long --fit-width
```

## Creating an Internal Network
An internal network is used for communication between instances over an internal network. To create one, define the network and subnet with the following commands:
```bash
openstack network create --internal kubenet
openstack subnet create --network kubenet --subnet-range 10.1.0.0/24 --gateway 10.1.0.1 kubesubnet
openstack network list --long --fit-width
openstack subnet list --long --fit-width
```

## Creating a router
In OpenStack, a router is used to connect internal traffic to external traffic, whether it's incoming (ingress) or outgoing (egress). To create a router, use the following commands:
```bash
openstack router create kuberouter
openstack router set --external-gateway ext-net kuberouter
openstack router add subnet kuberouter kubesubnet
openstack router show kuberouter
```

## Creating an Instance
Once the above steps are in place, you can create an instance with the following commands:
```bash
openstack server create --flavor n1-kubemaster --network kubenet --key-name k8s-key --image ubuntu20-focal --security-group kubesecgroup k8s-master01
openstack server create --flavor n2-kubeworker --network kubenet --key-name k8s-key --image ubuntu20-focal --security-group kubesecgroup k8s-worker01
```

## Creating a Floating IP
A floating IP functions as a NAT applied to the internal IP of an instance. To create floating IPs, use the following commands:
```bash
openstack floating ip create --floating-ip 172.16.1.244 ext-net
openstack floating ip create --floating-ip 172.16.1.245 ext-net
openstack floating ip list
openstack server add floating ip k8s-master01 172.16.1.244
openstack server add floating ip k8s-worker01 172.16.1.245
openstack server list
```

## Creating a Volume
A volume is used as persistent storage for an instance in the form of block storage. To create a volume and attach it to an instance, use the following commands:
```bash
openstack volume create --size 1 mvolume
openstack server add volume k8s-master01 mvolume
```
### Expanding a Volume
```bash
openstack server remove volume k8s-master01 mvolume
openstack volume set --size 2 mvolume
openstack volume list
openstack server add volume k8s-master01 mvolume
openstack server show k8s-master01
```

## Instance with Persistent Storage
To create persistent storage on the root partition when an instance is created, use the following command:
```bash
openstack volume create --size 10 --image ubuntu20-focal web-server-ubuntu02
openstack server create --flavor c1-standard-01 \
  --key-name controllerkey \
  --security-group secg-basic-web \
  --network int-net01 \
  --volume web-server-ubuntu02 --wait \
  web-server-ubuntu02
```

## Upgrading an Instance with a New Flavor
Over time, the specifications of an instance may need to be upgraded to meet new resource requirements. To apply this upgrade, follow these commands:
```bash
openstack flavor create --vcpus 2 --ram 2048 --disk 15 --public c2-standard-01
openstack server resize --flavor c2-standard-01 web-server-ubuntu01
openstack server list | grep web-server-ubuntu01
openstack server resize confirm web-server-ubuntu01
```

## References
- https://docs.openstack.org/python-openstackclient/latest/cli
- https://docs.openstack.org/python-openstackclient/latest/cli/command-objects/project-v2.html#project-create
- https://docs.openstack.org/python-openstackclient/latest/cli/command-objects/user-v2.html#user-create
- https://docs.openstack.org/keystone/rocky/admin/cli-manage-projects-users-and-roles.html