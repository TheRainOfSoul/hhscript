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
        if command -v less >/dev/null 2>&1; then
          eval "$cmd" 2>&1 | less -RFX >/dev/tty
        else
          eval "$cmd" >/dev/tty 2>&1
        fi
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
      "Справочник команд" \
      "Выход") || break
    case "$pick" in
      "Информация о системе и сеть") sec_sysinfo ;;
      "Установка программ (галочки)") sec_install ;;
      "Твики и настройка сервера")    sec_tweaks ;;
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
