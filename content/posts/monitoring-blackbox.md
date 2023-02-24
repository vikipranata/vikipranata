---
author: "Viki Pranata"
title: "Monitoring Koneksi server dengan Blackbox Exporeter"
description : "Membuat monitoring server dengan Blackbox"
date: "2023-01-26"
tags: ["linux", "Monitoring"]
showToc: true
---
Blackbox Exporter, berfungsi untuk pemeriksaan endpoint lewat HTTP, HTTPS, DNS, TCP, ICMP dan gRPC yang dikombinasikan dengan [Prometheus](/posts/monitoring-node_exporter/).

## 1. Instalasi Blackbox
Membuat user blackbox dan direktori yang dibutuhkan.
```bash
sudo useradd --no-create-home --shell /bin/false blackbox_exporter
sudo mkdir /etc/blackbox_exporter
sudo chown blackbox_exporter:blackbox_exporter /etc/blackbox_exporter
```

Untuk pemasanganya kita perlu mendownload terlebih dahulu binari file pada halaman [https://blackbox.io/download/](https://blackbox.io/download/) untuk memilih versi yang akan digunakan.

```bash
# Definisikan versi blackbox yang akan di install
BLACKBOX_VER=0.23.0
sudo wget https://github.com/prometheus/blackbox_exporter/releases/download/v$BLACKBOX_VER/blackbox_exporter-$BLACKBOX_VER.linux-amd64.tar.gz
# extract dan pindah ke direktori blackbox
sudo tar -zxvf blackbox_exporter-$BLACKBOX_VER.linux-amd64.tar.gz && cd blackbox_exporter-$BLACKBOX_VER.linux-amd64
```

Install file binari blackbox
```bash
sudo install -o blackbox_exporter -g blackbox_exporter \
blackbox_exporter /usr/local/bin
```
## 2. Konfigurasi Blackbox
Pindahkan konfigurasi file `blackbox.yml` serta update ownership ke blackbox_exporter user
```bash
sudo mv blackbox.yml /etc/blackbox_exporter
sudo chown -R blackbox_exporter:blackbox_exporter /etc/blackbox_exporter
```
## 3. Konfigurasi Service Blackbox
Buat file service systemd blackbox
```bash
cat <<EOF | sudo tee /etc/systemd/system/blackbox_exporter.service
[Unit]
Description="The blackbox exporter allows blackbox probing of endpoints over HTTP, HTTPS, DNS, TCP, ICMP and gRPC."
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox_exporter
Group=blackbox_exporter
Type=simple
ExecStart=/usr/local/bin/blackbox_exporter \
--config.file /etc/blackbox_exporter/blackbox.yml \
--web.listen-address="0.0.0.0:9115"

[Install]
WantedBy=multi-user.target
EOF
```

Reload systemd service untuk mendaftarkan service yang baru, lalu jalankan pada saat system boot.
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now blackbox_exporter
# Pastikan service sudah berjalan
sudo systemctl status blackbox_exporter
```
## 4. Tambahkan Konfigurasi node_exporter
Tambahkan konfigurasi pada file prometheus.yml

```yaml
scrape_configs:
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]  # Look for a HTTP 200 response.
    static_configs:
      - targets:
        - http://prometheus.io    # Target to probe with http.
        - https://prometheus.io   # Target to probe with https.
        - http://example.com:8080 # Target to probe with http on port 8080.
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9115  # The blackbox exporter's real hostname:port.
```

Bisa kita lanjutkan untuk administrasi via web console dengan menuju alamat url `http://<ip-server-blackbox>:9115/probe`

# Referensi
- https://github.com/prometheus/blackbox_exporter
- https://devconnected.com/how-to-install-and-configure-blackbox-exporter-for-prometheus