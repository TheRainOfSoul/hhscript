# HH Script — универсальный лаунчер

Меню для PowerShell, которое запускается одной короткой командой, скачивается
**в оперативку** (на диск ничего не пишется) и позволяет запускать MAS, WinUtil,
Win11Debloat, ставить программы и гонять свои скрипты.

## Запуск

Через домен (после настройки Cloudflare):

```powershell
irm get.hhtdom.ru | iex
```

Напрямую через GitHub (работает сразу):

```powershell
irm https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/menu.ps1 | iex
```

## Состав меню

- **Система:** Информация о ПК · MAS (активация) · Лёгкая чистка
  (удаление лишних приложений + TEMP + DNS) · Базовые твики
  (расширения файлов, тёмная тема, классическое меню Win11) ·
  **Сетевые утилиты** (ipconfig, ping/tracert, смена DNS на 1.1.1.1 / 8.8.8.8 /
  авто, сброс сети) — всё inline, без тяжёлых внешних утилит. Чистка и твики —
  с выбором пунктов **галочками** (↑/↓ навигация, Пробел — отметить, A — все,
  Enter — применить, Esc — отмена; резервный режим — ввод номеров)
- **Программы:** подменю установки **галочками** — Chrome, 7-Zip, VLC,
  qBittorrent, AnyDesk, Advanced IP Scanner, Winbox (MikroTik), Speedtest CLI,
  CrystalDiskInfo, HWiNFO, OCCT, FurMark, CrystalDiskMark
  (через `winget`) + Dahua ConfigTool и SmartPSS Lite (открываются
  официальной страницей загрузки). Отдельный пункт **«Обновить весь софт»** (`winget upgrade --all`)
- **[8] Программы для админа / Help Desk** — отдельный чек-лист бесплатных
  инструментов (CLI+GUI): Sysinternals Suite, mRemoteNG, PuTTY, WinSCP, MobaXterm,
  TightVNC, Nmap, Wireshark, Angry IP Scanner, Everything, WizTree, Rufus, Ventoy,
  Malwarebytes, KeePassXC, PowerShell 7, Windows Terminal, Notepad++ (через `winget`).
- **[9] Библиотеки и среды выполнения** — чек-лист runtime (по умолчанию всё
  отмечено): Visual C++ Redist (все 2005-2022, x86+x64), .NET Desktop Runtime 8/6,
  .NET Framework 3.5 (DISM), DirectX, Edge WebView2, Windows App Runtime,
  Java Temurin JRE 8/17. Требует прав администратора ([A]).
- **[13] Обновление драйверов** — определяет производителя и ставит драйверы из
  **официального источника** (без Windows Update): Dell → Dell Command Update
  (dcu-cli), HP → HP Image Assistant (HPIA), Lenovo → Thin Installer,
  Intel-платы → Intel DSA, AMD/прочее → официальная страница вендора.
  Требует прав администратора ([A]).
- **[12] Проверка/восстановление системы** — `DISM /RestoreHealth` + `sfc /scannow`
  (починка системных файлов). Требует прав администратора ([A]).
- **[4] Стресс-тест ПК** — отдельный скрипт `scripts/stresstest.ps1`: встроенный
  CPU-прожиг (100% всех ядер на N минут, чистый PowerShell) + запуск OCCT /
  FurMark / CrystalDiskMark / HWiNFO. Запускается и сам по себе через `irm`.
- **[15] Новый ПК** — первичная настройка чистой машины одной кнопкой: ставит
  Chrome / 7-Zip / AnyDesk, выносит иконку «Этот компьютер» на рабочий стол,
  отключает виджеты и обновляет драйверы (та же логика, что **[13]**).
  **Без Windows Update.** Требует прав администратора ([A]).
- **[3] Калькулятор диска для камер (модель Dahua)** — считает как официальный
  калькулятор Dahua, в обе стороны: *сколько диска нужно на N дней* ↔ *на сколько
  дней хватит диска*. Битрейт в Kbps или по разрешению+кодеку (H.264/H.265/H.265+),
  показывает Bandwidth. Числа совпадают с калькулятором Dahua (686.7 ГБ / 44 дня
  на их эталоне).
- **[7] Утилиты** — WinUtil (Chris Titus), Win11Debloat (Raphire), SophiApp (GUI),
  Sophia Script (PowerShell): debloat и твики известными инструментами.
- Перезапуск от имени администратора, выход

## Как менять под себя

- **Программы** — правь массив `$Programs` в начале `menu.ps1`
  (`Winget` = id пакета, `Url` = запасная ссылка для браузера).
- **Свои скрипты** — клади `.ps1` в `scripts/`, добавляй пункты в меню.
- **Короткая ссылка** — после настройки домена впиши её в `$LauncherUrl`.

## Как устроено

`irm` качает текст скрипта в память → `iex` его выполняет. Каждый пункт меню
делает такой же `irm <url> | iex`. На диск ничего не пишется, поэтому
ExecutionPolicy не мешает; права админа нужны только конкретным инструментам.
