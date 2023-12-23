---
author: "Viki Pranata"
title: "Monitoring dengan Prometheus"
description : "Membuat monitoring server dengan Prometheus"
date: "2023-01-22"
tags: ["linux", "Monitoring"]
showToc: true
---
Prometheus berfungsi untuk mengumpulkan metrik dari target server untuk mengamati, mengevaluasi, menampilkan hasil, dan mentrigger alert pada kondisi tertentu.

## 1. Instalasi Prometheus
Membuat user prometheus dan direktori yang dibutuhkan.
```bash
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus
```

Untuk pemasanganya kita perlu mendownload terlebih dahulu binari file pada halaman [https://prometheus.io/download/](https://prometheus.io/download/) untuk memilih versi yang akan digunakan.

```bash
# Definisikan versi prometheus yang akan di install
PROMETHEUS_VER=2.37.5
sudo wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VER/prometheus-$PROMETHEUS_VER.linux-amd64.tar.gz
# extract dan pindah ke direktori prometheus
sudo tar -zxvf prometheus-$PROMETHEUS_VER.linux-amd64.tar.gz && cd prometheus-$PROMETHEUS_VER.linux-amd64
```

Install file binari prometheus
```bash
sudo install -o prometheus -g prometheus prometheus /usr/local/bin
sudo install -o prometheus -g prometheus promtool /usr/local/bin
```

Pindahkan direktori consoles dan console_libraries serta update ownership ke prometheus user
```bash
sudo mv console* /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus
```

## 2. Konfigurasi Prometheus
Buat file konfigurasi prometheus.yml
```bash
sudo nano /etc/prometheus/prometheus.yml
# Sesuaikan dengan kebutuhan, dan update file ownership ke prometheus user
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
```

```yaml
global:
  scrape_interval: 10s
  evaluation_interval: 10s
scrape_configs:
  - job_name: "prometheus"
    scrape_interval: 5s
    static_configs:
      - targets: ["localhost:9090"]
    # Relabeling "instance" to remove the ":9090" part
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+)(:[0-9]+)?'
        replacement: '${1}'
```

## 3. Konfigurasi Service Prometheus
Buat file service systemd prometheus
```bash
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description="The Prometheus monitoring system and time series database."
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--web.listen-address="0.0.0.0:9090"

[Install]
WantedBy=multi-user.target
EOF
```

Reload systemd service untuk mendaftarkan service yang baru, lalu jalankan pada saat system boot.
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
# Pastikan service sudah berjalan
sudo systemctl status prometheus
```

Bisa kita lanjutkan untuk administrasi via web console dengan menuju alamat url `http://<ip-server-prometheus>:9090/`

# Referensi
- https://github.com/prometheus/prometheus
- https://devopscube.com/install-configure-prometheus-linux