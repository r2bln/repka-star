#!/usr/bin/bash

rm -rf tmp
mkdir tmp
cd tmp

wget --quiet -P /etc/ https://www.pistar.uk/downloads/XLXHosts.txt
wget --quiet -P /etc/ https://github.com/krot4u/Public_scripts/raw/master/DMRIds.dat
wget --quiet -P /etc/ https://raw.githubusercontent.com/g4klx/MMDVMHost/master/RSSI/RSSI_GM340_DEIv1.1.dat