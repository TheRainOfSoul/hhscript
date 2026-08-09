#!/usr/bin/env bash
# HH Toolbox — Linux CLI (Debian/Ubuntu)
# Запуск:  curl lin.hhtdom.ru | bash
# UI: gum (красивый, скачивается при отсутствии) -> чистый bash.
# Весь ввод из /dev/tty, т.к. при "curl | bash" stdin занят самим скриптом.

VERSION="1.0"

# --- защита от sh и от неинтерактивного запуска ---------------------------
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Запусти через bash:  curl lin.hhtdom.ru | bash" >&2
  exit 1
fi

trap 'printf "\n"; exit 130' INT

require_tty() {
  if ! { [ -e /dev/tty ] && ( : </dev/tty ) 2>/dev/null; }; then
    echo "Нужен интерактивный терминал (/dev/tty недоступен)." >&2
    echo "Скачай и запусти:  curl -fsSL lin.hhtdom.ru -o hh.sh && bash hh.sh" >&2
    exit 1
  fi
}

require_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Скрипт рассчитан на Debian/Ubuntu (нужен apt-get)." >&2
    exit 1
  fi
}

# --- ввод/привилегии -------------------------------------------------------
read_tty() { IFS= read -r "$@" </dev/tty; }

SUDO=""
init_sudo() { [ "$(id -u)" -ne 0 ] && SUDO="sudo"; }

# fetch OUT URL  (OUT="-" -> в stdout)
fetch() {
  local out=$1 url=$2
  if command -v curl >/dev/null 2>&1; then
    if [ "$out" = "-" ]; then curl -fsSL "$url"; else curl -fsSL -o "$out" "$url"; fi
  elif command -v wget >/dev/null 2>&1; then
    if [ "$out" = "-" ]; then wget -qO- "$url"; else wget -qO "$out" "$url"; fi
  else
    return 1
  fi
}

# поставить пакет, если ещё нет
ensure_pkg() {
  local p=$1
  dpkg -s "$p" >/dev/null 2>&1 && return 0
  ui_msg "Ставлю пакет: $p"
  $SUDO apt-get update -qq && $SUDO apt-get install -y "$p"
}

# текущая подсеть в формате CIDR (напр. 192.168.1.50/24) — для сканов по умолчанию
default_cidr() {
  local dev
  dev=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  ip -o -f inet addr show "$dev" 2>/dev/null | awk '{print $4; exit}'
}

# пейджер для длинного вывода (читает stdin, клавиши less берёт с /dev/tty сам)
page() {
  if command -v less >/dev/null 2>&1; then less -RFX >/dev/tty; else cat >/dev/tty; fi
}

# --- UI-слой: gum или plain ------------------------------------------------
UI=plain
GUM=""

try_install_gum() {
  local arch tag ver url tmp bin
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    aarch64|arm64) arch=arm64  ;;
    armv7l|armv6l) arch=armv7  ;;
    *) return 1 ;;
  esac
  tag=$(fetch - https://api.github.com/repos/charmbracelet/gum/releases/latest 2>/dev/null \
        | grep -o '"tag_name":[^,]*' | head -1 | grep -o 'v[0-9][0-9.]*')
  [ -n "$tag" ] || return 1
  ver=${tag#v}
  url="https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${ver}_Linux_${arch}.tar.gz"
  tmp=$(mktemp -d) || return 1
  if ! fetch "$tmp/gum.tgz" "$url"; then rm -rf "$tmp"; return 1; fi
  if ! tar -xzf "$tmp/gum.tgz" -C "$tmp" 2>/dev/null; then rm -rf "$tmp"; return 1; fi
  bin=$(find "$tmp" -type f -name gum 2>/dev/null | head -1)
  [ -x "$bin" ] || { rm -rf "$tmp"; return 1; }
  GUM="$bin"
  return 0
}

ensure_ui() {
  # принудительный режим:  HH_UI=plain  или  HH_UI=gum
  case "${HH_UI:-}" in
    plain) UI=plain; return ;;
    gum)   command -v gum >/dev/null 2>&1 && { GUM=gum; UI=gum; return; } ;;
  esac
  if command -v gum >/dev/null 2>&1; then GUM=gum; UI=gum; return; fi
  printf 'Подгружаю красивый интерфейс (gum)...\n' >/dev/tty
  if try_install_gum; then UI=gum; return; fi
  printf 'gum недоступен — простой текстовый режим.\n' >/dev/tty
  UI=plain
}

# ui_msg TEXT...      — сообщение/заголовок
ui_msg() {
  if [ "$UI" = gum ]; then "$GUM" style --border rounded --padding "0 1" --border-foreground 212 "$@"
  else printf '\n'; printf '%s\n' "$@"; fi
}

# ui_yesno PROMPT     — 0 = да
ui_yesno() {
  local prompt=$1 a
  if [ "$UI" = gum ]; then "$GUM" confirm "$prompt"; return $?; fi
  printf '%s [y/N]: ' "$prompt" >/dev/tty
  read_tty a || return 1
  case "$a" in y|Y|yes|Yes|да|Да) return 0 ;; *) return 1 ;; esac
}

# ui_input PROMPT [DEFAULT]  — строка в stdout
ui_input() {
  local prompt=$1 def=${2:-} a
  if [ "$UI" = gum ]; then
    if [ -n "$def" ]; then "$GUM" input --header "$prompt" --value "$def"
    else "$GUM" input --header "$prompt"; fi
    return
  fi
  if [ -n "$def" ]; then printf '%s [%s]: ' "$prompt" "$def" >/dev/tty
  else printf '%s: ' "$prompt" >/dev/tty; fi
  read_tty a || a=""
  [ -z "$a" ] && a="$def"
  printf '%s' "$a"
}

