#!/usr/bin/env bash
# HH Toolbox — macOS (полевой набор техника)
# Запуск:  curl mac.hhtdom.ru | bash
# UI: нативные окна macOS через osascript (AppleScript). Навигация и ввод — в
# окошках; вывод команд (сканы, ffprobe) идёт в Терминал. Без окон (SSH) —
# текстовый режим. Пишем под bash 3.2: /bin/bash в macOS древний.

VERSION="1.0"
LOG="${HOME:-/tmp}/.hhtoolbox.log"

# журнал действий: время + сообщение в ~/.hhtoolbox.log
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null || true; }

# --- только bash и только macOS -------------------------------------------
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Запусти через bash:  curl mac.hhtdom.ru | bash" >&2
  exit 1
fi
if [ "$(uname)" != "Darwin" ]; then
  echo "Это скрипт для macOS. Для Linux — lin.hhtdom.ru, для Windows — win.hhtdom.ru" >&2
  exit 1
fi

trap 'printf "\n"; exit 130' INT

read_tty() { IFS= read -r "$@" </dev/tty; }

pause() {
  printf '\nНажми Enter для продолжения...' >/dev/tty
  read_tty _ 2>/dev/null || true
}

# ===========================================================================
# UI-СЛОЙ: osascript (нативные окна) или plain (текст)
# ===========================================================================
UI=plain

# экранируем строку для вставки внутрь двойных кавычек AppleScript
osa_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# собрать AppleScript-список: "a", "b", "c"
osa_list() {
  local out="" a
  for a in "$@"; do
    if [ -n "$out" ]; then out="$out, "; fi
    out="$out\"$(osa_esc "$a")\""
  done
  printf '%s' "$out"
}

ensure_ui() {
  case "${HH_UI:-}" in
    plain) UI=plain; return ;;
    osa)   UI=osa;   return ;;
  esac
  # по SSH нет оконного сервера — окна не покажутся, идём в текст
  if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then UI=plain; return; fi
  if command -v osascript >/dev/null 2>&1 && osascript -e 'return 0' >/dev/null 2>&1; then
    UI=osa
  else
    UI=plain
  fi
}

# ui_msg TEXT...   — информационная строка (всегда в Терминал, без окна)
ui_msg() { printf '\n'; printf '%s\n' "$@"; }

# ui_alert TEXT... — важное сообщение: окно с OK (osa) или текст + пауза (plain)
ui_alert() {
  local text="$*"
  if [ "$UI" = osa ]; then
    osascript >/dev/null 2>&1 <<OSA || true
display dialog "$(osa_esc "$text")" with title "HH Toolbox" buttons {"OK"} default button "OK"
OSA
    return 0
  fi
  printf '\n%s\n' "$text"
  pause
}

# ui_yesno PROMPT  — 0 = да
ui_yesno() {
  local prompt=$1 ans
  if [ "$UI" = osa ]; then
    ans=$(osascript 2>/dev/null <<OSA
set r to display dialog "$(osa_esc "$prompt")" with title "HH Toolbox" buttons {"Нет","Да"} default button "Да" cancel button "Нет"
return button returned of r
OSA
)
    if [ "$ans" = "Да" ]; then return 0; else return 1; fi
  fi
  printf '%s [y/N]: ' "$prompt" >/dev/tty
  read_tty ans || return 1
  case "$ans" in y|Y|yes|Yes|да|Да) return 0 ;; *) return 1 ;; esac
}

# ui_input PROMPT [DEFAULT]  — строка в stdout (пусто = отмена)
ui_input() {
  local prompt=$1 def=${2:-} ans
  if [ "$UI" = osa ]; then
    ans=$(osascript 2>/dev/null <<OSA
set r to display dialog "$(osa_esc "$prompt")" default answer "$(osa_esc "$def")" with title "HH Toolbox" buttons {"Отмена","OK"} default button "OK" cancel button "Отмена"
return text returned of r
OSA
) || return 1
    printf '%s' "$ans"
    return 0
  fi
  if [ -n "$def" ]; then printf '%s [%s]: ' "$prompt" "$def" >/dev/tty
  else printf '%s: ' "$prompt" >/dev/tty; fi
  read_tty ans || ans=""
  [ -z "$ans" ] && ans="$def"
  printf '%s' "$ans"
}

