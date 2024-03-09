# Что в этом репозитории
Здесь зафиксирован путь боли и преодолений по запуску DMR Хотспота на базе [MMDVMHost](https://github.com/g4klx/MMDVMHost) и [DMRGateway](https://github.com/g4klx/DMRGateway) на российском аналоге RaspberryPi - [RepkaPi](https://repka-pi.ru/)

Возможно позже появится автоматизация.

Пока просто заметки. 

![repka-star](./files/IMG_20240309_122749_cut.jpg)
# Железки
- MMDVM_HS_HAT c [Aliexpress](https://aliexpress.ru/item/32915442246.html?spm=a2g2w.orderdetail.0.0.48e84aa6vTCf5Q&sku_id=12000024784954883)
- [Repka Pi 3](https://repka-pi.ru/) v. 1.3 2Gb

# Инструкция
## Конфигурируем Репку
Предполагаем что вы накатили на Репку [родную операционную систему](https://repka-pi.ru/#operation-system-anchor), она запустилась и вы получили доступ в терминал.
Распиновка GPIO по у молчанию у Репки отличается и выглядит [так](https://repka-pi.ru/#periphery_block) но с помощью поставляемой вместе с ОС утилиты `repka-config` её можно поменять. Нам нужен вариант 2.
## Прошиваем модем
Возможно модем с Алиэкспресса уже приходит прошитым - я не знал как это проверить и поэтому занялся прошивкой. Но проверить это можно. Статья в [этом блоге](https://www.mmdvm.club/index.php/archives/249/) говорит что **прошитый модем мигает красным светодиодом с интервалом в 1 секунду**. Что похоже на правду. Или наверняка - прочитать прошивку и посмотреть что внутри.

Для того чтобы прошить модем или прочитать его прошивку нужно перевести его в режим прошивки по UART. Для этого необходимо в определенной последовательности переключить состояние определённых GPIO пинов (20 и 21). `stm32flash` поидее может сделать это и сама но файлы за которые надо дергать GPIO у репки расположены в других местах так что выхода 2 - хачить исходники `stm32flash` либо перемапить пины с помощью библиотеки и шить 2 команды. Я выбрал последнее.
#### Устанавливаем stm32flash
Эта штука просто есть в репозитории - качаем
```bash
sudo apt install stm32flash
```
#### Устанавливаем библиотеку для работы с GPIO
Для совместимости с Raspberry Pi Репке нужно переключать пины программным способом. Ставим зависимости
```bash
sudo apt update
sudo apt install python3-dev python3-setuptools git
```
Качаем [бибилиотеку](https://gitflic.ru/project/repka_pi/repkapigpiofs)
```bash
git clone https://gitflic.ru/project/repka_pi/repkapigpiofs.git
```
Устанавливаем
```bash
cd repkapigpiofs
sudo python3 setup.py install
```
Далее либо пишем сами либо запускаем [скрипт](repka-hat.py) из этого репозитория
```bash
root@Repka-Pi:~/sources/repka-star# python3 repka-hat.py enter
Repka Pi 3
enter bootloader mode
```
Это переведет модем в режим прошивки и тогда можно будет посмотреть данные о нём
```bash
root@Repka-Pi:~/sources/repka-star# stm32flash /dev/ttyS0
stm32flash 0.5

http://stm32flash.sourceforge.net/

Interface serial_posix: 57600 8E1
Version      : 0x10
Option 1     : 0x00
Option 2     : 0x00
Device ID    : 0x0410 (STM32F10xxx Medium-density)
- RAM        : 20KiB  (512b reserved by bootloader)
- Flash      : 128KiB (size first sector: 4x1024)
- Option RAM : 16b
- System RAM : 2KiB
```
Читаем прошивку в файл
```bash
root@Repka-Pi:~/sources/repka-star# stm32flash -r dump.bin /dev/ttyS0
stm32flash 0.5

http://stm32flash.sourceforge.net/

Interface serial_posix: 57600 8E1
Version      : 0x10
Option 1     : 0x00
Option 2     : 0x00
Device ID    : 0x0410 (STM32F10xxx Medium-density)
- RAM        : 20KiB  (512b reserved by bootloader)
- Flash      : 128KiB (size first sector: 4x1024)
- Option RAM : 16b
- System RAM : 2KiB
Memory read
Read address 0x08020000 (100.00%) Done.
```
Смотрим есть ли в ней чтонибудь про MMDVM
```bash
root@Repka-Pi:~/sources/repka-star# strings dump.bin | grep -i mmdvm
MMDVM_HS FW configuration:
MMDVM_HS_Hat-v1.5.2 20201108 14.7456MHz ADF7021 FW by CA6JAU GitID #89daa20
```
Если да - то шить ничего не надо, если нет то надо шить. Можно сделать с тем же скриптом с командой `flash`
```bash
 python3 repka-hat.py flash
```
Он делает следующее
1. Качает прошивку из https://github.com/juribeparada/MMDVM_HS/
2. Перетыкает GPIO пины так же как и `enter` чтобы попасть в режим прошивки
3. Запускает `stm32flash` заливает скачанную прошивку
4. Перетыкает GPIO пины для выхода из режима прошивки и перезапускает модем ``
## Собираем софт
Клонируем репозитории [MMDVMHost](https://github.com/g4klx/MMDVMHost) и [DMRGateway](https://github.com/g4klx/DMRGateway) и собираем - у обоих в описании есть инструкция, но по сути оно водится к запуску `make` и оно всё собирается. Получаем на выходе 2 бинаря.
## Конфигурируем софт
Качаем репозиторий с публичными скриптами [QRA-Team](https://5973.ru/) https://github.com/krot4u/Public_scripts 
Запускаем скрипт `configure-pistar.sh` 
Скрипт отработает частично - спросит нас DMR Id, желаемую частоту и сломается. Но сможет создать два файла конфигурации
```
/etc/dmrgateway
/etc/mmdvmhost
```
Эти конфиги можно открыть и подрихтовать под себя. Я например поменял пути для некоторых справочников, добавил свой позывной который почему-то не прописался
```
[DMR Id Lookup]
File=/root/sources/Public_scripts/DMRIds.dat
Time=6

...

[Modem]
...
RSSIMappingFile=/root/sources/Public_scripts/RSSI_GM340_DEIv1.1.dat
```

RSSI_GM340_DEIv1.1.dat я взял тут https://github.com/g4klx/MMDVMHost/blob/master/RSSI/RSSI_GM340_DEIv1.1.dat
## Запускаем
Никакого [pistar](https://www.pistar.uk/) на Repka Pi не предвидется как минимум потому что исходников в открытом доступе нет, так что будем запускать руками. Для этого удобно использовать [tmux](https://ru.wikipedia.org/wiki/Tmux)

- создаю дополнительный терминал через `Ctrl+b+c`
- перехожу в новый терминал `Ctrl+b+1`
- делю его пвертикали `Ctrl+b+%`
- справа (`Ctrl+b+->`) запускаю `./DMRGateway /etc/dmrgateway`
- слева  (`Ctrl+b+<-`) `./MMDVMHost /etc/mmdvmhost`
- и детачусь через `Ctrl+B+D`

Как-то так
![tmux](./files/tmux.png)
# Выводы

1. Сделать хотспот на Repka Pi можно - **всё работает**
2. Установку и запуск автоматизировать несложно - надо просто заюзать скрипты [QRA-Team](https://5973.ru/) немного их подрихтовав
3. Компилировать программы [MMDVMHost](https://github.com/g4klx/MMDVMHost) и [DMRGateway](https://github.com/g4klx/DMRGateway) самостоятельно необязательно можно собрать и распространять уже готовые бинари
4. Запуск тоже несложно демонизировать - через system.d файлы
5. Единственная проблема - конфигурирование на лету через Web-интерфейс который предоставляет pistar - портировать его невозможно так как нет доступа к исходникам - остается только писать свой