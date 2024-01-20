---
author: "Viki Pranata"
title: "Hal Yang Bisa Dilakukan Setelah Membangun Kubernetes"
description : "hal yang bisa kita lakukan setelah membangun Kubernetes"
date: "2022-11-15"
tags: ["linux", "Kubernetes", "helm"]
showToc: true
---
Ada beberapa hal yang dapat dilakukan setelah membangun cluster kubernetes dengan menginstall tools maupun add-ons berikut:

## Menerapkan HELM Packet Manager
_The package manager for Kubernetes_ membantu kita untuk memasang aplikasi lewaat paket manager cukup dengan perintah berikut :
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
Selanjutnya kita bisa menambahkan helm repo sesuai dengan aplikasi yang akan kita pasang.

## Menerapkan bash auto-completion
Perintah kubernetes sangat banyak dan jarang kita hafal, langkah berikut dapat membantu untuk menjalankan perintah `kubectl, kubeadm, maupun helm`

```bash
cat <<EOF | sudo tee >> ~/.profile
source <(kubectl completion bash)
source <(kubeadm completion bash)
source <(helm completion bash)
EOF
```

Lalu jika kita ingin membuat alias kubectl dengan auto-completion bash dapat menerapkan berikut :
```bash
cat <<EOF | sudo tee >> ~/.profile
alias k=kubectl
complete -F __start_kubectl k
EOF
```

Selanjutnya jangan lupa `source ~/.profile` pada terminal session kita untuk menerapkan profile environment yang baru.

## Menginstall Metrics Server
Metrics Server berfungsi untuk mengumpulkan resource metrics dari Kubelet dan mengexpose ke apiserver melalui Metrics API untuk digunakan oleh Horizontal Pod Autoscaler (HPA) dan Vertical Pod Autoscaler (VPA). Metrics API juga dapat digunakan dengan perintah `kubectl top node` maupun `kubectl top pod -n <namespace>` bahkan kita bisa mensortir berdasarkan `--sort-by-cpu` maupun `--sort-by-memory`.
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm repo update
```
buat helm value dengan isi berikut :
```bash
cat <<EOF | tee metrics-server-helm-values.yaml
args:
  - --kubelet-insecure-tls
  - --kubelet-preferred-address-types=InternalIP
EOF
```
Selanjutnya tinggal diterapkan dengan perintah berikut :
```bash
helm install metrics-server metrics-server/metrics-server -n kube-system -f metrics-server-helm-values.yaml
```
Kita dapat melihat helm value apa saja yang bisa kita sesuaikan sebelum diterapkan dengan perintah `helm show values metrics-server/metrics-server` dan melihat helm value apa saja yang sudah kita terapkan dengan perintah `helm -n kube-system get values metrics-server`

## Menginstall Kube State Metrics
kube-state-metrics (KSM) adalah layanan sederhana yang mendengarkan server API Kubernetes dan menghasilkan metrik tentang status objek.
Buat folder dan kumpulkan manifest hasil download dengan perintah berikut :
```bash
mkdir ~/kube-state-metrics && cd ~/kube-state-metrics
wget https://raw.githubusercontent.com/kubernetes/kube-state-metrics/master/examples/standard/cluster-role-binding.yaml
wget https://raw.githubusercontent.com/kubernetes/kube-state-metrics/master/examples/standard/cluster-role.yaml
wget https://raw.githubusercontent.com/kubernetes/kube-state-metrics/master/examples/standard/deployment.yaml
wget https://raw.githubusercontent.com/kubernetes/kube-state-metrics/master/examples/standard/service-account.yaml
wget https://raw.githubusercontent.com/kubernetes/kube-state-metrics/master/examples/standard/service.yaml
```
Lalu delete pada file `service.yml` pada bagian `clusterIP: None` setelah itu terapkan manifest dengan perintah berikut :
```bash
kubectl apply -f .
```
Kita bisa melihat hasil instalasinya dengan perintah `kubectl -n kube-system get all | grep kube-state-metrics`

## Membuat Ingress Controller
Ingress digunakan untuk mengonfigurasi load balance HTTP untuk aplikasi (pod) yang berjalan di Kubernetes yang diperlukan untuk mengirimkan aplikasi tersebut ke klien di luar klaster Kubernetes. Kita akan menerapkan Nginx Ingress Controller menggunakan Helm Packet Manager dengan perintah berikut :

Buat namespace terlebih dahulu dengan perintah `kubectl create ns ingress-controller` agar tersusun dengan baik.
```bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
```
buat helm value dengan isi berikut :
```bash
cat <<EOF | tee ingress-helm-values.yaml
controller:
  service:
    externalTrafficPolicy: Cluster
    httpPort:
      enable: true
      nodePort: ""
      port: 80
      targetPort: 80
    httpsPort:
      enable: true
      nodePort: ""
      port: 443
      targetPort: 443
EOF
```
Selanjutnya tinggal diterapkan dengan perintah berikut :
```bash
helm install ingress nginx-stable/nginx-ingress --namespace ingress-controller -f ingress-helm-values.yaml
```
Kita dapat melihat helm value apa saja yang bisa kita sesuaikan sebelum diterapkan dengan perintah `helm show values nginx-stable/nginx-ingress` dan melihat helm value apa saja yang sudah kita terapkan dengan perintah `helm -n kube-system get values ingress`

## Menerapkan Kubernetes Dashboard
Kubernetes Dashboard sangat berguna untuk kita dalam mengelola cluster kubernetes secara GUI
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

Lalu buat user dengan cluster role `cluster-admin` dengan menggunakan manifest file `sa-rbac-vikipranata.yaml`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vikipranata
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vikipranata
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: vikipranata
  namespace: kubernetes-dashboard
```
terapkan manifest dengan perintah `kubectl apply -f sa-rbac-vikipranata.yaml` lalu buat token untuk masuk ke dashboard kubernetes dengan perintah
```bash
kubectl -n kubernetes-dashboard create token vikipranata > token.txt
cat token.txt
```
copy hasil token tersebut dan untuk mengakses nya kita perlu menggunakan koneksi proxy ke cluster dengan perintah `kubectl proxy` setelah muncul pesan _Starting to serve on 127.0.0.1:8001_ masuk ke pengaturan proxy anda pada browser dan buka url berikut :
[`http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`](
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

![img](/assets/images/kube-dashboard.webp)

## Menambahkan local-path provisioner
Local path provisioner berfungsi untuk memanfaatkan penyimpanan lokal di setiap node dengan membuat PersistentVolumes berbasis hostPath atau local pada directory /opt/local-path-provisioner di setiap node secara otomatis. Untuk menerapkan manifest local-path dengan perintah berikut :
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.23/deploy/local-path-storage.yaml
```
setelah terpasang, local-path dapat digunakan dengan StorageClass bernama `local-path` yang didapat dari perintah `kubectl get storageclass`

## Sumber Referensi
- https://kubernetes.io/docs/tasks/tools/included/optional-kubectl-configs-bash-linux
- https://helm.sh/docs/intro/install
- https://github.com/kubernetes/kube-state-metrics
- https://github.com/kubernetes-sigs/metrics-server
- https://github.com/kubernetes/kube-state-metrics/#kube-state-metrics-vs-metrics-server
- https://artifacthub.io/packages/helm/metrics-server/metrics-server
- https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-helm
- https://medium.com/pablo-perez/k8s-externaltrafficpolicy-local-or-cluster-40b259a19404
- https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer
- https://github.com/kubernetes/dashboard
- https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md
- https://github.com/rancher/local-path-provisioner