/*
 * Реализация подмножества bcm2835 API поверх linux i2c-dev; см. bcm2835.h.
 *
 * Шина выбирается переменной окружения OLED_I2C_DEV (по умолчанию /dev/i2c-1),
 * адрес устройства ставит сама библиотека через bcm2835_i2c_setSlaveAddress().
 */
#include "bcm2835.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static int i2c_fd = -1;

int bcm2835_init(void)
{
	return 1;
}

int bcm2835_close(void)
{
	return 1;
}

int bcm2835_i2c_begin(void)
{
	const char *dev = getenv("OLED_I2C_DEV");
	if (dev == NULL || *dev == '\0')
		dev = "/dev/i2c-1";

	i2c_fd = open(dev, O_RDWR);
	if (i2c_fd < 0) {
		fprintf(stderr, "OLED: cannot open %s: %s\n", dev, strerror(errno));
		return 0;
	}

	return 1;
}

void bcm2835_i2c_end(void)
{
	if (i2c_fd >= 0)
		close(i2c_fd);
	i2c_fd = -1;
}

int bcm2835_i2c_setSlaveAddress(uint8_t addr)
{
	if (i2c_fd < 0)
		return -1;
	return ioctl(i2c_fd, I2C_SLAVE, addr);
}

void bcm2835_i2c_set_baudrate(uint32_t baudrate)
{
	(void)baudrate; /* скорость шины задаётся device tree, не приложением */
}

/* 0 = успех — как BCM2835_I2C_REASON_OK в оригинале. */
int bcm2835_i2c_write(const char *buf, uint32_t len)
{
	if (i2c_fd < 0)
		return 1;
	return write(i2c_fd, buf, len) == (ssize_t)len ? 0 : 1;
}

void bcm2835_gpio_fsel(uint8_t pin, uint8_t mode)   { (void)pin; (void)mode; }
void bcm2835_gpio_write(uint8_t pin, uint8_t on)    { (void)pin; (void)on; }

void    bcm2835_spi_begin(uint8_t cs)               { (void)cs; }
void    bcm2835_spi_end(void)                       { }
void    bcm2835_spi_setBitOrder(uint8_t order)      { (void)order; }
void    bcm2835_spi_setClockDivider(uint16_t d)     { (void)d; }
void    bcm2835_spi_setDataMode(uint8_t mode)       { (void)mode; }
uint8_t bcm2835_spi_transfer(uint8_t value)         { (void)value; return 0; }
void    bcm2835_spi_writenb(char *buf, uint32_t len){ (void)buf; (void)len; }
