# RPK-5: Тоггл BrandMeister / QRA XLX в веб-интерфейсе

Сейчас переключение между BrandMeister и QRA-team XLX (`[DMR Network 1]`/`[XLX Network]` в `dmrgateway.cfg`, логика уже есть в `bot/cmd/bot.go`: `setMode`/`getMode`) доступно только через телеграм-бота, который пока не задеплоен (см. `tasks/RPK-3.md`). Нужен тот же переключатель прямо в `web/`.

## Решение

- В `web/cmd/web.go` добавлен `GET/POST /api/mode`:
  - `GET` — читает `[XLX Network] Enabled` и `[DMR Network 1] Enabled` из `dmrgateway.cfg` (тот же файл, что уже зарегистрирован в `configFiles` под id `dmrgateway`), определяет режим (`bm`/`qra`/`unknown`, если оба или ни один не включены), возвращает вместе со статусом `dmrgateway.service`.
  - `POST {"mode":"bm"|"qra"}` — выставляет пару `Enabled` (взаимоисключающе, как в `bot.go`), сохраняет `dmrgateway.cfg` через `ini.v1` (`PrettyFormat=false`, как и остальной код), рестартует `dmrgateway.service`, возвращает актуальный режим и статус.
  - Не заводили отдельный флаг/таблицу под dmrgateway — переиспользуется существующий `findConfigFile("dmrgateway")`, чтобы путь к файлу и имя сервиса не дублировались.
- Фронтенд (`static/index.html` + `static/app.js`): на вкладке «Конфиги» сверху — карточка «Режим DMRGateway» с двумя кнопками (BrandMeister / QRA-XLX, активная — сплошная, вторая — outline, как в остальном интерфейсе) и лампочкой статуса сервиса. Опрашивается раз в 5с (`loadMode`, отдельно от существующего `pollStatus`, т.к. отдаёт другую форму данных). После переключения режима форма конфигов (`loadConfigs()`) перечитывается с диска — иначе открытая форма редактирования `DMRGateway` показывала бы устаревшие значения `Enabled` и могла бы затереть их при следующем «Сохранить».
- Поведение при ошибке рестарта — как у существующей кнопки «Перезапустить»: конфиг уже записан на диск к моменту вызова `systemctl restart`, поэтому если рестарт не удался, файл всё равно отражает выбранный режим, а пользователю показывается текст ошибки.

Проверено локально: сборка (`go build`, `go vet`, `gofmt -l` чисто) и end-to-end через curl на копии реального `dmrgateway.cfg` — `GET /api/mode` корректно определяет `bm` из `Enabled=1/0`, `POST` с `qra`/`bm` меняет пару значений на диск (проверено grep'ом секций до/после), `POST` с невалидным `mode` — `400`. Рестарт `dmrgateway.service` на деве закономерно фейлится (`Unit dmrgateway.service not found` — юнит не установлен на дев-машине), это ожидаемо и не отличается от уже имеющегося поведения `/api/restart/{id}`.

Задеплоено на реальную Repka Pi (`repka-pi` в tailscale, `192.168.1.70` в LAN): `git push` + `git pull` + `make build/repka-web` + `make install` + `systemctl restart web.service` (только web, `mmdvmhost`/`dmrgateway` не трогали — их бинари не менялись).

## Known issues

Нет открытых. Ниже — закрытый инцидент.

### [Resolved] Переключение в QRA/XLX через новый тоггл уронило dmrgateway на реальном устройстве

При первой живой проверке тоггла (пользователь нажал «QRA / XLX» в веб-интерфейсе) `dmrgateway.service` ушёл в `failed` (`Start request repeated too quickly`, `StartLimitBurst` исчерпан за секунды).

Причина — не в самом тоггле: конфиг переключился верно (`[XLX Network] Enabled=1`, `[DMR Network 1] Enabled=0`), но на устройстве никогда не запускался `make xlxhosts` — отдельный таргет Makefile, который резолвит `qra-team.online` и пишет `/etc/DMRGateway/XLXHosts.txt`. Файла не было, DMRGateway логировал `Loaded 0 XLX reflectors` и тут же падал с exit 1 — раньше это было незаметно, потому что XLX ни разу не включали на этом устройстве с момента `make install`.

Фикс:
1. Немедленно на устройстве: `make xlxhosts` (создал `/etc/DMRGateway/XLXHosts.txt`) → `systemctl reset-failed dmrgateway.service` → `systemctl restart dmrgateway.service`. Подтверждено логами: `Logged into the master successfully`, `Linking to reflector XLX496 A`. `GET /api/mode` → `{"mode":"qra","status":"active"}`.
2. В репозитории: `xlxhosts` добавлен в зависимости таргета `install` (`install: check-root build configs xlxhosts services`), чтобы `XLXHosts.txt` создавался при любом `make install`, а не только вручную по памяти — иначе тот же баг повторится на любом новом устройстве RPK-4 или после `make uninstall`+переустановки.

Вывод на будущее: раз тоггл BM/QRA стал доступен из веба (а не только через недеплоенного бота), нужно чтобы все предпосылки для обоих режимов (в т.ч. `XLXHosts.txt`) закрывались самим `make install`, а не оставались скрытым ручным шагом — иначе включение «второй», реже используемой ветки конфига через UI будет неожиданно ронять живой сервис.
