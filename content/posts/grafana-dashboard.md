---
author: "Viki Pranata"
title: "Grafana Dashbaord dengan Reverse Proxy"
description : "Membuat Grafana Dashboard dengan Nginx Reverse Proxy"
date: "2023-01-22"
tags: ["linux", "Monitoring"]
showToc: true
---
## Objektif
Cara membuat grafana dashboard kita lebih aman dari internet dengan langkah-langkah berikut:
Sistem operasi yang saya gunakan adalah RedHat Base dengan _AlmaLinux 8_ dengan versi grafana _8.5.15_ atau yang lebih baru dengan subdomain _monitor.syslog.my.id_

## 1. Instalasi Paket
Untuk memilih versi grafana yang akan digunakan bisa merujuk pada link [disini](https://grafana.com/grafana/download/8.5.15?edition=oss)
```bash
# Download dan install paket grafana
sudo dnf install https://dl.grafana.com/oss/release/grafana-8.5.15-1.x86_64.rpm
```
## 2. Konfigurasi Grafana
Disini kita perlu mengubah parameter _http_addr_ pada _/etc/grafana/grafana.ini_ agar default port _3000_ grafana listen pada localhost _127.0.0.1_
```bash
sudo nano /etc/grafana/grafana.ini
# Ubah bagian ini
http_addr = 127.0.0.1
domain = monitor.syslog.my.id
```
Lalu memuat ulang daemon service, dan jalankan service grafana-server pada saat boot
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now grafana-server
# Pastikan service sudah berjalan
sudo systemctl status grafana-server
```

## 3. Konfigurasi Reverse Proxy
Setelah port 3000 sudah terbuka hanya pada localhost, maka kita perlu mengkonfigurasikan nginx sebagai reverse proxy server. Pertama kita perlu merubah konfigurasi nginx.conf seperti berikut:    

Install paket webserver dan certbot untuk mengenerate ssl dari let's encrypt
```bash
sudo dnf install nginx certbot python3-certbot-nginx
```
```bash
# Kosongkan file konfigurasi nginx.conf
sudo cat /dev/null > /etc/nginx/nginx.conf
sudo nano /etc/nginx/nginx.conf
```
Lalu isi dengan konfigurasi baru sebagai berikut :
```bash
user nginx;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
load_module /usr/lib64/nginx/modules/ngx_stream_module.so;

events {
     worker_connections 768;
     # multi_accept on;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/default.d/*.conf;
    include /etc/nginx/sites-enabled/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        return       404;

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    access_log  /var/log/nginx/access.log  main;
    error_log  /var/log/nginx/error.log;
    }
}
```
Buat direktori dan file konfigurasi untuk dashboard grafana
```bash
sudo mkdir /etc/nginx/sites-enabled
sudo nano /etc/nginx/sites-enabled/grafana.conf
# Isikan konfigurasi berikut
```
```bash
# this is required to proxy Grafana Live WebSocket connections.
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

upstream grafana {
  server localhost:3000;
}

server {
  listen 80;
  server_name monitor.syslog.my.id;
  location / {
    proxy_set_header Host $http_host;
    proxy_pass http://grafana;
  }

  # Proxy Grafana Live WebSocket connections.
  location /api/live/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $http_host;
    proxy_pass http://grafana;
  }
}
```
Validasi konfigurasi nginx dengan perintah
```bash
sudo nginx -t
# Pastikan tidak terdapat error, lalu reload service nginx
sudo systemctl reload nginx 
```
## 4. Konfigurasi SSL/TLS
Selanjutnya kita dapat memanfaatkan layanan sertifikat ssl gratis dari [let's encrypt](https://letsencrypt.org/id/) dan konfigurasi otomatis dengan certbot serta plugin certbot nginx.
```bash
certbot --nginx --email yourmail@example.com --agree-tos -d monitor.binercloud.com
```
Tambahkan cronjob agar sertifikat otomatis memperbarui setiap bulan dengan perintah `crontab -e`
```bash
0 0 1 * *       certbot renew --nginx --force-renew --non-interactive > /var/log/ssl_renewal_`date +\%Y\%m\%d_\%H\%M\%S`.log 2>&1
```

# Referensi
- https://grafana.com/grafana/download/8.5.15?edition=oss
- https://grafana.com/tutorials/run-grafana-behind-a-proxy
- https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx