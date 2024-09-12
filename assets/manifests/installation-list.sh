#!/bin/bash
sudo dnf install -y epel-release
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

sudo dnf install -y htop iftop iotop ipcalc whois dnsutils net-tools dnf-utils iperf3 nmap curl wget \
                    mlocate ncdu tmux traceroute mtr flameshot gparted speedtest-cli gnome-tweaks \
                    vlc onedrive setroubleshoot policycoreutils kubectl helm smartmontools nvme-cli \
                    python3-openstackclient python3-pip python3-virtualenv blackbox-terminal fprintd

sudo dnf remove --allowerasing rhythmbox mediawriter \
                gnome-logs gnome-maps gnome-tour gnome-weather \
                gnome-disk-utility gnome-system-monitor gnome-contacts gnome-terminal \
                gnome-remote-desktop gnome-boxes gnome-connections totem-video-thumbnailer

pip3 install -U chromaterm certbot certbot-dns-cloudflare

flatpak install -y flathub \
        com.spotify.Client \
        org.telegram.desktop \
        com.getpostman.Postman \
        com.github.tenderowl.frog \
        com.mattjakeman.ExtensionManager \
        com.github.IsmaelMartinez.teams_for_linux

sudo sed -i 's/^# set tabsize 8/set tabsize 2/' /etc/nanorc
sudo sed -i 's/^# set tabstospaces/set tabstospaces/' /etc/nanorc

## Gnome Extension ##
#Windows is Ready - Notification Remover
#Status Area Horizontal Spacing
#Notification Banner Reloaded
#Hide Activities Button
#Removable Drive Menu
#Net speed Simplified
#Frippery Move Clock
#Clipboard Indicator
#Blur my Shell
#Media Control
