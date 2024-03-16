#!/usr/bin/bash

echo 'Cleanup'
rm -rf /var/log/DMRGateway
rm -rf /var/log/MMDVMHost
rm -rf /etc/DMRGateway
rm -rf /etc/MMDVMHost
rm -rf /usr/bin/dmrgateway
rm -rf /usr/bin/mmdvmhost
rm -rf /etc/systemd/system/mmdvmhost.service
rm -rf /etc/systemd/system/dmrgateway.service
rm -rf tmp
mkdir tmp
cd tmp

echo 'Installing deps'
apt install -y ripgrep cmake make g++ git libsamplerate-dev python3-dev python3-setuptools stm32flash

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
cd ../../

echo 'Setup directories for daemons'
mkdir /var/log/DMRGateway
mkdir /var/log/MMDVMHost
mkdir /etc/DMRGateway
mkdir /etc/MMDVMHost

echo 'Copy binaries and configs'
cp ./tmp/mmdvmhost /usr/bin
cp ./tmp/dmrgateway /usr/bin
cp mmdvmhost.cfg /etc/MMDVMHost
cp dmrgateway.cfg /etc/DMRGateway
cp mmdvmhost.service /etc/systemd/system/
cp dmrgateway.service /etc/systemd/system/

echo 'Downloading configs'
wget --quiet -P /etc/MMDVMHost https://github.com/krot4u/Public_scripts/raw/master/DMRIds.dat
wget --quiet -P /etc/MMDVMHost https://raw.githubusercontent.com/g4klx/MMDVMHost/master/RSSI/RSSI_GM340_DEIv1.1.dat

echo 'Geting QRA Team XLX server ip:'
ip=$(host qra-team.online | rg -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
echo $ip

echo 'Generate fake XLXHosts.txt'
rm -f /etc/DMRGateway/XLXHosts.txt

echo "# This XLXHosts.txt is fake and contains only QRA Team XLX server" >> /etc/DMRGateway/XLXHosts.txt
echo "496;$ip;4001" >> /etc/DMRGateway/XLXHosts.txt
