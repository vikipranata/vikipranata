---
title: "High Availability with Keepalived"
date: 2024-09-04 09:00:00 +0700
modified: 2024-09-04 09:00:00 +0700
tags: [linux, keepalived]
description: ""
---

# **Installing Packages Dependencies**
```bash
dnf install -y keepalived
```

# **Keepalived Configuration**
Keepalived state reference  
- MASTER-MASTER (down, back to top priority)  
- MASTER-BACKUP (down, back to MASTER)  
- BACKUP-BACKUP (if down, respect to node with MASTER state)  
- Routers with priority 101 will become MASTER and Routers with priority 100 will become BACKUP.  

## Configure First Node
```bash
cat <<EOF | tee /etc/keepalived/keepalived.conf
global_defs {
    router_id JumpServer
    enable_script_security
    vrrp_check_unicast_src
}

vrrp_track_process track_openvpn {
    process openvpn
    weight 2
}

vrrp_instance VIP {
    state MASTER
    interface eth1
    virtual_router_id 69
    priority 101
    advert_int 1
    nopreempt

    authentication {
        auth_type PASS
        auth_pass Pa\$\$w0rd
    }

    unicast_src_ip 10.79.80.1
    unicast_peer {
        10.79.80.2
    }

    virtual_ipaddress {
        103.150.80.130/28 dev eth0
        10.79.80.254/24 dev eth1
    }

    virtual_routes {
        0.0.0.0/0 via 103.150.80.142 dev eth0 metric 100
    }

    static_routes {
        0.0.0.0/0 via 10.79.80.251 dev eth1 metric 101
    }

    track_process {
        track_openvpn
    }
}
EOF
```

`systemctl restart keepalived; systemctl enable keepalived`

## Configure Second Node
```bash
cat <<EOF | tee /etc/keepalived/keepalived.conf
global_defs {
    router_id JumpServer
    enable_script_security
    vrrp_check_unicast_src
}

vrrp_track_process track_openvpn {
    process openvpn
    weight 2
}

vrrp_instance VIP {
    state BACKUP
    interface eth1
    virtual_router_id 69
    priority 100
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass Pa\$\$w0rd
    }

    unicast_src_ip 10.79.80.2
    unicast_peer {
        10.79.80.1
    }

    virtual_ipaddress {
        104.18.5.103/28 dev eth0
        10.79.80.254/24 dev eth1
    }

    virtual_routes {
        0.0.0.0/0 via 103.150.80.142 dev eth0 metric 100
    }

    static_routes {
        0.0.0.0/0 via 10.79.80.251 dev eth1 metric 101
    }

    track_process {
        track_openvpn
    }
}
EOF
```

`systemctl restart keepalived; systemctl enable keepalived`

## Custom Health Check

If you want to custom script for health check change or adjust this `keepalived.conf` file.
```
vrrp_script healthcheck {
    script "/bin/bash /etc/keepalived/healthcheck.sh"
    user root root
    interval 2
    weight 2
}

vrrp_instance VIP {
    ...
    track_script {
        healthcheck
    }
    ...
}
```

and create `healthcheck.sh` bash script like this
```bash
#!/bin/bash
TARGET_URL="https://127.0.0.1:443"
USER_AGENT=$(keepalived -v 2>&1 | awk '/Keepalived/ {print $1"/"$2}')

curl --head \
        --silent \
        --insecure \
        --max-time 1 \
        --header "Via: $HOSTNAME" \
        --header "User-Agent: $USER_AGENT" \
        --request GET "$TARGET_URL" -o /dev/null
echo "Result code $?"
exit $?
```

Also when SELinux is Enforcing, add this module
```bash
semodule -r keepalived-health-check
cat <<EOF | tee keepalived-health-check.te
module keepalived-health-check 1.0;

require {
        type shell_exec_t;
        type keepalived_t;
        type keepalived_exec_t;
        type unreserved_port_t;
        type hostname_exec_t;
        class file { getattr setattr execute execute_no_trans open read map };
        class tcp_socket name_connect;
}

#============= keepalived_t ==============
allow keepalived_t shell_exec_t:file setattr;
allow keepalived_t unreserved_port_t:tcp_socket name_connect;
allow keepalived_t keepalived_exec_t:file { execute_no_trans open };
allow keepalived_t hostname_exec_t:file { getattr execute execute_no_trans open read };

#!!!! This avc can be allowed using the boolean 'domain_can_mmap_files'
allow keepalived_t hostname_exec_t:file map;
EOF
```

```bash
checkmodule -M -m -o keepalived-health-check.mod keepalived-health-check.te
semodule_package -o keepalived-health-check.pp -m keepalived-health-check.mod
semodule -i keepalived-health-check.pp
```

```bash
sealert -a /var/log/audit/audit.log
```

Troubleshooting with keepalived debug
```bash
keepalived -nldD
```

**Reference:**  
- [https://www.redhat.com/sysadmin/advanced-keepalived](https://www.redhat.com/sysadmin/advanced-keepalived)  
- [https://access.redhat.com/solutions/3220521](https://access.redhat.com/solutions/3220521)  
- [https://manpages.debian.org/testing/keepalived/keepalived.conf.5.en.html](https://manpages.debian.org/testing/keepalived/keepalived.conf.5.en.html)  
- [https://github.com/sandervanvugt/cka/blob/master/check\_apiserver.sh](https://github.com/sandervanvugt/cka/blob/master/check_apiserver.sh)