#!/bin/sh

systemctl restart dmrgateway
systemctl restart mmdvmhost
cp /etc/DMRGateway/dmrgateway.cfg dmrgateway.cfg.bak
cp /etc/MMDVMHost/mmdvmhost.cfg mmdvmhost.cfg.bak 