# ui_menu TITLE OPT...  — один выбор в stdout
ui_menu() {
  local title=$1; shift
  if [ "$UI" = gum ]; then "$GUM" choose --header "$title" "$@"; return; fi
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
  local pairs=("$@") i
  if [ "$UI" = gum ]; then
    local labels=() tags=() pair sel l j
    for pair in "${pairs[@]}"; do tags+=("${pair%%|*}"); labels+=("${pair#*|}"); done
    sel=$("$GUM" choose --no-limit --header "$title" "${labels[@]}") || return 1
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      for j in "${!labels[@]}"; do
        [ "${labels[$j]}" = "$l" ] && { printf '%s\n' "${tags[$j]}"; break; }
      done
    done <<< "$sel"
    return
  fi
  # plain: переключение номерами
  local n=${#pairs[@]} state=() line tok lo hi
  for ((i=0;i<n;i++)); do state[i]=0; done
  while :; do
    {
      printf '\n== %s ==\n' "$title"
      for ((i=0;i<n;i++)); do
        local mark=' '; [ "${state[i]}" = 1 ] && mark='x'
        printf '  [%s] %2d) %s\n' "$mark" "$((i+1))" "${pairs[i]#*|}"
      done
      printf '  Номера через пробел — отметить/снять (диапазон 2-6), a — все, n — снять все\n'
      printf '  Enter — применить, q — отмена\n  > '
    } >/dev/tty
    read_tty line || return 1
    case "$line" in
      q|Q) return 1 ;;
      '') break ;;
      a|A) for ((i=0;i<n;i++)); do state[i]=1; done ;;
      n|N) for ((i=0;i<n;i++)); do state[i]=0; done ;;
      *)
        for tok in $line; do
          if [[ $tok == *-* ]]; then
            lo=${tok%-*}; hi=${tok#*-}
            [[ $lo =~ ^[0-9]+$ && $hi =~ ^[0-9]+$ ]] || continue
            for ((i=lo;i<=hi;i++)); do (( i>=1 && i<=n )) && state[i-1]=$(( 1 - state[i-1] )); done
          elif [[ $tok =~ ^[0-9]+$ ]]; then
            (( tok>=1 && tok<=n )) && state[tok-1]=$(( 1 - state[tok-1] ))
          fi
        done
        ;;
    esac
  done
  for ((i=0;i<n;i++)); do [ "${state[i]}" = 1 ] && printf '%s\n' "${pairs[i]%%|*}"; done
}

pause() {
  printf '\nНажми Enter для продолжения...' >/dev/tty
  read_tty _ 2>/dev/null || true
}

banner() {
  if [ "$UI" = gum ]; then
    "$GUM" style --border double --margin "1 0" --padding "0 3" --border-foreground 212 --align center \
      "HH Toolbox — Linux" "Debian/Ubuntu · v$VERSION"
  else
    printf '\n========================================\n'
    printf '   HH Toolbox — Linux   ·   v%s\n' "$VERSION"
    printf '========================================\n'
  fi
}

# ===========================================================================
# ДАННЫЕ
# ===========================================================================

# пакеты apt:  "пакет|описание"
APT_ITEMS=(
  "htop|htop — интерактивный монитор процессов"
  "btop|btop — красивый монитор ресурсов"
  "tmux|tmux — сохранение сессий терминала"
  "mc|Midnight Commander — файловый менеджер"
  "ncdu|ncdu — анализ занятого места на диске"
  "tree|tree — дерево каталогов"
  "git|git — контроль версий"
  "curl|curl — HTTP-клиент"
  "wget|wget — загрузка файлов"
  "net-tools|net-tools — ifconfig/netstat/route"
  "dnsutils|dnsutils — dig/nslookup"
  "nmap|nmap — сканер портов и сети"
  "iftop|iftop — трафик по соединениям"
  "iotop|iotop — нагрузка на диск по процессам"
  "unzip|unzip — распаковка zip"
  "rsync|rsync — синхронизация/копирование"
  "ufw|ufw — простой фаервол"
  "fail2ban|fail2ban — защита от брутфорса SSH"
  "docker.io|Docker — контейнеры"
  "nginx|nginx — веб-сервер / reverse proxy"
  "fzf|fzf — нечёткий поиск"
  "jq|jq — обработка JSON"
  "ffmpeg|ffmpeg — конвертация + ffprobe (проверка RTSP-потоков камер)"
  "v4l-utils|v4l-utils — работа с USB-камерами (v4l2)"
  "tcpdump|tcpdump — захват сетевого трафика"
  "traceroute|traceroute — трассировка маршрута"
  "whois|whois — сведения о домене/IP"
  "arp-scan|arp-scan — поиск устройств в LAN по MAC (камеры, NVR)"
  "vnstat|vnstat — учёт трафика по интерфейсам"
  "ethtool|ethtool — параметры сетевой карты (скорость/дуплекс)"
  "socat|socat — универсальный ретранслятор сокетов"
  "bat|bat — cat с подсветкой синтаксиса"
  "ripgrep|ripgrep (rg) — быстрый поиск по тексту/логам"
  "screen|screen — сохранение сессий терминала"
  "tldr|tldr — краткие примеры по командам"
  "lsof|lsof — кто держит файлы/порты"
)

# твики:  "tag|описание"  (функция tw_<tag>)
TWEAK_ITEMS=(
  "update|Обновить систему (apt update && upgrade)"
  "ufw|Фаервол UFW: разрешить SSH и включить"
  "fail2ban|Установить и включить fail2ban"
  "unattended|Автообновления безопасности"
  "timezone|Часовой пояс (по умолч. Asia/Yerevan)"
  "swap|Создать swap-файл"
  "hostname|Сменить имя хоста"
  "bbr|Ускорение сети TCP BBR"
  "ssh_harden|Усилить SSH (только по ключу) — риск локаута"
)

