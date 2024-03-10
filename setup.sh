#!/usr/bin/bash

rm -rf tmp
mkdir tmp
cd tmp

echo 'Installing deps'
apt install -y ripgrep

echo 'Downloading configs'
wget --quiet -P /etc/ https://github.com/krot4u/Public_scripts/raw/master/DMRIds.dat
wget --quiet -P /etc/ https://raw.githubusercontent.com/g4klx/MMDVMHost/master/RSSI/RSSI_GM340_DEIv1.1.dat

echo 'Geting QRA Team XLX server ip:'
ip=$(host qra-team.online | rg -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")

echo 'Generate fake XLXHosts.txt'
rm -f /etc/XLXHosts.txt

echo "# This XLXHosts.txt is fake and contains only QRA Team XLX server" >> /etc/XLXHosts.txt
echo "496;$ip;4001" >> /etc/XLXHosts.txt

systemctl restart dmrgateway