---
author: "Viki Pranata"
title: "Load Balancer Ingress Kubernetes"
description : "Membuat node load balancer untuk ingress kubernetes dengan NGINX"
date: "2022-11-23"
tags: ["linux", "Kubernetes", "nginx", "loadbalancer"]
showToc: true
---
Dengan menambahkan node load balancer untuk ingress controller dimana akan membagi traffic masuk ke dalam worker. Kita akan menggunakan kubernetes cluster yang sudah pernah dibuat sebelumnya pada postingan [kubernetes for lab](/posts/kubernetes-for-lab).

## Topologi
![img](/assets/images/k8s_ingress_loadbalancer.png)

## Persiapan
### Menginstall paket yang dibutuhkan
```bash
sudo apt install nginx certbot python3-certbot-nginx
```
## Konfigurasi nginx http load balancer
### Backup konfigurasi lama
```bash
sudo mv /etc/nginx/{nginx.conf,nginx.conf.orig}
```
### Pasang konfigurasi baru
```
sudo nano /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
     worker_connections 768;
     # multi_accept on;
}

http {
     # include /etc/nginx/conf.d/*.conf;
     # include /etc/nginx/sites-enabled/*;
}

stream {
    include /etc/nginx/stream.d/*.conf;

    log_format basic '$remote_addr [$time_local] '
                 '$protocol $status $bytes_sent $bytes_received '
                 '$session_time "$upstream_addr" '
                 '"$upstream_bytes_sent" "$upstream_bytes_received" "$upstream_connect_time"';

    access_log /var/log/nginx/access.log basic;
    error_log  /var/log/nginx/error.log;
}
```
Buat direktori `stream.d` 
```bash
sudo mkdir /etc/nginx/stream.d
```
Buat konfigurasi http load balancer, pastikan terlebih dahulu port yang terekspose pada service ingress-nginx dengan perintah `kubectl -n ingress-controller get svc` pada deployment ingress controller dengan helm di postingan [membuat ingress controller](/posts/kubernetes-getting-started/#membuat-ingress-controller)
```bash
cat <<EOF | sudo tee /etc/nginx/stream.d/k8s-ingress-http.conf
upstream k8s-ingress-http {
    server 192.168.0.102:38080 max_fails=3;
    server 192.168.0.103:38080 max_fails=3;
}

server {
    listen 80 ;
    proxy_pass k8s-ingress-http;
    proxy_connect_timeout 10s;
    proxy_timeout 60s;
}
EOF
```

## Konfigurasi nginx https load balancer
### Generate SSL wildcard dengan letsencypt
```bash
sudo certbot certonly --manual --preferred-challenges=dns --email info@syslog.my.id --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d *.syslog.my.id
```
Ikuti lankah selanjutnya untuk membuat `TXT record _acme-challenge.syslog.my.id` dengan _value_ yang tampil dari output command tersebut pada domain panel, tunggu sampai propagasi selesai bisa di cek melalui [https://dnschecker.org](https://dnschecker.org/#TXT/_acme-challenge.syslog.my.id).

Buat konfigurasi http load balancer, pastikan terlebih dahulu port yang terekspose pada service ingress-nginx dengan perintah `kubectl -n ingress-controller get svc` pada deployment ingress controller dengan helm di postingan [membuat ingress controller](/posts/kubernetes-getting-started/#membuat-ingress-controller)
```bash
cat <<EOF | sudo tee /etc/nginx/stream.d/k8s-ingress-https.conf
upstream k8s-ingress-https {
    server 192.168.0.102:38443 max_fails=3;
    server 192.168.0.103:38443 max_fails=3;
}

server {
    listen 443 ssl http2;
    proxy_pass k8s-ingress-https;
    proxy_connect_timeout 10s;
    proxy_timeout 60s;

    ssl_certificat      /etc/letsencrypt/live/syslog.my.id/cert.pem;
    ssl_certificate_key /etc/letsencrypt/live/syslog.my.id/privkey.pem;

    # intermediate configuration
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
}
EOF
```
Download konfigurasi ssl tambahan
```bash
curl -sL https://ssl-config.mozilla.org/ffdhe2048.txt -o /etc/letsencrypt/ssl-dhparams.pem
curl -sL https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -o /etc/letsencrypt/options-ssl-nginx.conf
```

Lakukan penguijan konfigurasi dengan perintah `nginx -t` jika tidak ada pesan error bisa langsung diterapkan konfiruasi yang baru dengan perintah `sudo systemctl reload nginx`.

## Sumber Referensi
- https://geekrewind.com/generate-free-wildcard-certificates-using-lets-encrypt-certbot-on-ubuntu-18-04
- https://ssl-config.mozilla.org/#server=nginx&version=1.17.7&config=intermediate&openssl=1.1.1k&guideline=5.6
- https://github.com/certbot/certbot/tree/master/certbot-nginx