# справочник команд:  "описание@@команда"  (в командах есть | — потому @@)
CMDS=(
  "Открытые/слушающие порты@@ss -tulnp"
  "Топ процессов по CPU@@ps aux --sort=-%cpu | head -n 20"
  "Топ процессов по памяти@@ps aux --sort=-%mem | head -n 20"
  "Использование диска по ФС@@df -hT"
  "Крупнейшие папки здесь@@du -h --max-depth=1 . 2>/dev/null | sort -hr | head -n 20"
  "Блочные устройства@@lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE"
  "Активные сервисы systemd@@systemctl list-units --type=service --state=running --no-pager"
  "Ошибки в журнале (последние 50)@@journalctl -p err -n 50 --no-pager"
  "Кто в системе и последние входы@@{ echo '# сейчас:'; who; echo; echo '# входы:'; last -n 10; }"
  "Сетевые интерфейсы (кратко)@@ip -br a"
  "Таблица маршрутизации@@ip route"
  "Память@@free -h"
  "Аптайм и нагрузка@@uptime"
  "Версия ОС и ядра@@{ . /etc/os-release; echo \"\$PRETTY_NAME\"; uname -a; }"
)

# ===========================================================================
# РАЗДЕЛЫ
# ===========================================================================

sec_sysinfo() {
  local os kern up cpu cores mem disk gw dns pub load
  os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-$(uname -s)}")
  kern=$(uname -r)
  up=$(uptime -p 2>/dev/null || uptime)
  cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
  [ -z "$cpu" ] && cpu=$(uname -p)
  cores=$(nproc 2>/dev/null)
  mem=$(free -h | awk '/^Mem:/{print $3" / "$2}')
  disk=$(df -h / | awk 'NR==2{print $3" / "$2" ("$5" занято)"}')
  gw=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
  dns=$(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd', ' -)
  load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
  pub=$(fetch - https://api.ipify.org 2>/dev/null); [ -z "$pub" ] && pub="н/д"

  {
    printf '\n'
    printf 'ОС:          %s\n' "$os"
    printf 'Ядро:        %s\n' "$kern"
    printf 'Хост:        %s\n' "$(hostname)"
    printf 'Аптайм:      %s   (load %s)\n' "$up" "$load"
    printf 'CPU:         %s  (%s ядер)\n' "$cpu" "$cores"
    printf 'Память:      %s\n' "$mem"
    printf 'Диск /:      %s\n' "$disk"
    printf 'Шлюз:        %s\n' "${gw:-н/д}"
    printf 'DNS:         %s\n' "${dns:-н/д}"
    printf 'Внешний IP:  %s\n' "$pub"
    printf '\nИнтерфейсы:\n'
    ip -br a 2>/dev/null | grep -v '^lo ' | sed 's/^/  /'
    printf '\nСлушающие порты:\n'
    ss -tulnH 2>/dev/null | awk '{print "  "$1"  "$5}' | sort -u | head -n 25
  } >/dev/tty
  pause
}

sec_install() {
  local sel pkgs=() t
  sel=$(ui_checklist "Установка программ (apt) — отметь галочками" "${APT_ITEMS[@]}") || return
  while IFS= read -r t; do [ -n "$t" ] && pkgs+=("$t"); done <<< "$sel"
  [ "${#pkgs[@]}" -gt 0 ] || { ui_msg "Ничего не выбрано."; pause; return; }
  ui_msg "Будут установлены:" "${pkgs[*]}"
  ui_yesno "Установить сейчас?" || { pause; return; }
  $SUDO apt-get update
  $SUDO apt-get install -y "${pkgs[@]}"
  ui_msg "Готово."
  pause
}

sec_tweaks() {
  local sel t
  sel=$(ui_checklist "Твики и настройка сервера — отметь галочками" "${TWEAK_ITEMS[@]}") || return
  [ -n "$sel" ] || { ui_msg "Ничего не выбрано."; pause; return; }
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if declare -F "tw_$t" >/dev/null; then "tw_$t"; fi
  done <<< "$sel"
  ui_msg "Твики применены."
  pause
}

