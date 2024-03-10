#!/usr/bin/bash

rm -rf tmp
mkdir tmp
cd tmp

echo 'Installing deps'
apt install -y ripgrep cmake make g++ git libsamplerate-dev python3-dev python3-setuptools

echo 'Cloning software'
git clone https://github.com/g4klx/MMDVMHost
git clone https://github.com/g4klx/DMRGateway

echo 'Building software'
cd MMDVMHost
make
cp MMDVMHost ../mmdvmhost
cd ../DMRGateway
make 
cp DMRGateway ../dmrgateway
cd ../

echo 'Downloading configs'
wget --quiet -P /etc/ https://github.com/krot4u/Public_scripts/raw/master/DMRIds.dat
wget --quiet -P /etc/ https://raw.githubusercontent.com/g4klx/MMDVMHost/master/RSSI/RSSI_GM340_DEIv1.1.dat

echo 'Geting QRA Team XLX server ip:'
ip=$(host qra-team.online | rg -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")

echo 'Generate fake XLXHosts.txt'
rm -f /etc/XLXHosts.txt

echo "# This XLXHosts.txt is fake and contains only QRA Team XLX server" >> /etc/XLXHosts.txt
echo "496;$ip;4001" >> /etc/XLXHosts.txt