# ui_menu TITLE OPT...  — один выбор в stdout (пусто = отмена)
ui_menu() {
  local title=$1; shift
  if [ "$UI" = osa ]; then
    local lst; lst=$(osa_list "$@")
    osascript 2>/dev/null <<OSA
set r to choose from list {$lst} with title "HH Toolbox" with prompt "$(osa_esc "$title")" OK button name "Выбрать" cancel button name "Отмена"
if r is false then return ""
return item 1 of r
OSA
    return 0
  fi
  local opts=("$@") i choice
  {
    printf '\n== %s ==\n' "$title"
    for i in "${!opts[@]}"; do printf '  %2d) %s\n' "$((i+1))" "${opts[$i]}"; done
    printf '  Выбор [1-%d]: ' "${#opts[@]}"
  } >/dev/tty
  read_tty choice || return 1
  case "$choice" in ''|*[!0-9]*) return 1 ;; esac
  if [ "$choice" -ge 1 ] && [ "$choice" -le "${#opts[@]}" ]; then
    printf '%s\n' "${opts[$((choice-1))]}"
  else
    return 1
  fi
}

# ui_checklist TITLE "tag|label"...  — выбранные tag'и в stdout (по строке)
ui_checklist() {
  local title=$1; shift
  local pairs=("$@") labels=() p i
  for p in "${pairs[@]}"; do labels+=("${p#*|}"); done
  if [ "$UI" = osa ]; then
    local lst sel line
    lst=$(osa_list "${labels[@]}")
    sel=$(osascript 2>/dev/null <<OSA
set r to choose from list {$lst} with title "HH Toolbox" with prompt "$(osa_esc "$title")" with multiple selections allowed OK button name "Установить" cancel button name "Отмена"
if r is false then return ""
set AppleScript's text item delimiters to linefeed
return r as text
OSA
)
    [ -n "$sel" ] || return 1
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      for p in "${pairs[@]}"; do
        if [ "${p#*|}" = "$line" ]; then printf '%s\n' "${p%%|*}"; break; fi
      done
    done <<< "$sel"
    return 0
  fi
  # plain: переключение номерами
  local n=${#pairs[@]} state=() line tok mark
  for ((i=0;i<n;i++)); do state[i]=0; done
  while :; do
    {
      printf '\n== %s ==\n' "$title"
      for ((i=0;i<n;i++)); do
        mark=' '; [ "${state[i]}" = 1 ] && mark='x'
        printf '  [%s] %2d) %s\n' "$mark" "$((i+1))" "${pairs[i]#*|}"
      done
      printf '  Номера через пробел, a — все, Enter — применить, q — отмена\n  > '
    } >/dev/tty
    read_tty line || return 1
    case "$line" in
      q|Q) return 1 ;;
      '') break ;;
      a|A) for ((i=0;i<n;i++)); do state[i]=1; done ;;
      *) for tok in $line; do
           if [[ $tok =~ ^[0-9]+$ ]] && [ "$tok" -ge 1 ] && [ "$tok" -le "$n" ]; then
             state[tok-1]=$(( 1 - state[tok-1] ))
           fi
         done ;;
    esac
  done
  for ((i=0;i<n;i++)); do [ "${state[i]}" = 1 ] && printf '%s\n' "${pairs[i]%%|*}"; done
}

# ===========================================================================
# ДАННЫЕ
# ===========================================================================

# утилиты Homebrew:  "формула|описание"
BREW_ITEMS=(
  "htop|htop — монитор процессов"
  "btop|btop — красивый монитор ресурсов"
  "nmap|nmap — сканер портов и сети"
  "ffmpeg|ffmpeg + ffprobe (проверка RTSP-потоков камер)"
  "wireshark|wireshark / tshark — анализ трафика"
  "tmux|tmux — сессии терминала"
  "mtr|mtr — трасса с потерями"
  "iperf3|iperf3 — замер скорости между узлами"
  "arp-scan|arp-scan — поиск устройств в LAN по MAC (камеры, NVR)"
  "jq|jq — обработка JSON"
  "wget|wget — загрузка файлов"
)

# GUI-приложения Homebrew Cask:  "cask|описание"
CASK_ITEMS=(
  "google-chrome|Google Chrome — браузер"
  "firefox|Firefox — браузер"
  "anydesk|AnyDesk — удалённый доступ"
  "rustdesk|RustDesk — удалённый доступ (open-source)"
  "teamviewer|TeamViewer — удалённый доступ"
  "vlc|VLC — плеер (RTSP/видео)"
  "wireshark|Wireshark — анализ трафика (GUI)"
  "the-unarchiver|The Unarchiver — распаковка архивов"
  "keka|Keka — архиватор"
  "appcleaner|AppCleaner — полное удаление программ"
  "telegram|Telegram — мессенджер"
  "zoom|Zoom — видеосвязь"
)