sec_commands() {
  local labels=() item desc cmd pick i
  while :; do
    labels=()
    for item in "${CMDS[@]}"; do labels+=("${item%%@@*}"); done
    labels+=("← Назад")
    pick=$(ui_menu "Справочник команд — выбери, покажу и выполню" "${labels[@]}") || return
    [ "$pick" = "← Назад" ] || [ -z "$pick" ] && return
    for item in "${CMDS[@]}"; do
      desc=${item%%@@*}; cmd=${item#*@@}
      if [ "$desc" = "$pick" ]; then
        { printf '\n$ %s\n\n' "$cmd"; } >/dev/tty
        eval "$cmd" 2>&1 | page
        pause
        break
      fi
    done
  done
}

# ===========================================================================
# ТВИКИ
# ===========================================================================

tw_update() {
  ui_msg "Обновление системы..."
  $SUDO apt-get update && $SUDO apt-get -y upgrade
}

tw_ufw() {
  ensure_pkg ufw || return
  ui_msg "UFW: разрешаю SSH и включаю фаервол."
  $SUDO ufw allow OpenSSH >/dev/null 2>&1 || $SUDO ufw allow 22/tcp
  $SUDO ufw --force enable
  $SUDO ufw status verbose
}

tw_fail2ban() {
  ensure_pkg fail2ban || return
  $SUDO systemctl enable --now fail2ban
  ui_msg "fail2ban включён (защита SSH по умолчанию)."
}

tw_unattended() {
  ensure_pkg unattended-upgrades || return
  printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' \
    | $SUDO tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
  $SUDO systemctl enable --now unattended-upgrades 2>/dev/null
  ui_msg "Автообновления безопасности включены."
}

tw_timezone() {
  local tz; tz=$(ui_input "Часовой пояс" "Asia/Yerevan")
  [ -n "$tz" ] || return
  $SUDO timedatectl set-timezone "$tz" && ui_msg "Часовой пояс: $tz"
}

tw_swap() {
  if swapon --show 2>/dev/null | grep -q .; then
    ui_yesno "Swap уже есть. Всё равно создать /swapfile?" || return
  fi
  local sz f=/swapfile
  sz=$(ui_input "Размер swap-файла (напр. 2G)" "2G")
  if [ -e "$f" ]; then ui_msg "$f уже существует — пропускаю."; return; fi
  if ! $SUDO fallocate -l "$sz" "$f" 2>/dev/null; then
    local mb=${sz%[Gg]}; mb=$(( mb * 1024 ))
    $SUDO dd if=/dev/zero of="$f" bs=1M count="$mb" status=none
  fi
  $SUDO chmod 600 "$f"
  $SUDO mkswap "$f" >/dev/null
  $SUDO swapon "$f"
  grep -q "^$f " /etc/fstab 2>/dev/null || printf '%s none swap sw 0 0\n' "$f" | $SUDO tee -a /etc/fstab >/dev/null
  ui_msg "Swap создан: $sz"
  free -h >/dev/tty
}

tw_hostname() {
  local h; h=$(ui_input "Новое имя хоста" "$(hostname)")
  [ -n "$h" ] || return
  $SUDO hostnamectl set-hostname "$h" && ui_msg "Имя хоста: $h"
}

tw_bbr() {
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' \
    | $SUDO tee /etc/sysctl.d/99-bbr.conf >/dev/null
  $SUDO sysctl --system >/dev/null 2>&1
  ui_msg "TCP BBR: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
}

tw_ssh_harden() {
  ui_msg "ВНИМАНИЕ: отключаю вход по паролю и root-логин." \
         "Убедись, что SSH-ключ уже настроен — иначе потеряешь доступ!"
  ui_yesno "SSH-ключ настроен, продолжить?" || return
  local d=/etc/ssh/sshd_config.d f
  if [ -d "$d" ]; then f="$d/99-hh-harden.conf"; else f=/etc/ssh/sshd_config; fi
  printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' \
    | $SUDO tee "$f" >/dev/null
  $SUDO systemctl restart ssh 2>/dev/null || $SUDO systemctl restart sshd 2>/dev/null
  ui_msg "SSH усилён. Проверь новый вход в ОТДЕЛЬНОЙ сессии, прежде чем закрыть текущую!"
}

# ===========================================================================
# ДИАГНОСТИКА СЕТИ
# ===========================================================================

sec_netdiag() {
  local pick
  while :; do
    pick=$(ui_menu "Диагностика сети" \
      "Пинг-скан подсети (живые хосты)" \
      "Скан камер/NVR (порты CCTV)" \
      "Проверка RTSP-порта камеры" \
      "mtr — трасса с потерями" \
      "iperf3 — замер скорости между узлами" \
      "speedtest — скорость до интернета" \
      "← Назад") || return
    case "$pick" in
      "Пинг-скан"*)  nd_pingscan ;;
      "Скан камер"*) nd_camscan ;;
      "Проверка RTSP"*) nd_rtsp ;;
      "mtr"*)        nd_mtr ;;
      "iperf3"*)     nd_iperf ;;
      "speedtest"*)  nd_speedtest ;;
      *) return ;;
    esac
  done
}

nd_pingscan() {
  ensure_pkg nmap || { pause; return; }
  local d; d=$(ui_input "Подсеть/CIDR для скана" "$(default_cidr)")
  [ -n "$d" ] || return
  ui_msg "Пинг-скан $d ..."
  $SUDO nmap -sn "$d" 2>&1 | page
  pause
}

nd_camscan() {
  ensure_pkg nmap || { pause; return; }
  local t; t=$(ui_input "Хост или подсеть (камера/NVR)" "$(default_cidr)")
  [ -n "$t" ] || return
  ui_msg "Ищу камеры/NVR в $t" "порты 80,443,554,8000,37777,34567,8899,88 ..."
  $SUDO nmap -p 80,443,554,8000,37777,34567,8899,88 --open "$t" 2>&1 | page
  pause
}

nd_rtsp() {
  local h port
  h=$(ui_input "IP камеры" ""); [ -n "$h" ] || return
  port=$(ui_input "RTSP-порт" "554")
  if timeout 3 bash -c "exec 3<>/dev/tcp/$h/$port" 2>/dev/null; then
    ui_msg "Порт $h:$port ОТКРЫТ — RTSP слушает."
    if command -v ffprobe >/dev/null 2>&1; then
      local url; url=$(ui_input "RTSP URL для ffprobe" "rtsp://$h:$port/")
      [ -n "$url" ] && ffprobe -v error -rtsp_transport tcp -show_streams \
        -of default=noprint_wrappers=1 "$url" 2>&1 | page
    else
      ui_msg "Установи пакет ffmpeg — тогда проверю сам поток (ffprobe): разрешение/кодек."
    fi
  else
    ui_msg "Порт $h:$port закрыт или недоступен."
  fi
  pause
}

nd_mtr() {
  ensure_pkg mtr-tiny || ensure_pkg mtr || { pause; return; }
  local h; h=$(ui_input "Хост назначения" "1.1.1.1"); [ -n "$h" ] || return
  ui_msg "mtr до $h (10 циклов)..."
  $SUDO mtr -rwc 10 "$h" 2>&1 | page
  pause
}

nd_iperf() {
  ensure_pkg iperf3 || { pause; return; }
  local mode h
  mode=$(ui_menu "iperf3" \
    "Сервер (принять один замер)" \
    "Клиент (подключиться к серверу)" \
    "← Назад") || return
  case "$mode" in
    "Сервер"*)
      ui_msg "iperf3 -s на порту 5201 — жду один замер от клиента..."
      iperf3 -s -1 >/dev/tty 2>&1 ;;
    "Клиент"*)
      h=$(ui_input "IP сервера iperf3" ""); [ -n "$h" ] || return
      iperf3 -c "$h" 2>&1 | page ;;
    *) return ;;
  esac
  pause
}

nd_speedtest() {
  ensure_pkg speedtest-cli || { pause; return; }
  ui_msg "Замер скорости до интернета..."
  speedtest-cli 2>&1 | page
  pause
}

# ===========================================================================
# DOCKER И СЕРВИСЫ
# ===========================================================================

sec_docker() {
  local pick
  while :; do
    pick=$(ui_menu "Docker и сервисы" \
      "Установить Docker + compose" \
      "Развернуть готовые стеки (галочки)" \
      "Статус контейнеров" \
      "← Назад") || return
    case "$pick" in
      "Установить Docker"*) dk_install ;;
      "Развернуть"*)        dk_stacks ;;
      "Статус"*)            dk_status ;;
      *) return ;;
    esac
  done
}

