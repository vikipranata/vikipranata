---
author: "Viki Pranata"
title: "Belajar Ceph Storage"
description : "Belajar Ceph Software Define Storage"
date: "2023-01-22"
tags: ["linux", "storage", "ceph"]
showToc: true
---
# Reliable Autonomic Distributed Object Store (RADOS)
RADOS adalah sistem penyimpanan objek terdistribusi (distributed object store) yang terpercaya (reliable) dan otomatis (autonomic). RADOS memastikan bahwa data tetap aman dan dapat diakses bahkan dalam menghadapi kegagalan node atau server. Otomatisasi cerdasnya memungkinkan sistem beroperasi dengan efisien dan efektif tanpa banyak intervensi manusia.

# Ceph Monitor (ceph-mon)
Ceph-mon berfungsi untuk memantau semua bagian data dan membantu mengetahui di mana data harus disimpan dan ditemukan.

ceph-mon menggunakan cluster map dalam melacak dan mengatur informasi topologi cluster ceph seperti:
- OSD Map (Object Store Daemon) menyimpan informasi tentang status dan kapasitas setiap OSD dalam klaster. Ini membantu Ceph untuk mendistribusikan data dengan efisien.
- PG Map (Placeement Group) memberikan informasi tentang distribusi dan status dari Placement Groups di dalam klaster

Minimal ceph-mon yang terpasang setidaknya ada 3 monitor yang di tempatkan setiap host untuk mengaktifkan high availability sehingga cluster masih dapat berfungsi bahkan jika satu ceph-mon mengalami masalah.

Peran utama Ceph Monitor adalah untuk memelihara master copy dari cluster map dan juga menyediakan layanan authentication dan logging. 

Ceph Monitor menulis semua perubahan dalam service monitor ke stau instance Paxos, dan Paxos menuliskan perubahan pada key-value database untuk konsistensi data yang kuat.

![image](https://access.redhat.com/webassets/avalon/d/Red_Hat_Ceph_Storage-2-Configuration_Guide-en-US/images/6ed943dd0023cc45d098233e3e39676c/diag-3d37cf72a2b8faf454218b35e9bcb001.png)

# Ceph Manager (ceph-mgr)
Ceph Manager berfungsi untuk memperhatikan bagaimana kinerja cluster Ceph seperti berapa banyak penyimpanan yang digunakan, seberapa baik kinerjanya, dan seberapa sibuk sistemnya.

Ceph Dashboard dan RESTful API adalah beberapa alat untuk berkomunikasi dengan ceph-mgr dengan modul berbasis Python.

Minimal ceph-mgr yang terpasang setidaknya ada 2 dengan sistem active-backup.

# Ceph Object Storage Daemon (OSD)
Ceph-osd bisa diseebut juga storage worker pada cluster ceph. Dibantu dengan ceph-mon dan ceph-mgr untuk menjaga data tetap aman, membuat salinan data, dan menyeimbangkan data.

Backends OSD secara default pada versi 12.2.z rilis menggunakan Bluestore dan ini sangat direkomendasikan, untuk versi sebelumnya hanya ada opsi FilesStore untuk backend OSD.

Untuk stuktur penyimpanan data, Bluestore menggunakan format peneyimpanan langsung pada fisk fisik (raw disk) sehingga data disimpan langsung di perangkat penyimpanan tanpa menggunakan file system yang terpisah.
Sedangkan Filestore menggunakan file system seperti XFS atau ext4 sebagai lapisan penyimpanan untuk menyimpan data.

Dari segi performa, Bluestore cenderung memiliki kinerja yang lebih tinggi, terutama pada input/output yang acak, karena data disimpan langsung pada raw disk.

Bluestore juga sangat efisien karena menghindari lapisan tambahan (file system) dan memberikan kontrol langsung atas blok data yang disimpan pada disk.

# RADOS Gatewey (RGW)
Selain OSD, RGW adalah komponen ekosistem ceph yang memberikan antarmuka RESTful API untuk meyimpan dan menegambil data dari ceph menggunakan Librados (client library) salah satunya adalah ceph object gateway dengan kompabilitas pada protokol S3 dan OpenStack Swift API.

# Placement Group (PG)
Setiap objek di Ceph termasuk ke dalam satu PG dimana masing-masing objek memiliki identitas unik (pgid) tersendiri. Setiap pool di ceph memiliki kelompok objek yang disebut placement group (PG), PG ini kemudian diberikan ke beberapa OSD beredasarkan konfigurasi Pools. Setiap PG menampung banyak objek, dan setiap OSD menampung banyak PG.

Ceph mendistribusikan data secara merata pada storage devices dan menghindari hotspots serta menjaga keseimbangan pada cluster ceph dengan metode CRUSH (Controlled Replication Under Scalable Hashing).
CRUSH map digunakan untuk memetakan PG ke OSD. Ini menentukan tempat fisik di mana data di dalam PG disimpan di OSD di seluruh cluster ceph.

Untuk membuat perhitungan PGs dapet menggunakan [ceph calculator](https://florian.ca/ceph-calculator/)