# Office для Mac (.pkg):  "label|url|файл|kind"
#   kind=ms — прямая ссылка Microsoft (fwlink -> .pkg)
#   kind=ya — публичная ссылка Яндекс.Диска (имя берём из API)
OFFICE_ITEMS=(
  "Office 365 (весь пакет)|https://go.microsoft.com/fwlink/p/?linkid=2009112|Microsoft_Office.pkg|ms"
  "Word|https://go.microsoft.com/fwlink/p/?linkid=525134|Microsoft_Word.pkg|ms"
  "Excel|https://go.microsoft.com/fwlink/p/?linkid=525135|Microsoft_Excel.pkg|ms"
  "PowerPoint|https://go.microsoft.com/fwlink/p/?linkid=525136|Microsoft_PowerPoint.pkg|ms"
  "Outlook|https://go.microsoft.com/fwlink/p/?linkid=525137|Microsoft_Outlook.pkg|ms"
  "Сброс Office (reset)|https://disk.yandex.ru/d/tfFI9m-HfgDb0g||ya"
  "Сериализатор (Volume License)|https://disk.yandex.ru/d/7ke9FErmY_77BQ||ya"
)

# ===========================================================================
# ХЕЛПЕРЫ macOS
# ===========================================================================

mac_default_iface() { route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'; }

mac_ip() {
  local i=${1:-}
  [ -n "$i" ] || i=$(mac_default_iface)
  [ -n "$i" ] && ipconfig getifaddr "$i" 2>/dev/null
}

mac_gw() { route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}'; }

mac_dns() { scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3}' | awk '!s[$0]++' | paste -sd', ' -; }

ext_ip() { curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null; }

# Яндекс.Диск: прямая ссылка на скачивание по публичному URL (свежая, без токена)
yadisk_href() {
  curl -s -G "https://cloud-api.yandex.net/v1/disk/public/resources/download" --data-urlencode "public_key=$1" \
    | sed -n 's/.*"href":"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g'
}

# Яндекс.Диск: имя файла по публичному URL
yadisk_name() {
  curl -s -G "https://cloud-api.yandex.net/v1/disk/public/resources" --data-urlencode "public_key=$1" \
    | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//; s/"$//'
}

# текущая подсеть /24 для сканов по умолчанию
default_cidr() {
  local ip; ip=$(mac_ip)
  [ -n "$ip" ] && printf '%s.0/24' "$(printf '%s' "$ip" | cut -d. -f1-3)"
}

host_name() { scutil --get ComputerName 2>/dev/null || hostname; }

# строка отчёта Network Doctor: ok/bad/warn + подпись + деталь
dl() {
  local m=""
  case "$1" in ok) m='[OK]' ;; bad) m='[!!]' ;; warn) m='[~]' ;; esac
  printf '  %-4s %s\n' "$m" "$2"
  [ -n "${3:-}" ] && printf '        %s\n' "$3"
  return 0
}

# ===========================================================================
# РАЗДЕЛЫ
# ===========================================================================

sec_sysinfo() {
  local osn osv bld model cpu cores mem_b mem_g disk up
  osn=$(sw_vers -productName 2>/dev/null)
  osv=$(sw_vers -productVersion 2>/dev/null)
  bld=$(sw_vers -buildVersion 2>/dev/null)
  model=$(sysctl -n hw.model 2>/dev/null)
  cpu=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  [ -n "$cpu" ] || cpu="$model"
  cores=$(sysctl -n hw.ncpu 2>/dev/null)
  mem_b=$(sysctl -n hw.memsize 2>/dev/null)
  if [ -n "$mem_b" ]; then mem_g="$(( mem_b / 1024 / 1024 / 1024 )) ГБ"; else mem_g="н/д"; fi
  disk=$(df -h / | awk 'NR==2{print $3" / "$2" ("$5")"}')
  up=$(uptime | sed 's/^ *//')
  {
    printf '\n=== Информация о системе ===\n\n'
    printf 'ОС:      %s %s (%s)\n' "$osn" "$osv" "$bld"
    printf 'Модель:  %s\n' "$model"
    printf 'Хост:    %s\n' "$(host_name)"
    printf 'CPU:     %s  (%s ядер)\n' "$cpu" "$cores"
    printf 'Память:  %s\n' "$mem_g"
    printf 'Диск /:  %s\n' "$disk"
    printf 'Аптайм:  %s\n' "$up"
  }
  pause
}

