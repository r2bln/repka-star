PREFIX      ?= /usr/bin
SYSTEMD_DIR ?= /etc/systemd/system
BUILD_DIR   := build

MMDVM_DIR := $(BUILD_DIR)/MMDVMHost
DMR_DIR   := $(BUILD_DIR)/DMRGateway

MMDVM_REPO := https://github.com/g4klx/MMDVMHost
DMR_REPO   := https://github.com/g4klx/DMRGateway

XLX_HOST := qra-team.online

.PHONY: all deps build install configs services xlxhosts check-config restart backup clean uninstall check-root

all: build

deps:
	apt-get update
	apt-get install -y cmake make g++ git libsamplerate-dev nlohmann-json3-dev

$(MMDVM_DIR):
	git clone --depth 1 $(MMDVM_REPO) $(MMDVM_DIR)

$(DMR_DIR):
	git clone --depth 1 $(DMR_REPO) $(DMR_DIR)

$(MMDVM_DIR)/MMDVM-Host: $(MMDVM_DIR)
	$(MAKE) -C $(MMDVM_DIR)

$(DMR_DIR)/DMRGateway: $(DMR_DIR)
	$(MAKE) -C $(DMR_DIR)

build: $(MMDVM_DIR)/MMDVM-Host $(DMR_DIR)/DMRGateway

check-root:
	@if [ "$$(id -u)" != "0" ]; then echo "must be run as root" >&2; exit 1; fi

install: check-root build
	install -m 755 $(MMDVM_DIR)/MMDVM-Host $(PREFIX)/mmdvmhost
	install -m 755 $(DMR_DIR)/DMRGateway $(PREFIX)/dmrgateway

configs: check-root
	install -d /etc/MMDVMHost /etc/DMRGateway /var/log/MMDVMHost /var/log/DMRGateway
	cp -n mmdvmhost.cfg /etc/MMDVMHost/mmdvmhost.cfg
	cp -n dmrgateway.cfg /etc/DMRGateway/dmrgateway.cfg
	wget --quiet -N -P /etc/MMDVMHost https://github.com/krot4u/Public_scripts/raw/master/DMRIds.dat
	wget --quiet -N -P /etc/MMDVMHost https://raw.githubusercontent.com/g4klx/MMDVMHost/master/RSSI/RSSI_GM340_DEIv1.1.dat

xlxhosts: check-root
	ip=$$(getent hosts $(XLX_HOST) | awk '{print $$1}' | head -n1); \
	if [ -z "$$ip" ]; then echo "failed to resolve $(XLX_HOST)" >&2; exit 1; fi; \
	printf '# This XLXHosts.txt is fake and contains only QRA Team XLX server\n496;%s;4001\n' "$$ip" > /etc/DMRGateway/XLXHosts.txt

check-config:
	@if grep -qr -- '--[a-z_]*--' /etc/MMDVMHost/mmdvmhost.cfg /etc/DMRGateway/dmrgateway.cfg; then \
		echo "placeholders (--callsign--, --dmrid--, --freq--, ...) are still unfilled in /etc/MMDVMHost/mmdvmhost.cfg or /etc/DMRGateway/dmrgateway.cfg" >&2; \
		exit 1; \
	fi

services: check-root
	ln -sf $(CURDIR)/mmdvmhost.service $(SYSTEMD_DIR)/mmdvmhost.service
	ln -sf $(CURDIR)/dmrgateway.service $(SYSTEMD_DIR)/dmrgateway.service
	systemctl daemon-reload
	@echo
	@echo "systemd-юниты созданы (симлинки в $(SYSTEMD_DIR)), сервисы НЕ включены и НЕ запущены."
	@-$(MAKE) --no-print-directory check-config
	@echo "Перед запуском отредактируйте конфиги:"
	@echo "  /etc/MMDVMHost/mmdvmhost.cfg"
	@echo "  /etc/DMRGateway/dmrgateway.cfg"
	@echo "После чего включите и запустите сервисы вручную:"
	@echo "  systemctl enable --now mmdvmhost.service dmrgateway.service"

restart: check-root
	systemctl restart dmrgateway.service mmdvmhost.service

backup: check-root
	cp /etc/DMRGateway/dmrgateway.cfg dmrgateway.cfg.bak
	cp /etc/MMDVMHost/mmdvmhost.cfg mmdvmhost.cfg.bak

uninstall: check-root
	systemctl disable --now mmdvmhost.service dmrgateway.service || true
	rm -f $(SYSTEMD_DIR)/mmdvmhost.service $(SYSTEMD_DIR)/dmrgateway.service
	systemctl daemon-reload
	rm -f $(PREFIX)/mmdvmhost $(PREFIX)/dmrgateway

clean:
	rm -rf $(BUILD_DIR)