dk_install() {
  if command -v docker >/dev/null 2>&1; then
    ui_msg "Docker уже установлен: $(docker --version)"; pause; return
  fi
  ui_yesno "Установить Docker через официальный скрипт get.docker.com?" || return
  ui_msg "Устанавливаю Docker..."
  fetch - https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker 2>/dev/null
  if [ -n "$SUDO" ]; then
    $SUDO usermod -aG docker "$USER"
    ui_msg "Пользователь $USER добавлен в группу docker — перелогинься, чтобы работало без sudo."
  fi
  docker --version >/dev/tty 2>&1
  pause
}

dk_stacks() {
  command -v docker >/dev/null 2>&1 || { ui_msg "Сначала установи Docker."; pause; return; }
  local sel t
  sel=$(ui_checklist "Готовые стеки — отметь галочками" \
    "portainer|Portainer — веб-панель Docker (порт 9443)" \
    "npm|Nginx Proxy Manager — реверс-прокси + HTTPS (порт 81)" \
    "watchtower|Watchtower — автообновление контейнеров") || return
  [ -n "$sel" ] || { ui_msg "Ничего не выбрано."; pause; return; }
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if declare -F "dk_deploy_$t" >/dev/null; then "dk_deploy_$t"; fi
  done <<< "$sel"
  pause
}

dk_deploy_portainer() {
  $SUDO docker volume create portainer_data >/dev/null 2>&1
  $SUDO docker rm -f portainer >/dev/null 2>&1 || true
  $SUDO docker run -d --name portainer --restart=always \
    -p 8000:8000 -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data portainer/portainer-ce:latest
  ui_msg "Portainer поднят: https://<IP-сервера>:9443 (при первом входе задашь пароль admin)."
}

dk_deploy_npm() {
  local dir=/opt/npm
  $SUDO mkdir -p "$dir"
  $SUDO tee "$dir/docker-compose.yml" >/dev/null <<'YML'
services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
YML
  ( cd "$dir" && $SUDO docker compose up -d )
  ui_msg "Nginx Proxy Manager: http://<IP-сервера>:81" "Вход по умолчанию: admin@example.com / changeme"
}

dk_deploy_watchtower() {
  $SUDO docker rm -f watchtower >/dev/null 2>&1 || true
  $SUDO docker run -d --name watchtower --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --cleanup
  ui_msg "Watchtower запущен — контейнеры будут обновляться автоматически."
}

dk_status() {
  command -v docker >/dev/null 2>&1 || { ui_msg "Docker не установлен."; pause; return; }
  { $SUDO docker ps; printf '\n--- compose-проекты ---\n'; $SUDO docker compose ls 2>/dev/null; } 2>&1 | page
  pause
}

# ===========================================================================
# WIREGUARD VPN
# ===========================================================================

WG_CONF=/etc/wireguard/wg0.conf
WG_NET=10.66.66
WG_PORT=51820

sec_wireguard() {
  local pick
  while :; do
    pick=$(ui_menu "WireGuard VPN" \
      "Поднять сервер" \
      "Добавить клиента (QR)" \
      "Статус / список клиентов" \
      "← Назад") || return
    case "$pick" in
      "Поднять сервер")   wg_setup_server ;;
      "Добавить клиента"*) wg_add_client ;;
      "Статус"*)          wg_status ;;
      *) return ;;
    esac
  done
}

wg_setup_server() {
  ensure_pkg wireguard || { pause; return; }
  ensure_pkg iptables >/dev/null 2>&1 || true
  ensure_pkg qrencode >/dev/null 2>&1 || true
  if [ -f "$WG_CONF" ]; then
    ui_yesno "Сервер wg0 уже настроен. Перенастроить заново (сотрёт клиентов)?" || return
    $SUDO systemctl stop wg-quick@wg0 2>/dev/null
  fi
  local nic pub port skey spub
  nic=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  pub=$(fetch - https://api.ipify.org 2>/dev/null)
  pub=$(ui_input "Внешний IP/домен сервера" "${pub:-}"); [ -n "$pub" ] || return
  port=$(ui_input "UDP-порт" "$WG_PORT")
  skey=$(wg genkey); spub=$(printf '%s' "$skey" | wg pubkey)
  $SUDO mkdir -p /etc/wireguard
  $SUDO tee "$WG_CONF" >/dev/null <<CONF
[Interface]
Address = ${WG_NET}.1/24
ListenPort = ${port}
PrivateKey = ${skey}
PostUp = iptables -t nat -A POSTROUTING -o ${nic} -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${nic} -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT
# HH_ENDPOINT=${pub}:${port}
# HH_SERVERPUB=${spub}
CONF
  $SUDO chmod 600 "$WG_CONF"
  echo 'net.ipv4.ip_forward=1' | $SUDO tee /etc/sysctl.d/99-wg.conf >/dev/null
  $SUDO sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
  command -v ufw >/dev/null 2>&1 && $SUDO ufw allow "${port}/udp" >/dev/null 2>&1
  $SUDO systemctl enable --now wg-quick@wg0
  ui_msg "Сервер WireGuard поднят (wg0, сеть ${WG_NET}.0/24, порт ${port})." \
         "Теперь добавь клиента, чтобы получить конфиг с QR."
  pause
}

wg_add_client() {
  [ -f "$WG_CONF" ] || { ui_msg "Сначала подними сервер."; pause; return; }
  local name; name=$(ui_input "Имя клиента (латиницей)" "client1"); [ -n "$name" ] || return
  local spriv spub endpoint n ip ckey cpub psk out ccfg
  spriv=$($SUDO grep -m1 '^PrivateKey' "$WG_CONF" | awk '{print $3}')
  spub=$(printf '%s' "$spriv" | wg pubkey)
  endpoint=$($SUDO grep -m1 '^# HH_ENDPOINT=' "$WG_CONF" | cut -d= -f2)
  n=2
  while $SUDO grep -q "AllowedIPs = ${WG_NET}.${n}/32" "$WG_CONF" 2>/dev/null; do n=$((n+1)); done
  ip="${WG_NET}.${n}"
  ckey=$(wg genkey); cpub=$(printf '%s' "$ckey" | wg pubkey); psk=$(wg genpsk)
  $SUDO tee -a "$WG_CONF" >/dev/null <<PEER

[Peer]
# HH_CLIENT=${name}
PublicKey = ${cpub}
PresharedKey = ${psk}
AllowedIPs = ${ip}/32
PEER
  # применить на лету, иначе — перезапуск интерфейса
  $SUDO wg set wg0 peer "$cpub" preshared-key <(printf '%s' "$psk") allowed-ips "${ip}/32" 2>/dev/null \
    || $SUDO systemctl restart wg-quick@wg0
  ccfg="[Interface]
PrivateKey = ${ckey}
Address = ${ip}/24
DNS = 1.1.1.1

[Peer]
PublicKey = ${spub}
PresharedKey = ${psk}
Endpoint = ${endpoint}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25"
  { printf '\n=== Конфиг клиента %s ===\n\n%s\n\n' "$name" "$ccfg"; } >/dev/tty
  if command -v qrencode >/dev/null 2>&1; then
    { printf '=== QR (сканируй в приложении WireGuard) ===\n\n'; } >/dev/tty
    printf '%s' "$ccfg" | qrencode -t ansiutf8 >/dev/tty
  else
    ui_msg "Установи пакет qrencode для QR-кода. Конфиг выше скопируй вручную."
  fi
  out="/etc/wireguard/${name}.conf"
  printf '%s\n' "$ccfg" | $SUDO tee "$out" >/dev/null
  $SUDO chmod 600 "$out"
  ui_msg "Конфиг клиента сохранён: $out"
  pause
}

wg_status() {
  command -v wg >/dev/null 2>&1 || { ui_msg "WireGuard не установлен."; pause; return; }
  {
    $SUDO wg show
    printf '\nКлиенты в конфиге:\n'
    $SUDO grep '# HH_CLIENT=' "$WG_CONF" 2>/dev/null | sed 's/# HH_CLIENT=/  - /' || printf '  (нет)\n'
  } 2>&1 | page
  pause
}

# ===========================================================================
# ПОЛЬЗОВАТЕЛИ И ДОСТУП
# ===========================================================================

sec_users() {
  local pick
  while :; do
    pick=$(ui_menu "Пользователи и доступ" \
      "Создать sudo-пользователя" \
      "Добавить SSH-ключ пользователю" \
      "Сменить порт SSH" \
      "Обратный SSH-туннель (доступ за NAT)" \
      "Бэкап по расписанию (rsync + cron)" \
      "← Назад") || return
    case "$pick" in
      "Создать sudo"*)   usr_add ;;
      "Добавить SSH"*)   usr_addkey ;;
      "Сменить порт SSH") usr_sshport ;;
      "Обратный SSH"*)   usr_revssh ;;
      "Бэкап"*)          usr_backup ;;
      *) return ;;
    esac
  done
}

usr_add() {
  local u; u=$(ui_input "Имя нового пользователя" ""); [ -n "$u" ] || return
  if id "$u" >/dev/null 2>&1; then ui_msg "Пользователь $u уже существует."; pause; return; fi
  $SUDO adduser --disabled-password --gecos "" "$u"
  ui_msg "Задай пароль для $u (ввод скрыт):"
  $SUDO passwd "$u" </dev/tty
  $SUDO usermod -aG sudo "$u"
  ui_msg "Пользователь $u создан и добавлен в группу sudo."
  pause
}

usr_addkey() {
  local u key dir
  u=$(ui_input "Пользователь" "$USER"); [ -n "$u" ] || return
  id "$u" >/dev/null 2>&1 || { ui_msg "Нет такого пользователя: $u"; pause; return; }
  key=$(ui_input "Вставь публичный SSH-ключ (ssh-ed25519/ssh-rsa ...)" "")
  case "$key" in ssh-*) : ;; *) ui_msg "Это не похоже на публичный ключ (должен начинаться с ssh-)."; pause; return ;; esac
  dir=$(getent passwd "$u" | cut -d: -f6)/.ssh
  $SUDO mkdir -p "$dir"
  printf '%s\n' "$key" | $SUDO tee -a "$dir/authorized_keys" >/dev/null
  $SUDO chmod 700 "$dir"; $SUDO chmod 600 "$dir/authorized_keys"
  $SUDO chown -R "$u:$u" "$dir"
  ui_msg "Ключ добавлен пользователю $u."
  pause
}

usr_sshport() {
  local cur p d f
  cur=$($SUDO grep -rhm1 '^Port ' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ 2>/dev/null | awk '{print $2; exit}')
  [ -n "$cur" ] || cur=22
  p=$(ui_input "Новый порт SSH" "$cur"); [ -n "$p" ] || return
  case "$p" in ''|*[!0-9]*) ui_msg "Порт должен быть числом."; pause; return ;; esac
  ui_msg "ВНИМАНИЕ: открою порт $p в UFW, затем сменю порт и перезапущу SSH." \
         "НЕ закрывай текущую сессию, пока не проверишь вход на новом порту!"
  ui_yesno "Продолжить?" || return
  command -v ufw >/dev/null 2>&1 && $SUDO ufw allow "${p}/tcp" >/dev/null 2>&1
  d=/etc/ssh/sshd_config.d
  if [ -d "$d" ]; then
    f="$d/99-hh-port.conf"; printf 'Port %s\n' "$p" | $SUDO tee "$f" >/dev/null
  else
    $SUDO sed -i "s/^#\?Port .*/Port $p/" /etc/ssh/sshd_config
  fi
  $SUDO systemctl restart ssh 2>/dev/null || $SUDO systemctl restart sshd 2>/dev/null
  ui_msg "SSH теперь на порту $p. Проверь из НОВОГО окна:  ssh -p $p пользователь@хост"
  pause
}

usr_backup() {
  ensure_pkg rsync || { pause; return; }
  local src dst freq sched mark cronline
  src=$(ui_input "Что бэкапить (каталог-источник)" "/etc"); [ -n "$src" ] || return
  dst=$(ui_input "Куда складывать (каталог-назначение)" "/var/backups/hh"); [ -n "$dst" ] || return
  freq=$(ui_menu "Как часто?" "Ежедневно (03:00)" "Еженедельно (вс 03:00)" "Ежечасно" "← Отмена") || return
  case "$freq" in
    "Ежедневно"*)   sched="0 3 * * *" ;;
    "Еженедельно"*) sched="0 3 * * 0" ;;
    "Ежечасно")     sched="0 * * * *" ;;
    *) return ;;
  esac
  $SUDO mkdir -p "$dst"
  mark="# HH-backup ${src}"
  cronline="${sched} rsync -a --delete '${src}' '${dst}' ${mark}"
  { $SUDO crontab -l 2>/dev/null | grep -vF "$mark"; printf '%s\n' "$cronline"; } | $SUDO crontab -
  ui_msg "Бэкап настроен: $src -> $dst ($freq)." "Задание записано в crontab root."
  pause
}

usr_revssh() {
  ensure_pkg autossh || { pause; return; }
  ui_msg "Обратный SSH-туннель: машина сама подключается к relay-серверу с белым IP" \
         "и пробрасывает свой SSH обратно. Нужен уже настроенный SSH-КЛЮЧ к relay" \
         "(autossh пароль не вводит — проверь, что 'ssh relay' пускает без пароля)."
  local relay rport remote lport name svc
  relay=$(ui_input "Relay: пользователь@хост (напр. root@vps.example.com)" ""); [ -n "$relay" ] || return
  rport=$(ui_input "SSH-порт relay" "22")
  remote=$(ui_input "Порт на relay для проброса (потом: ssh -p ЭТОТ localhost)" "2222")
  lport=$(ui_input "Локальный порт этой машины" "22")
  name=$(ui_input "Имя туннеля (латиницей)" "main"); [ -n "$name" ] || return
  svc="hh-revssh-${name}"
  $SUDO tee "/etc/systemd/system/${svc}.service" >/dev/null <<UNIT
[Unit]
Description=HH reverse SSH tunnel (${name}) -> ${relay}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER}
Environment=AUTOSSH_GATETIME=0
ExecStart=/usr/bin/autossh -M 0 -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -p ${rport} -R ${remote}:localhost:${lport} ${relay}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now "$svc"
  sleep 1
  $SUDO systemctl --no-pager --full status "$svc" 2>&1 | head -n 12 >/dev/tty
  ui_msg "Туннель '${name}' поднят как сервис ${svc}." \
         "С relay: ssh -p ${remote} localhost — попадёшь на эту машину." \
         "Если статус failed — проверь SSH-ключ к ${relay}."
  pause
}

# ===========================================================================
# СЕТЬ И ВЕБ
# ===========================================================================

sec_netweb() {
  local pick
  while :; do
    pick=$(ui_menu "Сеть и веб" \
      "Статический IP (netplan)" \
      "Certbot — HTTPS для nginx" \
      "← Назад") || return
    case "$pick" in
      "Статический IP"*) nw_static ;;
      "Certbot"*)        nw_certbot ;;
      *) return ;;
    esac
  done
}

nw_static() {
  command -v netplan >/dev/null 2>&1 || { ui_msg "netplan не найден — нужен Ubuntu-сервер с netplan."; pause; return; }
  local nic cur_ip cur_gw cur_dns ip gw dns dns_yaml f how
  nic=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  nic=$(ui_input "Сетевой интерфейс" "${nic:-eth0}"); [ -n "$nic" ] || return
  cur_ip=$(ip -o -f inet addr show "$nic" 2>/dev/null | awk '{print $4; exit}')
  cur_gw=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
  cur_dns=$(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd, -)
  ip=$(ui_input "IP/маска (CIDR, напр. 192.168.1.50/24)" "$cur_ip"); [ -n "$ip" ] || return
  gw=$(ui_input "Шлюз" "$cur_gw")
  dns=$(ui_input "DNS через запятую" "${cur_dns:-1.1.1.1,8.8.8.8}")
  dns_yaml=$(printf '%s' "$dns" | sed 's/ *, */, /g')
  ui_msg "ВНИМАНИЕ: смена IP разорвёт SSH-сессию, если адрес меняется!" \
         "Убедись, что подключишься по новому адресу."
  ui_yesno "Записать конфиг?" || return
  f=/etc/netplan/99-hh.yaml
  $SUDO tee "$f" >/dev/null <<YAML
network:
  version: 2
  ethernets:
    ${nic}:
      dhcp4: false
      addresses: [${ip}]
      routes:
        - to: default
          via: ${gw}
      nameservers:
        addresses: [${dns_yaml}]
YAML
  $SUDO chmod 600 "$f"
  how=$(ui_menu "Как применить?" \
    "netplan try (безопасно — автооткат через 120 c)" \
    "netplan apply (сразу)" \
    "Только записать, не применять") || return
  case "$how" in
    "netplan try"*)   $SUDO netplan try </dev/tty ;;
    "netplan apply"*) $SUDO netplan apply && ui_msg "Применено. Новый адрес: $ip" ;;
    *) ui_msg "Конфиг записан в $f, не применён." ;;
  esac
  pause
}

