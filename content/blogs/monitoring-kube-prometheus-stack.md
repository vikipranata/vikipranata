---
author: "Viki Pranata"
title: "Kubernetes Monitoring dengan Prometheus Stack"
description : "Memonitoring Sumberdaya Kubernetes dengan kube-prometheus-stack"
date: "2022-11-22"
tags: ["linux", "Kubernetes", "helm", "Prometheus"]
showToc: true
---

## Persiapan
Membuat namespace baru untuk monitoring dengan perintah berikut :
```bash
kubectl create ns monitoring
```

Lalu memasangan `helm` yang bisa diterapkan pada postingan [helm packet manager](/posts/kubernetes-getting-started/#menerapkan-helm-packet-manager). Lnalu menambahkan repo prometheus-comunity dengan perintah berikut :
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Membuat secret akses certificate etcd client
> run as root user
```bash
sudo su
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n monitoring create secret generic etcd-client-cert --from-file=/etc/kubernetes/pki/etcd/ca.crt --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key
exit
```

### Membuat helm values kube-prometheus-stack
buat file dan isi data sebagai berikut :    
`nano kube-prometheus-stack-helm-values.yaml`
```yaml
alertmanager:
  enabled: false

grafana:
  defaultDashboardsTimezone: Asia/Jakarta
  adminPassword: P@ssw0rd
  image:
    repository: grafana/grafana
    tag: "8.2.7"
  persistence:
    enabled: true
    storageClassName: "local-path"
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 10Gi

prometheus:
  prometheusSpec:
    secrets: ['etcd-client-cert']
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "local-path"
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 10Gi
kubeEtcd:
  service:
    targetPort: 2379
  serviceMonitor:
    scheme: https
    insecureSkipVerify: false
    serverName: localhost
    caFile: /etc/prometheus/secrets/etcd-client-cert/ca.crt
    certFile: /etc/prometheus/secrets/etcd-client-cert/healthcheck-client.crt
    keyFile: /etc/prometheus/secrets/etcd-client-cert/healthcheck-client.key

kubeScheduler:
  service:
    targetPort: 10259
  serviceMonitor:
    https: "true"
    insecureSkipVerify: "true"
```
`storageClassName` didapat pada pemasangan local-path pada postingan [menambahkan local path provisioner](/posts/kubernetes-getting-started/#menambahkan-local-path-provisioner)

### Memasang kube-prometheus-stack dengan helm
```bash
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring -f kube-prometheus-stack-helm-values.yaml
```

### Membuat ingress kube-prometheus-stack
Membuat ingress untuk subdomain _grafana.syslog.my.id_ dan _prometheus.syslog.my.id_ dengan manifest file berikut :    
`nano kube-prometheus-stack-ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.syslog.my.id
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.syslog.my.id
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-prometheus-prometheus
            port:
              number: 9090
```
Menerapkan manifest dengan perintah
```bash
kubectl apply -f kube-prometheus-stack-ingress.yaml
```
Lalu lihat service den ingress kube-prometheus-stack dengan perintah    
`kubectl -n monitoring get svc` dan `kubectl -n monitoring get ingress`
![image](/assets/images/k8s_service_prometheus_stack.webp)

### Memperbaiki masalah yang terjadi
![image](/assets/images/kube-prometheus-stack-issue.webp)

> Update configmap kube-proxy
```bash
kubectl -n kube-system edit cm kube-proxy
```
tambahkan value `0.0.0.0:10249` pada key `metricsBindAddress`
```yaml
    metricsBindAddress: "0.0.0.0:10249"
```

> Update ip `127.0.0.1` ke ip `0.0.0.0`
```bash
sudo nano /etc/kubernetes/manifests/etcd.yaml
    # Ubah bagian ini
    # - --listen-metrics-urls=http://127.0.0.1:2381
```
```bash
sudo nano /etc/kubernetes/manifests/kube-scheduler.yaml
    # Ubah bagian ini
    # - --bind-address=127.0.0.1
```
```bash
sudo nano /etc/kubernetes/manifests/kube-controller-manager.yaml
    # Ubah bagian ini
    # - --bind-address=127.0.0.1
```
## Sumber Referensi
Persistent volumes issue:    
- https://github.com/prometheus-community/helm-charts/issues/186#issuecomment-899669790

etcd monitoring issue:    
- https://github.com/prometheus-community/helm-charts/issues/1005#issuecomment-1014873446
- https://github.com/prometheus-community/helm-charts/issues/204#issuecomment-765155883

kube-prometheus-stack scraping metrics issue:    
- https://stackoverflow.com/questions/65901186/kube-prometheus-stack-issue-scraping-metrics
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy