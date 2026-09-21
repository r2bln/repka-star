/*
 * Минимальная замена bcm2835.h для сборки hallard/ArduiPi_OLED на плате без
 * Broadcom BCM2835 (Repka Pi 3 — Allwinner H3).
 *
 * Оригинальная библиотека ходит в регистры Raspberry Pi через /dev/mem;
 * здесь те же функции реализованы поверх ядерного /dev/i2c-N (bcm2835.c).
 * Поддержан только I2C — SPI и GPIO-пины (reset) заглушены: у SSD1306 на
 * MMDVM-шляпе линии reset нет.
 */
#ifndef BCM2835_H
#define BCM2835_H

#include <stdint.h>

#define HIGH 0x1
#define LOW  0x0

#define BCM2835_GPIO_FSEL_OUTP 0x01

/* Пины из ArduiPi_OLED_lib.h — используются только как числа-заглушки. */
#define RPI_V2_GPIO_P1_18 24
#define RPI_V2_GPIO_P1_22 25

#define BCM2835_SPI_CS0                  0
#define BCM2835_SPI_CS1                  1
#define BCM2835_SPI_BIT_ORDER_MSBFIRST   1
#define BCM2835_SPI_MODE0                0
#define BCM2835_SPI_CLOCK_DIVIDER_16     16

#ifdef __cplusplus
extern "C" {
#endif

int  bcm2835_init(void);
int  bcm2835_close(void);

int  bcm2835_i2c_begin(void);
void bcm2835_i2c_end(void);
int  bcm2835_i2c_setSlaveAddress(uint8_t addr);
void bcm2835_i2c_set_baudrate(uint32_t baudrate);
int  bcm2835_i2c_write(const char *buf, uint32_t len);

void bcm2835_gpio_fsel(uint8_t pin, uint8_t mode);
void bcm2835_gpio_write(uint8_t pin, uint8_t on);

void    bcm2835_spi_begin(uint8_t cs);
void    bcm2835_spi_end(void);
void    bcm2835_spi_setBitOrder(uint8_t order);
void    bcm2835_spi_setClockDivider(uint16_t divider);
void    bcm2835_spi_setDataMode(uint8_t mode);
uint8_t bcm2835_spi_transfer(uint8_t value);
void    bcm2835_spi_writenb(char *buf, uint32_t len);

#ifdef __cplusplus
}
#endif

#endif /* BCM2835_H */
