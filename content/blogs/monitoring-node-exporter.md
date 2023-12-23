---
author: "Viki Pranata"
title: "Monitoring Utilisasi server dengan Node Exporter"
description : "Membuat monitoring utilisasi server dengan Node Exporter"
date: "2023-01-26"
tags: ["linux", "Monitoring"]
showToc: true
---
Node Exporter, berfungsi untuk mengumpulkan metrik terkait _hardware_ dan _kernel_ yang dikombinasikan dengan [prometheus](/posts/monitoring-prometheus).

## 1. Instalasi Node Exporter
Membuat user node exporter dan direktori yang dibutuhkan.
```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

Untuk pemasanganya kita perlu mendownload terlebih dahulu binari file pada halaman [repositori node exporter](https://github.com/prometheus/node_exporter/releases) untuk memilih versi yang akan digunakan.

```bash
# Definisikan versi node_exporter yang akan di install
NODE_EXPORTER_VER=1.5.0
sudo wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VER/node_exporter-$NODE_EXPORTER_VER.linux-amd64.tar.gz
# extract dan pindah ke direktori node_exporter
sudo tar -zxvf node_exporter-$NODE_EXPORTER_VER.linux-amd64.tar.gz && cd node_exporter-$NODE_EXPORTER_VER.linux-amd64
```

Install file binari node_exporter
```bash
sudo install -o node_exporter -g node_exporter \
node_exporter /usr/local/bin
```

## 2. Konfigurasi Service node_exporter
Buat file service systemd node_exporter
```bash
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description="The node exporter monitoring system and time series database."
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address="0.0.0.0:9100"

[Install]
WantedBy=multi-user.target
EOF
```

Reload systemd service untuk mendaftarkan service yang baru, lalu jalankan pada saat system boot.
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
# Pastikan service sudah berjalan
sudo systemctl status node_exporter
```

## 3. Tambahkan Konfigurasi node_exporter
Tambahkan konfigurasi pada file prometheus.yml

```yaml
scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets: [ "localhost:9100" ]
    scheme: http

    # Relabeling "instance" to remove the ":9100" part
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+)(:[0-9]+)?'
        replacement: '${1}'
```

Bisa kita lanjutkan untuk administrasi via web console dengan menuju alamat url `http://<ip-server-node_exporter>:9100/`

# Referensi
- https://github.com/prometheus/node_exporter
- https://prometheus.io/docs/guides/node-exporter