sec_netinfo() {
  local dev ip gw dns pub
  dev=$(mac_default_iface)
  ip=$(mac_ip "$dev")
  gw=$(mac_gw)
  dns=$(mac_dns)
  pub=$(ext_ip); [ -n "$pub" ] || pub="н/д"
  {
    printf '\n=== Информация о сети ===\n\n'
    printf 'Интерфейс:   %s\n' "${dev:-н/д}"
    printf 'IP-адрес:    %s\n' "${ip:-н/д}"
    printf 'Шлюз:        %s\n' "${gw:-н/д}"
    printf 'DNS:         %s\n' "${dns:-н/д}"
    printf 'Внешний IP:  %s\n' "$pub"
    printf '\nИнтерфейсы (с IP):\n'
    ifconfig 2>/dev/null | awk '
      /^[a-z0-9]+:/ { iface=$1; sub(":","",iface) }
      /status: active/ { act[iface]=1 }
      /inet / { ipa[iface]=$2 }
      END { for (i in ipa) if (i != "lo0") printf "  %-8s %s%s\n", i, ipa[i], (act[i] ? " (active)" : "") }'
    printf '\nСлушающие порты:\n'
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{print "  "$1"  "$9}' | sort -u | head -n 25
  }
  pause
}

# Network Doctor: read-only батарея проверок «почему не работает сеть» + вердикт
nd_doctor() {
  local verdict='' dev gw ip dns pub o loss ipdead=0 gwok=0 netok=0 tgt
  printf '\n=== Network Doctor — диагностика сети ===\n\n'

  dev=$(mac_default_iface)
  if [ -z "$dev" ]; then
    dl bad "Нет активного интерфейса" "Кабель/Wi-Fi не подключены."
    ui_alert "Нет сетевого подключения — нет активного интерфейса."
    return
  fi
  if ifconfig "$dev" 2>/dev/null | grep -q 'status: active'; then
    dl ok "Интерфейс активен" "$dev"
  else
    dl ok "Интерфейс с маршрутом по умолчанию" "$dev"
  fi

  ip=$(mac_ip "$dev"); gw=$(mac_gw); dns=$(mac_dns)
  if [ -z "$ip" ]; then
    dl bad "Нет IPv4-адреса" "Интерфейс активен, но адрес не назначен."
    verdict="Нет IP — DHCP не выдал. Проверь DHCP на роутере или задай статику."; ipdead=1
  elif printf '%s' "$ip" | grep -q '^169\.254\.'; then
    dl bad "APIPA-адрес $ip" "DHCP не ответил (169.254.x.x)."
    verdict="ПК не получил IP от DHCP. Проверь кабель до роутера / DHCP-сервер."; ipdead=1
  else
    dl ok "IPv4: $ip" "Шлюз: ${gw:-нет}; DNS: ${dns:-нет}"
  fi

  if [ -n "$gw" ] && [ "$ipdead" = 0 ]; then
    if o=$(ping -c3 -t3 "$gw" 2>/dev/null); then
      gwok=1; loss=$(printf '%s' "$o" | grep -oE '[0-9.]+% packet loss' | head -1)
      dl ok "Шлюз $gw отвечает" "$loss"
    else
      dl bad "Шлюз $gw не отвечает" "Роутер/локальная сеть недоступны."
      verdict="Шлюз недоступен — проблема в локальной сети или роутере."
    fi
  fi

  if [ "$ipdead" = 0 ]; then
    for tgt in 1.1.1.1 8.8.8.8; do
      if o=$(ping -c3 -t3 "$tgt" 2>/dev/null); then
        netok=1; loss=$(printf '%s' "$o" | grep -oE '[0-9.]+% packet loss' | head -1)
        dl ok "Интернет доступен ($tgt)" "$loss"; break
      fi
    done
    if [ "$netok" = 0 ]; then
      dl bad "Интернет недоступен (ICMP)" "Пинг до 1.1.1.1 и 8.8.8.8 не прошёл."
      [ "$gwok" = 1 ] && verdict="Локальная сеть ок, но нет выхода в интернет — провайдер/роутер (WAN)."
    fi
  fi

  if [ "$ipdead" = 0 ]; then
    if dscacheutil -q host -a name cloudflare.com 2>/dev/null | grep -q 'ip_address'; then
      dl ok "DNS резолвит имена" "cloudflare.com → адрес получен."
    else
      dl bad "DNS не резолвит имена" "Имена сайтов не преобразуются в адреса."
      [ "$netok" = 1 ] && verdict="Интернет есть, но DNS не работает — смени DNS на 1.1.1.1 / 8.8.8.8."
    fi
  fi

  if [ "$netok" = 1 ]; then
    pub=$(ext_ip)
    [ -n "$pub" ] && dl ok "Внешний IP: $pub" "Полный доступ к интернету подтверждён."
  fi

  printf '\n'
  if [ -n "$verdict" ]; then
    printf '  Итог: %s\n' "$verdict"
    ui_alert "Итог диагностики:

$verdict"
  else
    printf '  → Сеть работает нормально.\n'
    ui_alert "Сеть работает нормально: интерфейс, IP, шлюз, интернет и DNS в порядке."
  fi
  pause
}

