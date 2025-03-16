#!/bin/bash

sudo dnf install -y epel-release
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
curl -sLo ~/.bashrc https://raw.githubusercontent.com/vikipranata/vikipranata/ghpages/assets/manifests/.bashrc
cp -r ~/.bashrc /etc/skel/.bashrc

cat <<EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

cat <<EOF | sudo tee /etc/yum.repos.d/microsoft-edge.repo
[microsoft-edge]
name=microsoft-edge
baseurl=https://packages.microsoft.com/yumrepos/edge/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

cat <<EOF | sudo tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

curl -s https://packagecloud.io/install/repositories/eugeny/tabby/script.rpm.sh | sudo bash
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm

sudo dnf check-update
sudo dnf install -y htop iftop iotop ipcalc whois dnsutils net-tools dnf-utils iperf3 nmap curl wget jq nano \
                    git mlocate ncdu tmux traceroute mtr gparted speedtest-cli gnome-tweaks \
                    vlc onedrive setroubleshoot policycoreutils kubectl helm smartmontools nvme-cli gparted \
                    python3-openstackclient python3-pip python3-virtualenv fprintd s3cmd tree \
                    gnome-shell-extension microsoft-edge-stable google-chrome-stable code tabby-terminal \
                    NetworkManager-openvpn NetworkManager-openvpn-gnome NetworkManager-l2tp NetworkManager-l2tp-gnome wireguard-tools

FLAMESHOT_VER=12.1.0
sudo dnf install -y https://github.com/flameshot-org/flameshot/releases/download/v$FLAMESHOT_VER/flameshot-$FLAMESHOT_VER-1.fc35.x86_64.rpm

sudo dnf remove --allowerasing rhythmbox mediawriter \
                gnome-logs gnome-maps gnome-tour gnome-weather hexchat evolution brasero \
                gnome-disk-utility gnome-system-monitor gnome-contacts gnome-terminal \
                gnome-remote-desktop gnome-boxes gnome-connections totem-video-thumbnailer

pip3 install -U chromaterm certbot certbot-dns-cloudflare

flatpak install -y flathub \
        com.spotify.Client \
        org.telegram.desktop \
        com.getpostman.Postman \
        com.github.tenderowl.frog \
        com.mattjakeman.ExtensionManager \
        com.hunterwittenborn.Celeste \
        com.obsproject.Studio

sudo sed -i 's/^# set tabsize 8/set tabsize 2/' /etc/nanorc
sudo sed -i 's/^# set tabstospaces/set tabstospaces/' /etc/nanorc

mkdir -p /run/media/$USER/Systems /run/media/$USER/Data
cat <<EOF | tee -a /etc/fstab
# UUID=01DA69D87C6FE010 /run/media/$USER/Systems   ntfs    defaults,umask=0002,uid=1000,gid=1000,nofail 0 2
# UUID=01DB79D81545E2C0 /run/media/$USER/Data      ntfs    defaults,umask=0002,uid=1000,gid=1000,nofail 0 2
EOF

## Gnome Extension | https://extensions.gnome.org
# Windows is Ready - Notification Remover
# Status Area Horizontal Spacing
# Notification Banner Reloaded
# Hide Activities Button
# Removable Drive Menu
# Net speed Simplified
# Frippery Move Clock
# Clipboard History
# Power Tracker
# Blur my Shell
# Media Control

## Gnome shortcuts
# Launchers - Home folder | Super+E
# Screenshots - Save a screenshots to Picture | Disable
# System - Show the notification list | Disable
# System - Show the run command promt | Super+R
# Custom - Flameshot | Print
