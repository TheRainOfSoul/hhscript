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