# Homebrew: убедиться что есть, при отказе вернуть 1
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then return 0; fi
  if ! ui_yesno "Homebrew не найден. Установить его сейчас? (несколько минут, спросит пароль)"; then
    return 1
  fi
  printf '\nУстанавливаю Homebrew...\n'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  command -v brew >/dev/null 2>&1
}

# общий установщик через brew: $1 = "" (формула) или "--cask", $2 = заголовок,
# далее — пункты "tag|описание"
brew_install_from() {
  local flag=$1 title=$2; shift 2
  if ! ensure_brew; then ui_msg "Homebrew нужен для установки."; pause; return; fi
  local sel tags=() t
  sel=$(ui_checklist "$title" "$@") || { ui_msg "Ничего не выбрано."; return; }
  while IFS= read -r t; do [ -n "$t" ] && tags+=("$t"); done <<< "$sel"
  if [ "${#tags[@]}" -eq 0 ]; then ui_msg "Ничего не выбрано."; return; fi
  if ! ui_yesno "Установить: ${tags[*]}?"; then return; fi
  log "brew install $flag: ${tags[*]}"
  for t in "${tags[@]}"; do
    printf '\n==> brew install %s %s\n' "$flag" "$t"
    if [ -n "$flag" ]; then brew install "$flag" "$t"; else brew install "$t"; fi
  done
  ui_alert "Готово. Установлено: ${tags[*]}"
  pause
}

sec_install() { brew_install_from "" "Утилиты (Homebrew) — отметь нужное" "${BREW_ITEMS[@]}"; }
sec_apps()    { brew_install_from "--cask" "Приложения (GUI) — отметь нужное" "${CASK_ITEMS[@]}"; }

# нативный спидтест macOS 12+ (ставить ничего не нужно)
nd_speedtest() {
  if ! command -v networkQuality >/dev/null 2>&1; then
    ui_alert "networkQuality есть только в macOS 12 (Monterey) и новее. Обнови систему."
    return
  fi
  printf '\nЗамер скорости интернета (networkQuality)\nобычно 15-30 секунд, дождись результата...\n\n'
  networkQuality
  pause
}

# скачать один установщик Office (.pkg) и предложить открыть
office_download() {
  local label=$1 url=$2 file=$3 kind=$4 dl href name out dir
  dir="$HOME/Downloads"; mkdir -p "$dir"
  if [ "$kind" = ya ]; then
    ui_msg "Получаю ссылку с Яндекс.Диска для «$label»..."
    href=$(yadisk_href "$url")
    if [ -z "$href" ]; then ui_alert "Не удалось получить ссылку с Яндекс.Диска для «$label»."; return; fi
    name=$(yadisk_name "$url"); [ -n "$name" ] || name="${label}.pkg"
    out="$dir/$name"; dl="$href"
  else
    out="$dir/$file"; dl="$url"
  fi
  printf '\nСкачиваю «%s»\n  -> %s\n(большой файл, несколько минут)\n\n' "$label" "$out"
  if curl -fL --retry 2 -o "$out" "$dl"; then
    ui_msg "Готово: $out"
    if ui_yesno "Открыть установщик «$label» сейчас?"; then open "$out"; fi
  else
    ui_alert "Ошибка загрузки «$label»."
  fi
}

