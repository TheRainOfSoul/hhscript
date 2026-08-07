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
- `win.hhtdom.ru` → тот же контент, что `get.hhtdom.ru` (menu.ps1). В коде `$LauncherUrl = 'https://win.hhtdom.ru'`.
- `lin.hhtdom.ru` → raw `linux.sh`.

## Тесты / CI
- `bash -n linux.sh` (синтаксис) + `shellcheck linux.sh` (линт) + проверка «нет CRLF».
- Функциональный прогон (apt/gum/tty) — только на реальном Debian/Ubuntu (не воспроизвести на Windows-CI).

## Вне области v1
- Не-apt дистрибутивы (RHEL/Arch/SUSE). GUI для Linux. Специфичные стеки (кроме Docker/nginx как пакетов).
