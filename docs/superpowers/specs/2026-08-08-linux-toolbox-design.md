# HH Toolbox — Linux CLI + Windows URL — дизайн

## Цель
- Windows-тулбокс запускать через `irm win.hhtdom.ru | iex` (GUI-first + CLI-откат — уже есть).
- Новый Linux CLI-тулбокс для headless Debian/Ubuntu: `curl lin.hhtdom.ru | bash`.

## Решения (утверждено)
- **Дистрибутивы:** только Debian/Ubuntu (apt).
- **UI-бэкенд:** `gum` (красивый; скачивается бинарником, если нет) → чистый bash (fallback). Без whiptail. Абстракция `ui_*`.
- **Разделы:** установка пакетов (галочки), твики/настройка сервера (галочки), справочник команд (с описанием + запуск), инфо о системе + сеть.

## Критичные ограничения
- `curl … | bash` отдаёт скрипт в stdin → обычный `read` ломается. **Весь ввод — из `/dev/tty`.** gum/whiptail сами используют /dev/tty; plain-режим читает `< /dev/tty` явно.
- **LF-концы строк** обязательны (bash давится CRLF) — зеркало Windows-проблемы с BOM. `.gitattributes: *.sh eol=lf`, проверка в CI.
- Без глобального `set -e` (меню не должно падать на ненулевом коде). Привилегированные команды через `sudo` (пароль из /dev/tty), если не root.

## Архитектура linux.sh
- Слой UI: `ui_menu / ui_checklist / ui_yesno / ui_input / ui_msg / ui_run`. Только они зовут gum/whiptail/plain.
- `ensure_ui`: gum если есть; иначе попытка скачать бинарник gum (GitHub, по арх.); иначе plain (чистый bash).
- Разделы — отдельные функции `sec_sysinfo / sec_install / sec_tweaks / sec_commands`; главный цикл `main`.
- Твики — по функции на каждый (`tw_update`, `tw_ufw`, `tw_fail2ban`, `tw_unattended`, `tw_timezone`, `tw_swap`, `tw_hostname`, `tw_bbr`, `tw_ssh_harden`). Разрушительные — с подтверждением; SSH-хардненинг — с явным предупреждением о риске локаута.

## Доставка (Cloudflare, настраивает пользователь)
- `win.hhtdom.ru` → menu.ps1 (единственный Windows-домен; `get.hhtdom.ru` не используется). В коде `$LauncherUrl = 'https://win.hhtdom.ru'`.
- `lin.hhtdom.ru` → raw `linux.sh`.

## Тесты / CI
- `bash -n linux.sh` (синтаксис) + `shellcheck linux.sh` (линт) + проверка «нет CRLF».
- Функциональный прогон (apt/gum/tty) — только на реальном Debian/Ubuntu (не воспроизвести на Windows-CI).

## Вне области v1
- Не-apt дистрибутивы (RHEL/Arch/SUSE). GUI для Linux. Специфичные стеки (кроме Docker/nginx как пакетов).

## v1.1 — расширение (утверждено)
Четыре новых раздела главного меню, всё на тех же `ui_*` / `/dev/tty` / `sudo` / `ensure_pkg`:
- **Диагностика сети:** пинг-скан подсети, скан камер/NVR по CCTV-портам, проверка RTSP (`/dev/tcp` + опц. `ffprobe`), `mtr`, `iperf3` (сервер `-1`/клиент), `speedtest`.
- **Docker и сервисы:** установка через `get.docker.com`; деплой галочками Portainer (docker run), Nginx Proxy Manager (compose в `/opt/npm`), Watchtower.
- **WireGuard VPN:** сервер `wg0` (сеть `10.66.66.0/24`, NAT через PostUp/PostDown iptables, IP-forward, автозапуск), добавление клиента с QR (`qrencode -t ansiutf8`); ключ сервера и endpoint хранятся в комментариях `wg0.conf`.
- **Пользователи и доступ:** `adduser --disabled-password` + `passwd` (скрытый ввод с /dev/tty) + группа sudo; SSH-ключ в `authorized_keys`; смена порта SSH (сначала `ufw allow`, затем рестарт, предупреждение о локауте); бэкап `rsync`+`cron` (идемпотентно по маркеру).

Тестирование: bash -n + shellcheck + навигация в plain через pty на WSL. Docker/WireGuard/systemd/root-действия — только на реальном VPS.

