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

# make install OLED=1 — дополнительно собрать и поставить вывод на OLED-дисплей (SSD1306, I2C):
# mosquitto (MQTT-брокер), MMDVM-Info и MMDVM-Display с библиотекой ArduiPi_OLED
OLED ?= 0

OLED_LIB_REPO := https://github.com/hallard/ArduiPi_OLED
DISPLAY_REPO  := https://github.com/g4klx/MMDVM-Display
INFO_REPO     := https://github.com/g4klx/MMDVM-Info

OLED_LIB_DIR := $(BUILD_DIR)/ArduiPi_OLED
DISPLAY_DIR  := $(BUILD_DIR)/MMDVM-Display
INFO_DIR     := $(BUILD_DIR)/MMDVM-Info
OLED_LIB     := $(OLED_LIB_DIR)/libArduiPi_OLED.a

JOBS ?= $(shell n=$$(nproc); j=$$((n * 2 / 3)); [ $$j -ge 1 ] && echo $$j || echo 1)

.PHONY: all deps build install configs services xlxhosts check-config restart backup clean uninstall check-root install-oled

all: build

deps: .deps-stamp
ifeq ($(OLED),1)
deps: .deps-oled-stamp
endif

.deps-stamp:
	@if [ "$$(id -u)" != "0" ]; then echo "must be run as root" >&2; exit 1; fi
	apt-get update
	apt-get install -y cmake make g++ git nlohmann-json3-dev libmosquitto-dev golang-go
	touch .deps-stamp

.deps-oled-stamp:
	@if [ "$$(id -u)" != "0" ]; then echo "must be run as root" >&2; exit 1; fi
	apt-get update
	apt-get install -y mosquitto mosquitto-clients i2c-tools
	touch .deps-oled-stamp

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

# OLED: ArduiPi_OLED из апстрима привязана к регистрам Raspberry Pi (bcm2835), поэтому вместо
# её bcm2835.{c,h} подкладываем oled/bcm2835.{c,h} — тот же API поверх /dev/i2c-N.
# Библиотека собирается статически и линкуется в MMDVM-Display, ставить её в систему не нужно.
$(OLED_LIB_DIR):
	git clone --depth 1 $(OLED_LIB_REPO) $(OLED_LIB_DIR)

$(OLED_LIB): oled/bcm2835.c oled/bcm2835.h | $(OLED_LIB_DIR)
	cp oled/bcm2835.c oled/bcm2835.h $(OLED_LIB_DIR)/
	cd $(OLED_LIB_DIR) && rm -f *.o $(notdir $(OLED_LIB)) \
		&& $(CXX) -O2 -fno-rtti -c ArduiPi_OLED.cpp Adafruit_GFX.cpp \
		&& $(CC) -O2 -c bcm2835.c \
		&& ar rcs $(notdir $(OLED_LIB)) ArduiPi_OLED.o Adafruit_GFX.o bcm2835.o

$(DISPLAY_DIR):
	git clone --depth 1 $(DISPLAY_REPO) $(DISPLAY_DIR)

$(INFO_DIR):
	git clone --depth 1 $(INFO_REPO) $(INFO_DIR)

# OLED-драйвер выводит температуру захардкоженно как "NNF / NNC" и игнорирует TemperatureInF —
# оставляем только градусы Цельсия. Если апстрим поменяет строку, sed просто ничего не найдёт.
$(DISPLAY_DIR)/.celsius: | $(DISPLAY_DIR)
	sed -i 's|"Temp: %.0fF / %.0fC ", m_tempF, m_tempC|"Temp: %.0fC ", m_tempC|' $(DISPLAY_DIR)/OLED.cpp
	touch $@

$(DISPLAY_DIR)/MMDVM-Display: $(OLED_LIB) $(DISPLAY_DIR)/.celsius | $(DISPLAY_DIR)
	$(MAKE) -C $(DISPLAY_DIR) -j$(JOBS) MMDVM-Display \
		CFLAGS="-g -O3 -Wall -std=c++11 -MMD -MD -pthread -DUSE_OLED -I$(CURDIR)/$(OLED_LIB_DIR)" \
		LIBS="-lArduiPi_OLED -lpthread -lutil -lmosquitto" \
		LDFLAGS="-g -L$(CURDIR)/$(OLED_LIB_DIR)"

$(INFO_DIR)/MMDVM-Info: | $(INFO_DIR)
	$(MAKE) -C $(INFO_DIR) -j$(JOBS)

OLED_BINS :=
ifeq ($(OLED),1)
OLED_BINS := $(DISPLAY_DIR)/MMDVM-Display $(INFO_DIR)/MMDVM-Info
endif

build: deps $(MMDVM_DIR)/MMDVM-Host $(DMR_DIR)/DMRGateway $(WEB_BIN) $(OLED_BINS)

check-root:
	@if [ "$$(id -u)" != "0" ]; then echo "must be run as root" >&2; exit 1; fi

install: check-root build configs xlxhosts services
	install -m 755 $(MMDVM_DIR)/MMDVM-Host $(PREFIX)/mmdvmhost
	install -m 755 $(DMR_DIR)/DMRGateway $(PREFIX)/dmrgateway
	install -m 755 $(WEB_BIN) $(PREFIX)/repka-web
ifeq ($(OLED),1)
	$(MAKE) --no-print-directory install-oled
endif
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

install-oled: check-root
	install -m 755 $(DISPLAY_DIR)/MMDVM-Display $(PREFIX)/mmdvm-display
	install -m 755 $(INFO_DIR)/MMDVM-Info $(PREFIX)/mmdvm-info
	install -d /etc/MMDVMHost
	cp -n mmdvm-display.ini /etc/MMDVMHost/mmdvm-display.ini
	cp -n mmdvm-info.ini /etc/MMDVMHost/mmdvm-info.ini
	@# MMDVM-Display слушает топик "host", а MMDVMHost по умолчанию публикует под "mmdvm"
	@if [ -f /etc/MMDVMHost/mmdvmhost.cfg ] && ! grep -q '^\[MQTT\]' /etc/MMDVMHost/mmdvmhost.cfg; then \
		printf '\n[MQTT]\nName=host\n' >> /etc/MMDVMHost/mmdvmhost.cfg; \
		echo "добавил [MQTT] Name=host в /etc/MMDVMHost/mmdvmhost.cfg"; \
	fi
	ln -sf $(CURDIR)/mmdvm-display.service $(SYSTEMD_DIR)/mmdvm-display.service
	ln -sf $(CURDIR)/mmdvm-info.service $(SYSTEMD_DIR)/mmdvm-info.service
	systemctl daemon-reload
	@echo "OLED: включите сервисы: systemctl enable --now mosquitto mmdvm-info mmdvm-display (и рестарт mmdvmhost)"

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
	-systemctl disable --now mmdvm-display.service mmdvm-info.service
	rm -f $(SYSTEMD_DIR)/mmdvm-display.service $(SYSTEMD_DIR)/mmdvm-info.service $(PREFIX)/mmdvm-display $(PREFIX)/mmdvm-info
	systemctl daemon-reload

clean:
	rm -rf $(BUILD_DIR) .deps-stamp .deps-oled-stamp