sec_office() {
  local labels=() it label url file kind pick
  while :; do
    labels=()
    for it in "${OFFICE_ITEMS[@]}"; do
      IFS='|' read -r label url file kind <<< "$it"
      labels+=("$label")
    done
    labels+=("← Назад")
    pick=$(ui_menu "Office для Mac — что скачать (.pkg)" "${labels[@]}") || return
    { [ -z "$pick" ] || [ "$pick" = "← Назад" ]; } && return
    for it in "${OFFICE_ITEMS[@]}"; do
      IFS='|' read -r label url file kind <<< "$it"
      if [ "$label" = "$pick" ]; then
        log "office: $label"
        office_download "$label" "$url" "$file" "$kind"
        break
      fi
    done
  done
}

nd_camscan() {
  if ! command -v nmap >/dev/null 2>&1; then
    if ui_yesno "Нужен nmap (через Homebrew). Установить сейчас?"; then
      if ! ensure_brew || ! brew install nmap; then ui_alert "Не удалось установить nmap."; return; fi
    else
      return
    fi
  fi
  local t; t=$(ui_input "Хост или подсеть (камера/NVR)" "$(default_cidr)"); [ -n "$t" ] || return
  printf '\nИщу камеры/NVR в %s\nпорты 80,443,554,8000,37777,34567,8899,88 ...\n\n' "$t"
  nmap -p 80,443,554,8000,37777,34567,8899,88 --open "$t" 2>&1
  pause
}

nd_rtsp() {
  local h port url
  h=$(ui_input "IP камеры" ""); [ -n "$h" ] || return
  port=$(ui_input "RTSP-порт" "554"); [ -n "$port" ] || return
  if nc -z -G 3 "$h" "$port" >/dev/null 2>&1; then
    ui_alert "Порт $h:$port ОТКРЫТ — RTSP слушает."
    if command -v ffprobe >/dev/null 2>&1; then
      url=$(ui_input "RTSP URL для ffprobe" "rtsp://$h:$port/"); [ -n "$url" ] || return
      printf '\n$ ffprobe %s\n\n' "$url"
      ffprobe -v error -rtsp_transport tcp -show_streams -of default=noprint_wrappers=1 "$url" 2>&1
      pause
    else
      ui_alert "Установи ffmpeg (в разделе установки) — тогда проверю сам поток: разрешение и кодек."
    fi
  else
    ui_alert "Порт $h:$port закрыт или недоступен."
  fi
}

# ===========================================================================
# ГЛАВНЫЙ ЦИКЛ
# ===========================================================================

main() {
  log "=== старт HH Toolbox macOS v$VERSION (пользователь $(id -un)) ==="
  ensure_ui
  if [ "$UI" = osa ]; then
    osascript -e 'display notification "Полевой набор техника" with title "HH Toolbox — macOS"' >/dev/null 2>&1 || true
  fi
  printf '\n========================================\n'
  printf '   HH Toolbox — macOS   ·   v%s\n' "$VERSION"
  printf '========================================\n'
  local pick
  while :; do
    pick=$(ui_menu "Главное меню — $(host_name)" \
      "Информация о системе" \
      "Информация о сети" \
      "Диагностика сети (Network Doctor)" \
      "Скорость интернета" \
      "Скан камер и NVR" \
      "Проверка RTSP-камеры" \
      "Установка утилит (Homebrew)" \
      "Приложения (GUI, Homebrew)" \
      "Office для Mac (загрузка)" \
      "Выход") || break
    [ -n "$pick" ] && [ "$pick" != "Выход" ] && log "раздел: $pick"
    case "$pick" in
      "Информация о системе")              sec_sysinfo ;;
      "Информация о сети")                 sec_netinfo ;;
      "Диагностика сети (Network Doctor)") nd_doctor ;;
      "Скорость интернета")                nd_speedtest ;;
      "Скан камер и NVR")                  nd_camscan ;;
      "Проверка RTSP-камеры")              nd_rtsp ;;
      "Установка утилит (Homebrew)")       sec_install ;;
      "Приложения (GUI, Homebrew)")        sec_apps ;;
      "Office для Mac (загрузка)")         sec_office ;;
      "Выход"|"") break ;;
    esac
  done
  printf 'Пока!\n'
}

# HH_NORUN=1 — только загрузить функции/данные (для тестов), не показывать меню
if [ -z "${HH_NORUN:-}" ]; then
  main "$@"
fi