## v1.2 — расширение (утверждено)
Ещё 6 фич, всё на тех же `ui_*` / `/dev/tty` / `sudo` / `ensure_pkg`:
- **Пользователи и доступ += Обратный SSH-туннель:** `autossh` в systemd-юните `hh-revssh-<name>` (`-M 0 -N -R remote:localhost:local`, автозапуск/реконнект, `User=$USER` — использует ключ пользователя к relay).
- **Новый раздел «Сеть и веб»:** статический IP через `netplan` (форма IP/маска/шлюз/DNS → `/etc/netplan/99-hh.yaml`, применение `netplan try`/`apply`, предупреждение о разрыве сессии); `certbot --nginx` (домены+email, предусловия).
- **Новый раздел «Обслуживание и мониторинг»:** чистка (`apt autoremove --purge`/`clean`, `journalctl --vacuum-time=7d`, опц. `docker system prune -af`) с отчётом свободного места; `netdata` через официальный kickstart (`--disable-telemetry`, опц. UFW 19999); просмотрщик SSH-логов и `fail2ban` (последние входы, неудачные попытки, забаненные, разбан).

Тест v1.2: bash -n + shellcheck (чисто) + навигация по всем новым меню в plain через pty. netplan/certbot/autossh/netdata — VPS-only.

## v1.3 — управление сервером (утверждено)
Цель: закрыть базовое администрирование, ради которого сейчас всё равно уходишь в голую консоль. Главное меню 10 → 12 пунктов; фаервол и cron/логи вписаны в существующие разделы, чтобы меню не расползалось.
- **Новый раздел «Службы и процессы»:** список юнитов (running / failed / enabled / поиск по имени); общий пикер `svc_pick` (фильтр → `ui_menu` до 30 юнитов, имя в stdout, `ui_msg`/`pause` внутри принудительно в `/dev/tty` — иначе сообщение попадёт в подстановку команды); управление юнитом (start/stop/restart/enable/disable + статус в шапке цикла, подтверждение при остановке `ssh*`); `journalctl -u`; «кто занял порт» (`ss -tulnp` + `lsof -i`); завершение процесса по имени (`pgrep -a -f`) или PID с запретом PID 1 и предупреждением про `sshd`/`systemd`, эскалация до `kill -9`; топ по CPU/памяти.
- **Новый раздел «Диски и хранилище»:** обзор (`lsblk` + `df -hT` + `df -i` + `blkid`); SMART через `smartmontools` (`-H -i`, ключевые атрибуты грепом, `-t short`, `-l selftest`); монтирование (кандидаты = `lsblk -pn -e 7,11 -o PATH,SIZE,FSTYPE,MOUNTPOINT | awk 'NF==3'`, т.е. с ФС и без точки монтирования) с записью в `/etc/fstab` по UUID и `nofail`, бэкапом `/etc/fstab.hh.bak` и откатом, если `mount -a` вернул ошибку; отмонтирование (`NF==4`, исключены `/`, `/boot*` и `[SWAP]`), при занятости — `fuser -vm`/`lsof +D`; форматирование (`wipefs` + `parted mklabel gpt mkpart` + `mkfs.ext4`) с тройной защитой: тип устройства должен быть `disk`, системный диск (через `findmnt -no SOURCE /` → `lsblk -no PKNAME`) и диски со смонтированными разделами отклоняются, подтверждение — ввод точного имени устройства, не y/n; анализ места (`ncdu` или `du`+`find` топами); Samba-шара (дописывание секции в `smb.conf`, `smbpasswd -a/-e`, проверка `testparm`, `ufw allow samba`) и NFS-экспорт (`/etc/exports`, `exportfs -ra`, `ufw allow nfs`).
- **«Сеть и веб» += Фаервол UFW:** правила с номерами, открыть порт (без суффикса — считается `/tcp`), удалить правило по номеру, разрешить IP, вкл/выкл, сброс к минимуму (deny incoming + allow outgoing + SSH). Текущий порт SSH определяется общим хелпером `ssh_port()` (его же переиспользует `usr_sshport`) и служит защитой от самоблокировки: предупреждение при удалении SSH-правила, автодобавление правила перед включением фаервола.
- **«Обслуживание и мониторинг» += Задачи (cron):** просмотр `crontab` root и пользователя + `/etc/cron.d`; добавление задачи по шаблону (5 мин / час / день / неделя / своя строка) в crontab root; удаление по номеру (нумеруются только непустые не-комментарии, удаление по точному совпадению строки `grep -vxF`).
- **«Обслуживание и мониторинг» += Журналы:** последние ошибки (`-p err`), лог службы (через `svc_pick`), `dmesg -T`, поиск по журналу, `--disk-usage` + `--vacuum-size=200M`.

Тест v1.3: shellcheck чисто (вывод в файл через `--format=gcc` — консоль Windows давится на «—»), `bash -n`, LF, наличие всех 21 функции-обработчика через `declare -F`, навигация по новым меню в plain через pty, живой прогон read-only функций в WSL с `SUDO=""` и `page(){ cat; }`. SMART/format/fstab/Samba/NFS/UFW — VPS-only.