nw_certbot() {
  command -v nginx >/dev/null 2>&1 || ui_msg "nginx не установлен — сертификат прописывается в его конфиг. Поставь nginx в разделе «Установка»."
  ensure_pkg certbot || { pause; return; }
  ensure_pkg python3-certbot-nginx || { pause; return; }
  local domain email args=() d
  domain=$(ui_input "Домен (несколько — через пробел)" ""); [ -n "$domain" ] || return
  email=$(ui_input "Email для Let's Encrypt (пусто — без email)" "")
  ui_msg "Требуется: домен указывает на этот сервер (A-запись), порт 80 открыт, nginx запущен."
  ui_yesno "Получить сертификат сейчас?" || return
  for d in $domain; do args+=(-d "$d"); done
  if [ -n "$email" ]; then
    $SUDO certbot --nginx "${args[@]}" -m "$email" --agree-tos -n --redirect 2>&1 | page
  else
    $SUDO certbot --nginx "${args[@]}" --register-unsafely-without-email --agree-tos -n --redirect 2>&1 | page
  fi
  pause
}

# ===========================================================================
# ОБСЛУЖИВАНИЕ И МОНИТОРИНГ
# ===========================================================================

sec_maint() {
  local pick
  while :; do
    pick=$(ui_menu "Обслуживание и мониторинг" \
      "Чистка системы (освободить место)" \
      "netdata — веб-мониторинг" \
      "SSH-логи и fail2ban" \
      "← Назад") || return
    case "$pick" in
      "Чистка"*)   mt_clean ;;
      "netdata"*)  mt_netdata ;;
      "SSH-логи"*) mt_sshlog ;;
      *) return ;;
    esac
  done
}

mt_clean() {
  local before after
  before=$(df -h / | awk 'NR==2{print $4}')
  ui_msg "Будет: apt autoremove/clean + чистка журналов старше 7 дней" \
         "(и docker prune, если Docker установлен — с отдельным подтверждением)."
  ui_yesno "Продолжить чистку?" || return
  $SUDO apt-get autoremove --purge -y
  $SUDO apt-get clean
  $SUDO journalctl --vacuum-time=7d 2>&1 | tail -n 3 >/dev/tty
  if command -v docker >/dev/null 2>&1; then
    if ui_yesno "docker system prune -af (удалит неиспользуемые образы/тома)?"; then
      $SUDO docker system prune -af
    fi
  fi
  after=$(df -h / | awk 'NR==2{print $4}')
  ui_msg "Свободно на /:  было $before  →  стало $after"
  pause
}

mt_netdata() {
  if systemctl is-active --quiet netdata 2>/dev/null || command -v netdata >/dev/null 2>&1; then
    ui_msg "netdata уже установлен. Веб-панель: http://<IP-сервера>:19999"
    systemctl status netdata --no-pager 2>&1 | head -n 6 >/dev/tty
    pause; return
  fi
  ui_yesno "Установить netdata (официальный установщик)?" || return
  ui_msg "Ставлю netdata..."
  fetch - https://get.netdata.cloud/kickstart.sh | $SUDO sh -s -- --dont-wait --disable-telemetry
  if command -v ufw >/dev/null 2>&1 && ui_yesno "Открыть порт 19999 в UFW?"; then
    $SUDO ufw allow 19999/tcp >/dev/null 2>&1
  fi
  ui_msg "Готово. Веб-панель: http://<IP-сервера>:19999"
  pause
}

mt_sshlog() {
  local pick ipp
  while :; do
    pick=$(ui_menu "SSH-логи и fail2ban" \
      "Последние входы" \
      "Неудачные попытки входа" \
      "Забаненные IP (fail2ban)" \
      "Разбанить IP (fail2ban)" \
      "← Назад") || return
    case "$pick" in
      "Последние входы")
        { echo "# last -n 20:"; last -n 20 2>/dev/null; } | page ;;
      "Неудачные"*)
        {
          if [ -f /var/log/auth.log ]; then
            $SUDO grep -a 'Failed password' /var/log/auth.log 2>/dev/null | tail -n 30
          else
            $SUDO journalctl _COMM=sshd 2>/dev/null | grep -a 'Failed password' | tail -n 30
          fi
          echo "(если пусто — неудачных попыток нет или логи в другом месте)"
        } | page ;;
      "Забаненные"*)
        if command -v fail2ban-client >/dev/null 2>&1; then
          $SUDO fail2ban-client status sshd 2>&1 | page
        else
          ui_msg "fail2ban не установлен (поставь в разделе «Твики»)."; pause
        fi ;;
      "Разбанить"*)
        if command -v fail2ban-client >/dev/null 2>&1; then
          ipp=$(ui_input "IP для разбана" ""); [ -n "$ipp" ] || continue
          $SUDO fail2ban-client set sshd unbanip "$ipp" >/dev/tty 2>&1
          ui_msg "Разбанен: $ipp"; pause
        else
          ui_msg "fail2ban не установлен."; pause
        fi ;;
      *) return ;;
    esac
  done
}

# ===========================================================================
# ГЛАВНЫЙ ЦИКЛ
# ===========================================================================

main() {
  require_tty
  require_apt
  init_sudo
  ensure_ui
  banner
  local pick
  while :; do
    pick=$(ui_menu "Главное меню — $(hostname)" \
      "Информация о системе и сеть" \
      "Установка программ (галочки)" \
      "Твики и настройка сервера" \
      "Диагностика сети" \
      "Docker и сервисы" \
      "WireGuard VPN" \
      "Пользователи и доступ" \
      "Сеть и веб" \
      "Обслуживание и мониторинг" \
      "Справочник команд" \
      "Выход") || break
    case "$pick" in
      "Информация о системе и сеть") sec_sysinfo ;;
      "Установка программ (галочки)") sec_install ;;
      "Твики и настройка сервера")    sec_tweaks ;;
      "Диагностика сети")             sec_netdiag ;;
      "Docker и сервисы")             sec_docker ;;
      "WireGuard VPN")                sec_wireguard ;;
      "Пользователи и доступ")        sec_users ;;
      "Сеть и веб")                   sec_netweb ;;
      "Обслуживание и мониторинг")    sec_maint ;;
      "Справочник команд")            sec_commands ;;
      "Выход"|"") break ;;
    esac
  done
  printf 'Пока!\n' >/dev/tty
}

# HH_NORUN=1 — только загрузить функции/данные (для тестов), не показывать меню
if [ -z "${HH_NORUN:-}" ]; then
  main "$@"
fi
