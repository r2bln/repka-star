PREFIX      ?= /usr/bin
SYSTEMD_DIR ?= /etc/systemd/system
BUILD_DIR   := build

MMDVM_DIR := $(BUILD_DIR)/MMDVMHost
DMR_DIR   := $(BUILD_DIR)/DMRGateway
WEB_DIR   := web
WEB_BIN   := $(BUILD_DIR)/repka-web

MMDVM_REPO := https://github.com/g4klx/MMDVMHost
DMR_REPO   := https://github.com/g4klx/DMRGateway

WEB_SRCS := $(shell find $(WEB_DIR) -type f \( -name '*.go' -o -path '*/static/*' \) 2>/dev/null)

XLX_HOST := qra-team.online

JOBS ?= $(shell n=$$(nproc); j=$$((n * 2 / 3)); [ $$j -ge 1 ] && echo $$j || echo 1)

.PHONY: all deps build install configs services xlxhosts check-config restart backup clean uninstall check-root

all: build

deps: .deps-stamp

.deps-stamp:
	@if [ "$$(id -u)" != "0" ]; then echo "must be run as root" >&2; exit 1; fi
	apt-get update
	apt-get install -y cmake make g++ git nlohmann-json3-dev libmosquitto-dev golang-go
	touch .deps-stamp

$(MMDVM_DIR):
	git clone --depth 1 $(MMDVM_REPO) $(MMDVM_DIR)

$(DMR_DIR):
	git clone --depth 1 $(DMR_REPO) $(DMR_DIR)

$(MMDVM_DIR)/MMDVM-Host: $(MMDVM_DIR)
	$(MAKE) -C $(MMDVM_DIR) -j$(JOBS)

$(DMR_DIR)/DMRGateway: $(DMR_DIR)
	$(MAKE) -C $(DMR_DIR) -j$(JOBS)

$(WEB_BIN): $(WEB_SRCS) | deps
	mkdir -p $(BUILD_DIR)
	cd $(WEB_DIR) && go build -o $(CURDIR)/$(WEB_BIN) ./cmd

build: deps $(MMDVM_DIR)/MMDVM-Host $(DMR_DIR)/DMRGateway $(WEB_BIN)

check-root:
	@if [ "$$(id -u)" != "0" ]; then echo "must be run as root" >&2; exit 1; fi

install: check-root build configs xlxhosts services
	install -m 755 $(MMDVM_DIR)/MMDVM-Host $(PREFIX)/mmdvmhost
	install -m 755 $(DMR_DIR)/DMRGateway $(PREFIX)/dmrgateway
	install -m 755 $(WEB_BIN) $(PREFIX)/repka-web
	@echo
	@echo "Установка завершена: бинари в $(PREFIX), конфиги в /etc/MMDVMHost и /etc/DMRGateway,"
	@echo "systemd-юниты symlink'нуты в $(SYSTEMD_DIR) (сервисы НЕ включены и НЕ запущены)."
	@-$(MAKE) --no-print-directory check-config
	@echo "Перед запуском отредактируйте конфиги:"
	@echo "  /etc/MMDVMHost/mmdvmhost.cfg"
	@echo "  /etc/DMRGateway/dmrgateway.cfg"
	@echo "После чего включите и запустите сервисы вручную:"
	@echo "  systemctl enable --now mmdvmhost.service dmrgateway.service web.service"
	@echo "Веб-интерфейс (без авторизации и https, слушает на всех интерфейсах): http://<host>:8080"

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
	ln -sf $(CURDIR)/web.service $(SYSTEMD_DIR)/web.service
	systemctl daemon-reload

restart: check-root
	systemctl restart dmrgateway.service mmdvmhost.service web.service

backup: check-root
	cp /etc/DMRGateway/dmrgateway.cfg dmrgateway.cfg.bak
	cp /etc/MMDVMHost/mmdvmhost.cfg mmdvmhost.cfg.bak

uninstall: check-root
	systemctl disable --now mmdvmhost.service dmrgateway.service web.service || true
	rm -f $(SYSTEMD_DIR)/mmdvmhost.service $(SYSTEMD_DIR)/dmrgateway.service $(SYSTEMD_DIR)/web.service
	systemctl daemon-reload
	rm -f $(PREFIX)/mmdvmhost $(PREFIX)/dmrgateway $(PREFIX)/repka-web

clean:
	rm -rf $(BUILD_DIR) .deps-stamp
