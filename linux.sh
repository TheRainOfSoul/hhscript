#!/usr/bin/env bash
# HH Toolbox - Linux CLI (Debian/Ubuntu)
# Run:  curl lin.hhtdom.ru | bash
# UI: gum (pretty, downloaded if missing) -> plain bash.
# All input from /dev/tty, because with "curl | bash" stdin is the script itself.

VERSION="1.0"
LOG="${HOME:-/root}/.hhtoolbox.log"

# action log (audit on the client's server): time + message in ~/.hhtoolbox.log
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null || true; }

# --- guard against sh and non-interactive runs ----------------------------
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Run it with bash:  curl lin.hhtdom.ru | bash" >&2
  exit 1
fi

trap 'printf "\n"; exit 130' INT

require_tty() {
  if ! { [ -e /dev/tty ] && ( : </dev/tty ) 2>/dev/null; }; then
    echo "An interactive terminal is required (/dev/tty is unavailable)." >&2
    echo "Download and run:  curl -fsSL lin.hhtdom.ru -o hh.sh && bash hh.sh" >&2
    exit 1
  fi
}

require_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script targets Debian/Ubuntu (apt-get is required)." >&2
    exit 1
  fi
}

# On a VM Linux console Cyrillic often turns into triangles/diamonds -
# the active VT font has no Cyrillic glyphs. Load a Cyrillic UTF-8 font.
# Only for a real console (TERM=linux); over SSH the client terminal draws,
# setfont does not apply there - leave it. Silent, no privileges - not critical.
fix_console_font() {
  [ "${TERM:-}" = linux ] || return 0
  command -v setfont >/dev/null 2>&1 || return 0
  local f
  for f in Uni2-Terminus16 Uni2-Fixed16 Uni2-VGA16 CyrSlav-Terminus16 \
           CyrSlav-Fixed16 UniCyr_8x16 Cyr_a8x16 cyr-sun16; do
    setfont "$f" 2>/dev/null && return 0
  done
  command -v setupcon >/dev/null 2>&1 && setupcon 2>/dev/null
  return 0
}

# --- input/privileges ------------------------------------------------------
read_tty() { IFS= read -r "$@" </dev/tty; }

SUDO=""
init_sudo() { [ "$(id -u)" -ne 0 ] && SUDO="sudo"; }

# fetch OUT URL  (OUT="-" -> to stdout)
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

# install a package if not present yet
ensure_pkg() {
  local p=$1
  dpkg -s "$p" >/dev/null 2>&1 && return 0
  ui_msg "Installing package: $p"
  log "apt install: $p"
  $SUDO apt-get update -qq && $SUDO apt-get install -y "$p"
}

# current subnet in CIDR form (e.g. 192.168.1.50/24) - default for scans
default_cidr() {
  local dev
  dev=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  ip -o -f inet addr show "$dev" 2>/dev/null | awk '{print $4; exit}'
}

# pager for long output (reads stdin, less takes keys from /dev/tty itself)
page() {
  if command -v less >/dev/null 2>&1; then less -RFX >/dev/tty; else cat >/dev/tty; fi
}

# --- UI layer: gum or plain ------------------------------------------------
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
  # forced mode:  HH_UI=plain  or  HH_UI=gum
  case "${HH_UI:-}" in
    plain) UI=plain; return ;;
    gum)   command -v gum >/dev/null 2>&1 && { GUM=gum; UI=gum; return; } ;;
  esac
  if command -v gum >/dev/null 2>&1; then GUM=gum; UI=gum; return; fi
  printf 'Fetching the pretty interface (gum)...\n' >/dev/tty
  if try_install_gum; then UI=gum; return; fi
  printf 'gum unavailable - using plain text mode.\n' >/dev/tty
  UI=plain
}

# ui_msg TEXT...      - message/heading
ui_msg() {
  if [ "$UI" = gum ]; then "$GUM" style --border rounded --padding "0 1" --border-foreground 212 "$@"
  else printf '\n'; printf '%s\n' "$@"; fi
}

# ui_yesno PROMPT     - 0 = yes
ui_yesno() {
  local prompt=$1 a
  if [ "$UI" = gum ]; then "$GUM" confirm "$prompt"; return $?; fi
  printf '%s [y/N]: ' "$prompt" >/dev/tty
  read_tty a || return 1
  case "$a" in y|Y|yes|Yes) return 0 ;; *) return 1 ;; esac
}

# ui_input PROMPT [DEFAULT]  - line to stdout
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

# ui_menu TITLE OPT...  - single choice to stdout
ui_menu() {
  local title=$1; shift
  if [ "$UI" = gum ]; then "$GUM" choose --header "$title" "$@"; return; fi
  local opts=("$@") i choice
  {
    printf '\n== %s ==\n' "$title"
    for i in "${!opts[@]}"; do printf '  %2d) %s\n' "$((i+1))" "${opts[$i]}"; done
    printf '  Choice [1-%d]: ' "${#opts[@]}"
  } >/dev/tty
  read_tty choice || return 1
  case "$choice" in ''|*[!0-9]*) return 1 ;; esac
  if [ "$choice" -ge 1 ] && [ "$choice" -le "${#opts[@]}" ]; then
    printf '%s\n' "${opts[$((choice-1))]}"
  else
    return 1
  fi
}

# ui_checklist TITLE "tag|label"...  - selected tags to stdout (one per line)
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
  # plain: toggle by numbers
  local n=${#pairs[@]} state=() line tok lo hi
  for ((i=0;i<n;i++)); do state[i]=0; done
  while :; do
    {
      printf '\n== %s ==\n' "$title"
      for ((i=0;i<n;i++)); do
        local mark=' '; [ "${state[i]}" = 1 ] && mark='x'
        printf '  [%s] %2d) %s\n' "$mark" "$((i+1))" "${pairs[i]#*|}"
      done
      printf '  Numbers separated by spaces - toggle (range 2-6), a - all, n - clear all\n'
      printf '  Enter - apply, q - cancel\n  > '
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
  printf '\nPress Enter to continue...' >/dev/tty
  read_tty _ 2>/dev/null || true
}

banner() {
  if [ "$UI" = gum ]; then
    "$GUM" style --border double --margin "1 0" --padding "0 3" --border-foreground 212 --align center \
      "HH Toolbox - Linux" "Debian/Ubuntu - v$VERSION"
  else
    printf '\n========================================\n'
    printf '   HH Toolbox - Linux   -   v%s\n' "$VERSION"
    printf '========================================\n'
  fi
}

# ===========================================================================
# DATA
# ===========================================================================

# apt packages:  "package|description"
APT_ITEMS=(
  "htop|htop - interactive process monitor"
  "btop|btop - pretty resource monitor"
  "tmux|tmux - persistent terminal sessions"
  "mc|Midnight Commander - file manager"
  "ncdu|ncdu - disk usage analyzer"
  "tree|tree - directory tree"
  "git|git - version control"
  "curl|curl - HTTP client"
  "wget|wget - file downloader"
  "net-tools|net-tools - ifconfig/netstat/route"
  "dnsutils|dnsutils - dig/nslookup"
  "nmap|nmap - port and network scanner"
  "iftop|iftop - traffic by connection"
  "iotop|iotop - disk load by process"
  "unzip|unzip - extract zip"
  "rsync|rsync - sync/copy"
  "ufw|ufw - simple firewall"
  "fail2ban|fail2ban - SSH brute-force protection"
  "docker.io|Docker - containers"
  "nginx|nginx - web server / reverse proxy"
  "fzf|fzf - fuzzy finder"
  "jq|jq - JSON processor"
  "ffmpeg|ffmpeg - conversion + ffprobe (test camera RTSP streams)"
  "v4l-utils|v4l-utils - USB cameras (v4l2)"
  "tcpdump|tcpdump - capture network traffic"
  "traceroute|traceroute - trace the route"
  "whois|whois - domain/IP info"
  "arp-scan|arp-scan - find LAN devices by MAC (cameras, NVR)"
  "vnstat|vnstat - per-interface traffic accounting"
  "ethtool|ethtool - NIC settings (speed/duplex)"
  "socat|socat - universal socket relay"
  "bat|bat - cat with syntax highlighting"
  "ripgrep|ripgrep (rg) - fast text/log search"
  "screen|screen - persistent terminal sessions"
  "tldr|tldr - short command examples"
  "lsof|lsof - who holds files/ports"
)

# tweaks:  "tag|description"  (function tw_<tag>)
TWEAK_ITEMS=(
  "update|Update the system (apt update && upgrade)"
  "ufw|UFW firewall: allow SSH and enable"
  "fail2ban|Install and enable fail2ban"
  "unattended|Unattended security updates"
  "timezone|Timezone (default Asia/Yerevan)"
  "swap|Create a swap file"
  "hostname|Change the hostname"
  "bbr|Network speedup TCP BBR"
  "ssh_harden|Harden SSH (key-only) - lockout risk"
)

# command reference:  "description@@command"  (commands contain | - hence @@)
CMDS=(
  "Open/listening ports@@ss -tulnp"
  "Top processes by CPU@@ps aux --sort=-%cpu | head -n 20"
  "Top processes by memory@@ps aux --sort=-%mem | head -n 20"
  "Disk usage by filesystem@@df -hT"
  "Largest folders here@@du -h --max-depth=1 . 2>/dev/null | sort -hr | head -n 20"
  "Block devices@@lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE"
  "Active systemd services@@systemctl list-units --type=service --state=running --no-pager"
  "Errors in the journal (last 50)@@journalctl -p err -n 50 --no-pager"
  "Who is logged in and recent logins@@{ echo '# now:'; who; echo; echo '# logins:'; last -n 10; }"
  "Network interfaces (brief)@@ip -br a"
  "Routing table@@ip route"
  "Memory@@free -h"
  "Uptime and load@@uptime"
  "OS and kernel version@@{ . /etc/os-release; echo \"\$PRETTY_NAME\"; uname -a; }"
  "HH Toolbox action log@@tail -n 100 \"\$LOG\" 2>/dev/null || echo 'log is empty'"
)

# ===========================================================================
# SECTIONS
# ===========================================================================

sec_sysinfo() {
  local os kern up cpu cores mem disk load
  os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-$(uname -s)}")
  kern=$(uname -r)
  up=$(uptime -p 2>/dev/null || uptime)
  cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
  [ -z "$cpu" ] && cpu=$(uname -p)
  cores=$(nproc 2>/dev/null)
  mem=$(free -h | awk '/^Mem:/{print $3" / "$2}')
  disk=$(df -h / | awk 'NR==2{print $3" / "$2" ("$5" used)"}')
  load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)

  {
    printf '\n=== System info ===\n\n'
    printf 'OS:          %s\n' "$os"
    printf 'Kernel:      %s\n' "$kern"
    printf 'Host:        %s\n' "$(hostname)"
    printf 'Uptime:      %s   (load %s)\n' "$up" "$load"
    printf 'CPU:         %s  (%s cores)\n' "$cpu" "$cores"
    printf 'Memory:      %s\n' "$mem"
    printf 'Disk /:      %s\n' "$disk"
  } >/dev/tty
  pause
}

sec_netinfo() {
  local dev ip gw dns pub
  dev=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  ip=$(ip -o -f inet addr show "$dev" 2>/dev/null | awk '{print $4; exit}')
  gw=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
  dns=$(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd', ' -)
  pub=$(fetch - https://api.ipify.org 2>/dev/null); [ -z "$pub" ] && pub="n/a"

  {
    printf '\n=== Network info ===\n\n'
    printf 'Interface:   %s\n' "${dev:-n/a}"
    printf 'IP address:  %s\n' "${ip:-n/a}"
    printf 'Gateway:     %s\n' "${gw:-n/a}"
    printf 'DNS:         %s\n' "${dns:-n/a}"
    printf 'External IP: %s\n' "$pub"
    printf '\nInterfaces:\n'
    ip -br a 2>/dev/null | grep -v '^lo ' | sed 's/^/  /'
    printf '\nListening ports:\n'
    ss -tulnH 2>/dev/null | awk '{print "  "$1"  "$5}' | sort -u | head -n 25
  } >/dev/tty
  pause
}

sec_install() {
  local sel pkgs=() t
  sel=$(ui_checklist "Install packages (apt) - tick the boxes" "${APT_ITEMS[@]}") || return
  while IFS= read -r t; do [ -n "$t" ] && pkgs+=("$t"); done <<< "$sel"
  [ "${#pkgs[@]}" -gt 0 ] || { ui_msg "Nothing selected."; pause; return; }
  ui_msg "Will install:" "${pkgs[*]}"
  ui_yesno "Install now?" || { pause; return; }
  log "installing packages: ${pkgs[*]}"
  $SUDO apt-get update
  $SUDO apt-get install -y "${pkgs[@]}"
  ui_msg "Done."
  pause
}

sec_tweaks() {
  local sel t
  sel=$(ui_checklist "Server tweaks & hardening - tick the boxes" "${TWEAK_ITEMS[@]}") || return
  [ -n "$sel" ] || { ui_msg "Nothing selected."; pause; return; }
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if declare -F "tw_$t" >/dev/null; then log "tweak: $t"; "tw_$t"; fi
  done <<< "$sel"
  ui_msg "Tweaks applied."
  pause
}

sec_commands() {
  local labels=() item desc cmd pick i
  while :; do
    labels=()
    for item in "${CMDS[@]}"; do labels+=("${item%%@@*}"); done
    labels+=("<- Back")
    pick=$(ui_menu "Command reference - pick one, I'll show and run it" "${labels[@]}") || return
    [ "$pick" = "<- Back" ] || [ -z "$pick" ] && return
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
# TWEAKS
# ===========================================================================

tw_update() {
  ui_msg "Updating the system..."
  $SUDO apt-get update && $SUDO apt-get -y upgrade
}

tw_ufw() {
  ensure_pkg ufw || return
  ui_msg "UFW: allowing SSH and enabling the firewall."
  $SUDO ufw allow OpenSSH >/dev/null 2>&1 || $SUDO ufw allow 22/tcp
  $SUDO ufw --force enable
  $SUDO ufw status verbose
}

tw_fail2ban() {
  ensure_pkg fail2ban || return
  $SUDO systemctl enable --now fail2ban
  ui_msg "fail2ban enabled (SSH protection by default)."
}

tw_unattended() {
  ensure_pkg unattended-upgrades || return
  printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' \
    | $SUDO tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
  $SUDO systemctl enable --now unattended-upgrades 2>/dev/null
  ui_msg "Unattended security updates enabled."
}

tw_timezone() {
  local tz; tz=$(ui_input "Timezone" "Asia/Yerevan")
  [ -n "$tz" ] || return
  $SUDO timedatectl set-timezone "$tz" && ui_msg "Timezone: $tz"
}

tw_swap() {
  if swapon --show 2>/dev/null | grep -q .; then
    ui_yesno "Swap already exists. Create /swapfile anyway?" || return
  fi
  local sz f=/swapfile
  sz=$(ui_input "Swap file size (e.g. 2G)" "2G")
  if [ -e "$f" ]; then ui_msg "$f already exists - skipping."; return; fi
  if ! $SUDO fallocate -l "$sz" "$f" 2>/dev/null; then
    local mb=${sz%[Gg]}; mb=$(( mb * 1024 ))
    $SUDO dd if=/dev/zero of="$f" bs=1M count="$mb" status=none
  fi
  $SUDO chmod 600 "$f"
  $SUDO mkswap "$f" >/dev/null
  $SUDO swapon "$f"
  grep -q "^$f " /etc/fstab 2>/dev/null || printf '%s none swap sw 0 0\n' "$f" | $SUDO tee -a /etc/fstab >/dev/null
  ui_msg "Swap created: $sz"
  free -h >/dev/tty
}

tw_hostname() {
  local h; h=$(ui_input "New hostname" "$(hostname)")
  [ -n "$h" ] || return
  $SUDO hostnamectl set-hostname "$h" && ui_msg "Hostname: $h"
}

tw_bbr() {
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' \
    | $SUDO tee /etc/sysctl.d/99-bbr.conf >/dev/null
  $SUDO sysctl --system >/dev/null 2>&1
  ui_msg "TCP BBR: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
}

tw_ssh_harden() {
  ui_msg "WARNING: disabling password login and root login." \
         "Make sure an SSH key is already set up - otherwise you will lose access!"
  ui_yesno "SSH key is set up, continue?" || return
  local d=/etc/ssh/sshd_config.d f
  if [ -d "$d" ]; then f="$d/99-hh-harden.conf"; else f=/etc/ssh/sshd_config; fi
  printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' \
    | $SUDO tee "$f" >/dev/null
  $SUDO systemctl restart ssh 2>/dev/null || $SUDO systemctl restart sshd 2>/dev/null
  log "SSH hardening applied (key-only)"
  ui_msg "SSH hardened. Verify a new login in a SEPARATE session before closing this one!"
}

# ===========================================================================
# NETWORK DIAGNOSTICS
# ===========================================================================

sec_netdiag() {
  local pick
  while :; do
    pick=$(ui_menu "Network diagnostics" \
      "Network Doctor - why the network is down" \
      "Ping sweep of subnet (live hosts)" \
      "Scan cameras/NVR (CCTV ports)" \
      "Check camera RTSP port" \
      "mtr - route with packet loss" \
      "iperf3 - bandwidth between hosts" \
      "speedtest - internet speed" \
      "<- Back") || return
    case "$pick" in
      "Network Doctor"*) nd_doctor ;;
      "Ping sweep"*)  nd_pingscan ;;
      "Scan cameras"*) nd_camscan ;;
      "Check camera RTSP"*) nd_rtsp ;;
      "mtr"*)        nd_mtr ;;
      "iperf3"*)     nd_iperf ;;
      "speedtest"*)  nd_speedtest ;;
      *) return ;;
    esac
  done
}

# report line: ok/bad/warn + label + detail
dl() {
  local m
  case "$1" in ok) m='[OK]' ;; bad) m='[!!]' ;; warn) m='[~]' ;; esac
  printf '  %-4s %s\n' "$m" "$2" >/dev/tty
  [ -n "${3:-}" ] && printf '        %s\n' "$3" >/dev/tty
  return 0
}

# Network Doctor: a battery of read-only "why is the network down" checks + verdict.
nd_doctor() {
  command -v ping >/dev/null 2>&1 || ensure_pkg iputils-ping >/dev/null 2>&1 || true
  local verdict='' dev gw ip dns pub ups o loss ipdead=0 gwok=0 netok=0 tgt
  printf '\n=== Network Doctor - network diagnostics ===\n\n' >/dev/tty

  # 1) link
  ups=$(ip -br link 2>/dev/null | awk '$1!="lo" && $2=="UP"{print $1}' | paste -sd', ' -)
  if [ -n "$ups" ]; then
    dl ok "Network interface is up" "$ups"
  else
    dl bad "No active interfaces" "Cable unplugged or the adapter is off."
    printf '\n  -> No physical connection.\n' >/dev/tty; pause; return
  fi

  # 2) IP / gateway / DNS
  dev=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  gw=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
  ip=$(ip -o -f inet addr show "$dev" 2>/dev/null | awk '{print $4; exit}')
  dns=$(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd', ' -)
  if [ -z "$ip" ]; then
    dl bad "No IPv4 address" "The adapter is up but no address is assigned."
    verdict+=$'\n  -> No IP - DHCP did not hand one out. Check DHCP on the router or set a static IP.'; ipdead=1
  elif printf '%s' "$ip" | grep -q '^169\.254\.'; then
    dl bad "APIPA address $ip" "DHCP did not answer (169.254.x.x)."
    verdict+=$'\n  -> The PC got no IP from DHCP. Check the cable to the router / the DHCP server.'; ipdead=1
  else
    dl ok "IPv4 address: $ip" "Gateway: ${gw:-none}; DNS: ${dns:-none}"
  fi

  # 3) gateway
  if [ -n "$gw" ] && [ "$ipdead" = 0 ]; then
    if o=$(ping -c3 -W1 "$gw" 2>/dev/null); then
      gwok=1; loss=$(printf '%s' "$o" | grep -oE '[0-9]+% packet loss' | head -1)
      dl ok "Gateway $gw responds" "$loss"
    else
      dl bad "Gateway $gw does not respond" "Router/local network unreachable."
      verdict+=$'\n  -> Gateway unreachable - the problem is in the LAN or the router.'
    fi
  fi

  # 4) internet (ICMP)
  if [ "$ipdead" = 0 ]; then
    for tgt in 1.1.1.1 8.8.8.8; do
      if o=$(ping -c3 -W1 "$tgt" 2>/dev/null); then
        netok=1; loss=$(printf '%s' "$o" | grep -oE '[0-9]+% packet loss' | head -1)
        dl ok "Internet reachable ($tgt)" "$loss"; break
      fi
    done
    if [ "$netok" = 0 ]; then
      dl bad "Internet unreachable (ICMP)" "Ping to 1.1.1.1 and 8.8.8.8 failed."
      [ "$gwok" = 1 ] && verdict+=$'\n  -> LAN is fine but no internet access - ISP/router (WAN).'
    fi
  fi

  # 5) DNS resolution
  if [ "$ipdead" = 0 ]; then
    if getent hosts cloudflare.com >/dev/null 2>&1; then
      dl ok "DNS resolves names" "cloudflare.com -> address received."
    else
      dl bad "DNS does not resolve names" "Site names are not translated to addresses."
      [ "$netok" = 1 ] && verdict+=$'\n  -> Internet works but DNS does not - switch DNS to 1.1.1.1 / 8.8.8.8.'
    fi
  fi

  # 6) external IP
  if [ "$netok" = 1 ]; then
    pub=$(fetch - https://api.ipify.org 2>/dev/null)
    [ -n "$pub" ] && dl ok "External IP: $pub" "Full internet access confirmed."
  fi

  printf '\n' >/dev/tty
  if [ -n "$verdict" ]; then
    printf '  Verdict:%s\n' "$verdict" >/dev/tty
  else
    printf '  -> Network is working fine: interface, IP, gateway, internet and DNS are all OK.\n' >/dev/tty
  fi
  pause
}

nd_pingscan() {
  ensure_pkg nmap || { pause; return; }
  local d; d=$(ui_input "Subnet/CIDR to scan" "$(default_cidr)")
  [ -n "$d" ] || return
  ui_msg "Ping sweep of $d ..."
  $SUDO nmap -sn "$d" 2>&1 | page
  pause
}

nd_camscan() {
  ensure_pkg nmap || { pause; return; }
  local t; t=$(ui_input "Host or subnet (camera/NVR)" "$(default_cidr)")
  [ -n "$t" ] || return
  ui_msg "Looking for cameras/NVR in $t" "ports 80,443,554,8000,37777,34567,8899,88 ..."
  $SUDO nmap -p 80,443,554,8000,37777,34567,8899,88 --open "$t" 2>&1 | page
  pause
}

nd_rtsp() {
  local h port
  h=$(ui_input "Camera IP" ""); [ -n "$h" ] || return
  port=$(ui_input "RTSP port" "554")
  if timeout 3 bash -c "exec 3<>/dev/tcp/$h/$port" 2>/dev/null; then
    ui_msg "Port $h:$port is OPEN - RTSP is listening."
    if command -v ffprobe >/dev/null 2>&1; then
      local url; url=$(ui_input "RTSP URL for ffprobe" "rtsp://$h:$port/")
      [ -n "$url" ] && ffprobe -v error -rtsp_transport tcp -show_streams \
        -of default=noprint_wrappers=1 "$url" 2>&1 | page
    else
      ui_msg "Install the ffmpeg package - then I can probe the stream (ffprobe): resolution/codec."
    fi
  else
    ui_msg "Port $h:$port is closed or unreachable."
  fi
  pause
}

nd_mtr() {
  ensure_pkg mtr-tiny || ensure_pkg mtr || { pause; return; }
  local h; h=$(ui_input "Destination host" "1.1.1.1"); [ -n "$h" ] || return
  ui_msg "mtr to $h (10 cycles)..."
  $SUDO mtr -rwc 10 "$h" 2>&1 | page
  pause
}

nd_iperf() {
  ensure_pkg iperf3 || { pause; return; }
  local mode h
  mode=$(ui_menu "iperf3" \
    "Server (accept one measurement)" \
    "Client (connect to a server)" \
    "<- Back") || return
  case "$mode" in
    "Server"*)
      ui_msg "iperf3 -s on port 5201 - waiting for one measurement from a client..."
      iperf3 -s -1 >/dev/tty 2>&1 ;;
    "Client"*)
      h=$(ui_input "iperf3 server IP" ""); [ -n "$h" ] || return
      iperf3 -c "$h" 2>&1 | page ;;
    *) return ;;
  esac
  pause
}

nd_speedtest() {
  ensure_pkg speedtest-cli || { pause; return; }
  ui_msg "Measuring internet speed..."
  speedtest-cli 2>&1 | page
  pause
}

# ===========================================================================
# DOCKER AND SERVICES
# ===========================================================================

sec_docker() {
  local pick
  while :; do
    pick=$(ui_menu "Docker & services" \
      "Install Docker + compose" \
      "Deploy ready-made stacks (checkboxes)" \
      "Container status" \
      "<- Back") || return
    case "$pick" in
      "Install Docker"*) dk_install ;;
      "Deploy"*)        dk_stacks ;;
      "Container status"*) dk_status ;;
      *) return ;;
    esac
  done
}

dk_install() {
  if command -v docker >/dev/null 2>&1; then
    ui_msg "Docker is already installed: $(docker --version)"; pause; return
  fi
  ui_yesno "Install Docker via the official get.docker.com script?" || return
  ui_msg "Installing Docker..."
  fetch - https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker 2>/dev/null
  if [ -n "$SUDO" ]; then
    $SUDO usermod -aG docker "$USER"
    ui_msg "User $USER added to the docker group - re-login to use it without sudo."
  fi
  docker --version >/dev/tty 2>&1
  pause
}

dk_stacks() {
  command -v docker >/dev/null 2>&1 || { ui_msg "Install Docker first."; pause; return; }
  local sel t
  sel=$(ui_checklist "Ready-made stacks - tick the boxes" \
    "portainer|Portainer - Docker web panel (port 9443)" \
    "npm|Nginx Proxy Manager - reverse proxy + HTTPS (port 81)" \
    "watchtower|Watchtower - auto-update containers") || return
  [ -n "$sel" ] || { ui_msg "Nothing selected."; pause; return; }
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
  ui_msg "Portainer is up: https://<server-IP>:9443 (set the admin password on first login)."
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
  ui_msg "Nginx Proxy Manager: http://<server-IP>:81" "Default login: admin@example.com / changeme"
}

dk_deploy_watchtower() {
  $SUDO docker rm -f watchtower >/dev/null 2>&1 || true
  $SUDO docker run -d --name watchtower --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --cleanup
  ui_msg "Watchtower started - containers will update automatically."
}

dk_status() {
  command -v docker >/dev/null 2>&1 || { ui_msg "Docker is not installed."; pause; return; }
  { $SUDO docker ps; printf '\n--- compose projects ---\n'; $SUDO docker compose ls 2>/dev/null; } 2>&1 | page
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
      "Set up server" \
      "Add client (QR)" \
      "Status / client list" \
      "<- Back") || return
    case "$pick" in
      "Set up server")   wg_setup_server ;;
      "Add client"*) wg_add_client ;;
      "Status"*)          wg_status ;;
      *) return ;;
    esac
  done
}

wg_setup_server() {
  ensure_pkg wireguard || { pause; return; }
  ensure_pkg iptables >/dev/null 2>&1 || true
  ensure_pkg qrencode >/dev/null 2>&1 || true
  if [ -f "$WG_CONF" ]; then
    ui_yesno "Server wg0 is already configured. Reconfigure from scratch (wipes clients)?" || return
    $SUDO systemctl stop wg-quick@wg0 2>/dev/null
  fi
  local nic pub port skey spub
  nic=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  pub=$(fetch - https://api.ipify.org 2>/dev/null)
  pub=$(ui_input "Server external IP/domain" "${pub:-}"); [ -n "$pub" ] || return
  port=$(ui_input "UDP port" "$WG_PORT")
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
  ui_msg "WireGuard server is up (wg0, network ${WG_NET}.0/24, port ${port})." \
         "Now add a client to get a config with a QR code."
  pause
}

wg_add_client() {
  [ -f "$WG_CONF" ] || { ui_msg "Set up the server first."; pause; return; }
  local name; name=$(ui_input "Client name (Latin letters)" "client1"); [ -n "$name" ] || return
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
  # apply live, otherwise restart the interface
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
  { printf '\n=== Client config %s ===\n\n%s\n\n' "$name" "$ccfg"; } >/dev/tty
  if command -v qrencode >/dev/null 2>&1; then
    { printf '=== QR (scan it in the WireGuard app) ===\n\n'; } >/dev/tty
    printf '%s' "$ccfg" | qrencode -t ansiutf8 >/dev/tty
  else
    ui_msg "Install the qrencode package for a QR code. Copy the config above manually."
  fi
  out="/etc/wireguard/${name}.conf"
  printf '%s\n' "$ccfg" | $SUDO tee "$out" >/dev/null
  $SUDO chmod 600 "$out"
  ui_msg "Client config saved: $out"
  pause
}

wg_status() {
  command -v wg >/dev/null 2>&1 || { ui_msg "WireGuard is not installed."; pause; return; }
  {
    $SUDO wg show
    printf '\nClients in the config:\n'
    $SUDO grep '# HH_CLIENT=' "$WG_CONF" 2>/dev/null | sed 's/# HH_CLIENT=/  - /' || printf '  (none)\n'
  } 2>&1 | page
  pause
}

# ===========================================================================
# USERS AND ACCESS
# ===========================================================================

sec_users() {
  local pick
  while :; do
    pick=$(ui_menu "Users & access" \
      "Create sudo user" \
      "Add SSH key to a user" \
      "Change SSH port" \
      "Reverse SSH tunnel (access behind NAT)" \
      "Scheduled backup (rsync + cron)" \
      "<- Back") || return
    case "$pick" in
      "Create sudo"*)   usr_add ;;
      "Add SSH"*)   usr_addkey ;;
      "Change SSH port") usr_sshport ;;
      "Reverse SSH"*)   usr_revssh ;;
      "Scheduled backup"*)          usr_backup ;;
      *) return ;;
    esac
  done
}

usr_add() {
  local u; u=$(ui_input "New user name" ""); [ -n "$u" ] || return
  if id "$u" >/dev/null 2>&1; then ui_msg "User $u already exists."; pause; return; fi
  $SUDO adduser --disabled-password --gecos "" "$u"
  ui_msg "Set a password for $u (input hidden):"
  $SUDO passwd "$u" </dev/tty
  $SUDO usermod -aG sudo "$u"
  ui_msg "User $u created and added to the sudo group."
  pause
}

usr_addkey() {
  local u key dir
  u=$(ui_input "User" "$USER"); [ -n "$u" ] || return
  id "$u" >/dev/null 2>&1 || { ui_msg "No such user: $u"; pause; return; }
  key=$(ui_input "Paste the public SSH key (ssh-ed25519/ssh-rsa ...)" "")
  case "$key" in ssh-*) : ;; *) ui_msg "This does not look like a public key (must start with ssh-)."; pause; return ;; esac
  dir=$(getent passwd "$u" | cut -d: -f6)/.ssh
  $SUDO mkdir -p "$dir"
  printf '%s\n' "$key" | $SUDO tee -a "$dir/authorized_keys" >/dev/null
  $SUDO chmod 700 "$dir"; $SUDO chmod 600 "$dir/authorized_keys"
  $SUDO chown -R "$u:$u" "$dir"
  ui_msg "Key added for user $u."
  pause
}

usr_sshport() {
  local cur p d f
  cur=$(ssh_port)
  p=$(ui_input "New SSH port" "$cur"); [ -n "$p" ] || return
  case "$p" in ''|*[!0-9]*) ui_msg "The port must be a number."; pause; return ;; esac
  ui_msg "WARNING: I'll open port $p in UFW, then change the port and restart SSH." \
         "Do NOT close the current session until you verify login on the new port!"
  ui_yesno "Continue?" || return
  command -v ufw >/dev/null 2>&1 && $SUDO ufw allow "${p}/tcp" >/dev/null 2>&1
  d=/etc/ssh/sshd_config.d
  if [ -d "$d" ]; then
    f="$d/99-hh-port.conf"; printf 'Port %s\n' "$p" | $SUDO tee "$f" >/dev/null
  else
    $SUDO sed -i "s/^#\?Port .*/Port $p/" /etc/ssh/sshd_config
  fi
  $SUDO systemctl restart ssh 2>/dev/null || $SUDO systemctl restart sshd 2>/dev/null
  log "SSH port changed -> $p"
  ui_msg "SSH is now on port $p. Verify from a NEW window:  ssh -p $p user@host"
  pause
}

usr_backup() {
  ensure_pkg rsync || { pause; return; }
  local src dst freq sched mark cronline
  src=$(ui_input "What to back up (source directory)" "/etc"); [ -n "$src" ] || return
  dst=$(ui_input "Where to store it (destination directory)" "/var/backups/hh"); [ -n "$dst" ] || return
  freq=$(ui_menu "How often?" "Daily (03:00)" "Weekly (Sun 03:00)" "Hourly" "<- Cancel") || return
  case "$freq" in
    "Daily"*)   sched="0 3 * * *" ;;
    "Weekly"*) sched="0 3 * * 0" ;;
    "Hourly")     sched="0 * * * *" ;;
    *) return ;;
  esac
  $SUDO mkdir -p "$dst"
  mark="# HH-backup ${src}"
  cronline="${sched} rsync -a --delete '${src}' '${dst}' ${mark}"
  { $SUDO crontab -l 2>/dev/null | grep -vF "$mark"; printf '%s\n' "$cronline"; } | $SUDO crontab -
  ui_msg "Backup configured: $src -> $dst ($freq)." "The job is written to root's crontab."
  pause
}

usr_revssh() {
  ensure_pkg autossh || { pause; return; }
  ui_msg "Reverse SSH tunnel: the machine connects out to a relay server with a public IP" \
         "and forwards its own SSH back. You need an SSH KEY to the relay already set up" \
         "(autossh does not type a password - make sure 'ssh relay' works without one)."
  local relay rport remote lport name svc
  relay=$(ui_input "Relay: user@host (e.g. root@vps.example.com)" ""); [ -n "$relay" ] || return
  rport=$(ui_input "Relay SSH port" "22")
  remote=$(ui_input "Port on the relay to forward (then: ssh -p THIS localhost)" "2222")
  lport=$(ui_input "Local port on this machine" "22")
  name=$(ui_input "Tunnel name (Latin letters)" "main"); [ -n "$name" ] || return
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
  ui_msg "Tunnel '${name}' is up as service ${svc}." \
         "From the relay: ssh -p ${remote} localhost - you land on this machine." \
         "If status is failed - check the SSH key to ${relay}."
  pause
}

# ===========================================================================
# NETWORK AND WEB
# ===========================================================================

sec_netweb() {
  local pick
  while :; do
    pick=$(ui_menu "Network & web" \
      "Static IP (netplan)" \
      "UFW firewall (rules & ports)" \
      "Certbot - HTTPS for nginx" \
      "<- Back") || return
    case "$pick" in
      "Static IP"*) nw_static ;;
      "UFW firewall"*)    nw_firewall ;;
      "Certbot"*)        nw_certbot ;;
      *) return ;;
    esac
  done
}

nw_static() {
  command -v netplan >/dev/null 2>&1 || { ui_msg "netplan not found - you need an Ubuntu server with netplan."; pause; return; }
  local nic cur_ip cur_gw cur_dns ip gw dns dns_yaml f how
  nic=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
  nic=$(ui_input "Network interface" "${nic:-eth0}"); [ -n "$nic" ] || return
  cur_ip=$(ip -o -f inet addr show "$nic" 2>/dev/null | awk '{print $4; exit}')
  cur_gw=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
  cur_dns=$(grep -h '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd, -)
  ip=$(ui_input "IP/mask (CIDR, e.g. 192.168.1.50/24)" "$cur_ip"); [ -n "$ip" ] || return
  gw=$(ui_input "Gateway" "$cur_gw")
  dns=$(ui_input "DNS, comma-separated" "${cur_dns:-1.1.1.1,8.8.8.8}")
  dns_yaml=$(printf '%s' "$dns" | sed 's/ *, */, /g')
  ui_msg "WARNING: changing the IP will drop the SSH session if the address changes!" \
         "Make sure you can reconnect on the new address."
  ui_yesno "Write the config?" || return
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
  how=$(ui_menu "How to apply?" \
    "netplan try (safe - auto-rollback after 120s)" \
    "netplan apply (immediately)" \
    "Write config only, do not apply") || return
  case "$how" in
    "netplan try"*)   $SUDO netplan try </dev/tty ;;
    "netplan apply"*) log "static IP $ip on $nic (gateway $gw)"; $SUDO netplan apply && ui_msg "Applied. New address: $ip" ;;
    *) ui_msg "Config written to $f, not applied." ;;
  esac
  pause
}

nw_certbot() {
  command -v nginx >/dev/null 2>&1 || ui_msg "nginx is not installed - the cert is written into its config. Install nginx under 'Install packages'."
  ensure_pkg certbot || { pause; return; }
  ensure_pkg python3-certbot-nginx || { pause; return; }
  local domain email args=() d
  domain=$(ui_input "Domain (several - space-separated)" ""); [ -n "$domain" ] || return
  email=$(ui_input "Email for Let's Encrypt (empty - no email)" "")
  ui_msg "Required: the domain points to this server (A record), port 80 open, nginx running."
  ui_yesno "Get the certificate now?" || return
  for d in $domain; do args+=(-d "$d"); done
  if [ -n "$email" ]; then
    $SUDO certbot --nginx "${args[@]}" -m "$email" --agree-tos -n --redirect 2>&1 | page
  else
    $SUDO certbot --nginx "${args[@]}" --register-unsafely-without-email --agree-tos -n --redirect 2>&1 | page
  fi
  pause
}

# current SSH port (to avoid self-lockout in UFW rules)
ssh_port() {
  local p
  p=$($SUDO grep -rhm1 '^Port ' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ 2>/dev/null | awk '{print $2; exit}')
  [ -n "$p" ] || p=22
  printf '%s' "$p"
}

nw_firewall() {
  ensure_pkg ufw || { pause; return; }
  local pick p ip n cur sshp
  sshp=$(ssh_port)
  while :; do
    pick=$(ui_menu "UFW firewall (SSH is currently on port $sshp)" \
      "Status and rules (numbered)" \
      "Open a port" \
      "Delete rule by number" \
      "Allow everything from one IP" \
      "Enable firewall" \
      "Disable firewall" \
      "Reset to safe minimum (SSH only)" \
      "<- Back") || return
    case "$pick" in
      "Status"*)
        $SUDO ufw status numbered verbose 2>&1 | page
        pause ;;
      "Open a port")
        p=$(ui_input "Port (e.g. 8080/tcp, 5000:5010/udp)" "")
        [ -n "$p" ] || continue
        case "$p" in *[/:]*) : ;; *) p="${p}/tcp" ;; esac
        $SUDO ufw allow "$p" >/dev/tty 2>&1
        pause ;;
      "Delete rule"*)
        $SUDO ufw status numbered >/dev/tty 2>&1
        n=$(ui_input "Rule number to delete" "")
        case "$n" in ''|*[!0-9]*) ui_msg "The number must be numeric."; pause; continue ;; esac
        cur=$($SUDO ufw status numbered 2>/dev/null | awk -v n="[$n]" '$1==n')
        [ -n "$cur" ] || { ui_msg "No rule with number $n."; pause; continue; }
        ui_msg "Rule: $cur"
        if printf '%s' "$cur" | grep -qE "(^|[^0-9])${sshp}(/|[[:space:]])|OpenSSH|(^|[[:space:]])SSH"; then
          ui_msg "WARNING: this is an SSH rule (port $sshp) - you may lose access to the server."
        fi
        ui_yesno "Really delete?" || continue
        $SUDO ufw --force delete "$n" >/dev/tty 2>&1
        pause ;;
      "Allow everything"*)
        ip=$(ui_input "IP address (e.g. 192.168.1.10)" "")
        [ -n "$ip" ] || continue
        $SUDO ufw allow from "$ip" >/dev/tty 2>&1
        pause ;;
      "Enable firewall")
        if ! $SUDO ufw status 2>/dev/null | grep -qE "(^|[[:space:]])(${sshp}(/tcp)?|OpenSSH)([[:space:]]|$)"; then
          ui_msg "SSH ($sshp) is not allowed in the rules - adding it, otherwise you lose access."
          $SUDO ufw allow "${sshp}/tcp" >/dev/null 2>&1
        fi
        $SUDO ufw --force enable >/dev/tty 2>&1
        pause ;;
      "Disable firewall")
        $SUDO ufw disable >/dev/tty 2>&1
        pause ;;
      "Reset"*)
        ui_msg "Reset will remove ALL rules and keep only SSH ($sshp):" \
               "incoming - denied, outgoing - allowed."
        ui_yesno "Continue?" || continue
        $SUDO ufw --force reset >/dev/null 2>&1
        $SUDO ufw default deny incoming >/dev/null 2>&1
        $SUDO ufw default allow outgoing >/dev/null 2>&1
        $SUDO ufw allow "${sshp}/tcp" >/dev/null 2>&1
        $SUDO ufw --force enable >/dev/null 2>&1
        $SUDO ufw status verbose >/dev/tty 2>&1
        pause ;;
      *) return ;;
    esac
  done
}

# ===========================================================================
# MAINTENANCE AND MONITORING
# ===========================================================================

sec_maint() {
  local pick
  while :; do
    pick=$(ui_menu "Maintenance & monitoring" \
      "Clean up system (free space)" \
      "netdata - web monitoring" \
      "SSH logs & fail2ban" \
      "Scheduled tasks (cron)" \
      "Logs (journalctl, dmesg)" \
      "<- Back") || return
    case "$pick" in
      "Clean up"*)   mt_clean ;;
      "netdata"*)  mt_netdata ;;
      "SSH logs"*) mt_sshlog ;;
      "Scheduled tasks"*) mt_cron ;;
      "Logs"*)  mt_logs ;;
      *) return ;;
    esac
  done
}

mt_clean() {
  local before after
  before=$(df -h / | awk 'NR==2{print $4}')
  ui_msg "Will do: apt autoremove/clean + vacuum journals older than 7 days" \
         "(and docker prune, if Docker is installed - with a separate confirmation)."
  ui_yesno "Continue cleanup?" || return
  $SUDO apt-get autoremove --purge -y
  $SUDO apt-get clean
  $SUDO journalctl --vacuum-time=7d 2>&1 | tail -n 3 >/dev/tty
  if command -v docker >/dev/null 2>&1; then
    if ui_yesno "docker system prune -af (remove unused images/volumes)?"; then
      $SUDO docker system prune -af
    fi
  fi
  after=$(df -h / | awk 'NR==2{print $4}')
  ui_msg "Free on /:  was $before  ->  now $after"
  pause
}

mt_netdata() {
  if systemctl is-active --quiet netdata 2>/dev/null || command -v netdata >/dev/null 2>&1; then
    ui_msg "netdata is already installed. Web panel: http://<server-IP>:19999"
    systemctl status netdata --no-pager 2>&1 | head -n 6 >/dev/tty
    pause; return
  fi
  ui_yesno "Install netdata (official installer)?" || return
  ui_msg "Installing netdata..."
  fetch - https://get.netdata.cloud/kickstart.sh | $SUDO sh -s -- --dont-wait --disable-telemetry
  if command -v ufw >/dev/null 2>&1 && ui_yesno "Open port 19999 in UFW?"; then
    $SUDO ufw allow 19999/tcp >/dev/null 2>&1
  fi
  ui_msg "Done. Web panel: http://<server-IP>:19999"
  pause
}

mt_sshlog() {
  local pick ipp
  while :; do
    pick=$(ui_menu "SSH logs & fail2ban" \
      "Recent logins" \
      "Failed login attempts" \
      "Banned IPs (fail2ban)" \
      "Unban IP (fail2ban)" \
      "<- Back") || return
    case "$pick" in
      "Recent logins")
        { echo "# last -n 20:"; last -n 20 2>/dev/null; } | page ;;
      "Failed"*)
        {
          if [ -f /var/log/auth.log ]; then
            $SUDO grep -a 'Failed password' /var/log/auth.log 2>/dev/null | tail -n 30
          else
            $SUDO journalctl _COMM=sshd 2>/dev/null | grep -a 'Failed password' | tail -n 30
          fi
          echo "(if empty - no failed attempts, or logs are elsewhere)"
        } | page ;;
      "Banned"*)
        if command -v fail2ban-client >/dev/null 2>&1; then
          $SUDO fail2ban-client status sshd 2>&1 | page
        else
          ui_msg "fail2ban is not installed (install it under 'Server tweaks')."; pause
        fi ;;
      "Unban"*)
        if command -v fail2ban-client >/dev/null 2>&1; then
          ipp=$(ui_input "IP to unban" ""); [ -n "$ipp" ] || continue
          $SUDO fail2ban-client set sshd unbanip "$ipp" >/dev/tty 2>&1
          ui_msg "Unbanned: $ipp"; pause
        else
          ui_msg "fail2ban is not installed."; pause
        fi ;;
      *) return ;;
    esac
  done
}

mt_cron() {
  local pick cmd sched line n list
  while :; do
    pick=$(ui_menu "Scheduled tasks (cron)" \
      "Show tasks" \
      "Add task" \
      "Delete task" \
      "<- Back") || return
    case "$pick" in
      "Show tasks"*)
        {
          printf '\n# root crontab\n'
          $SUDO crontab -l 2>/dev/null || printf '  (empty)\n'
          printf '\n# %s crontab\n' "$USER"
          crontab -l 2>/dev/null || printf '  (empty)\n'
          printf '\n# system jobs (/etc/cron.d)\n'
          find /etc/cron.d -maxdepth 1 -type f -printf '  %f\n' 2>/dev/null
        } 2>&1 | page
        pause ;;
      "Add task"*)
        cmd=$(ui_input "Command (use full paths - cron has a minimal PATH)" "")
        [ -n "$cmd" ] || continue
        sched=$(ui_menu "When to run?" \
          "Every 5 minutes" \
          "Every hour" \
          "Every day at 03:00" \
          "Every week (Sun 03:00)" \
          "Custom cron line" \
          "<- Cancel") || continue
        case "$sched" in
          "Every 5"*)      line="*/5 * * * *" ;;
          "Every hour")     line="0 * * * *" ;;
          "Every day"*)   line="0 3 * * *" ;;
          "Every week"*) line="0 3 * * 0" ;;
          "Custom"*)   line=$(ui_input "Schedule (min hour day month weekday)" "0 3 * * *") ;;
          *) continue ;;
        esac
        [ -n "$line" ] || continue
        { $SUDO crontab -l 2>/dev/null; printf '%s %s\n' "$line" "$cmd"; } | $SUDO crontab -
        ui_msg "Added to root's crontab:" "$line $cmd"
        pause ;;
      "Delete task"*)
        list=$($SUDO crontab -l 2>/dev/null | grep -vE '^[[:space:]]*($|#)')
        [ -n "$list" ] || { ui_msg "root has no tasks."; pause; continue; }
        { printf '\n'; printf '%s\n' "$list" | nl -w2 -s') '; } >/dev/tty
        n=$(ui_input "Task number to delete" "")
        case "$n" in ''|*[!0-9]*) ui_msg "The number must be numeric."; pause; continue ;; esac
        cmd=$(printf '%s\n' "$list" | sed -n "${n}p")
        [ -n "$cmd" ] || { ui_msg "No task #$n."; pause; continue; }
        ui_msg "Deleting: $cmd"
        ui_yesno "Sure?" || continue
        $SUDO crontab -l 2>/dev/null | grep -vxF "$cmd" | $SUDO crontab -
        ui_msg "Deleted."
        pause ;;
      *) return ;;
    esac
  done
}

mt_logs() {
  local pick u n q
  while :; do
    pick=$(ui_menu "Logs" \
      "Recent system errors" \
      "Service log" \
      "Kernel messages (dmesg)" \
      "Search the journal" \
      "Journal size & cleanup" \
      "<- Back") || return
    case "$pick" in
      "Recent system errors"*)
        $SUDO journalctl -p err -n 100 --no-pager 2>&1 | page
        pause ;;
      "Service log")
        u=$(svc_pick) || continue
        n=$(ui_input "How many last lines" "200")
        $SUDO journalctl -u "$u" -n "${n:-200}" --no-pager 2>&1 | page
        pause ;;
      "Kernel messages"*)
        $SUDO dmesg -T 2>&1 | tail -n 200 | page
        pause ;;
      "Search the journal")
        q=$(ui_input "What to search for (e.g. error, sshd, timeout)" "")
        [ -n "$q" ] || continue
        $SUDO journalctl --no-pager -n 5000 2>/dev/null | grep -iF -- "$q" | tail -n 200 | page
        pause ;;
      "Journal size"*)
        $SUDO journalctl --disk-usage >/dev/tty 2>&1
        if ui_yesno "Shrink journals to 200 MB?"; then
          $SUDO journalctl --vacuum-size=200M 2>&1 | tail -n 3 | page
        fi
        pause ;;
      *) return ;;
    esac
  done
}

# ===========================================================================
# SERVICES AND PROCESSES
# ===========================================================================

sec_services() {
  local pick
  while :; do
    pick=$(ui_menu "Services & processes" \
      "List services" \
      "Manage a service" \
      "Service log" \
      "Who holds a port" \
      "Kill a process" \
      "Top processes" \
      "<- Back") || return
    case "$pick" in
      "List services")     svc_list ;;
      "Manage a service") svc_manage ;;
      "Service log")       svc_log ;;
      "Who holds a port")   svc_port ;;
      "Kill a process")    svc_kill ;;
      "Top processes")    svc_top ;;
      *) return ;;
    esac
  done
}

# pick a systemd unit: service name to stdout, 1 - if cancelled
svc_pick() {
  local f units=() u sel
  f=$(ui_input "Part of a service name (empty - show running)" "")
  if [ -n "$f" ]; then
    while IFS= read -r u; do
      [ -n "$u" ] && units+=("$u")
    done < <(systemctl list-units --type=service --all --no-legend --plain --no-pager 2>/dev/null \
             | awk '{print $1}' | grep -iF -- "$f" | head -n 30)
  else
    while IFS= read -r u; do
      [ -n "$u" ] && units+=("$u")
    done < <(systemctl list-units --type=service --state=running --no-legend --plain --no-pager 2>/dev/null \
             | awk '{print $1}' | head -n 30)
  fi
  if [ "${#units[@]}" -eq 0 ]; then
    { ui_msg "No services found."; pause; } >/dev/tty
    return 1
  fi
  sel=$(ui_menu "Choose a service" "${units[@]}" "<- Back") || return 1
  if [ -z "$sel" ] || [ "$sel" = "<- Back" ]; then return 1; fi
  printf '%s' "$sel"
}

svc_list() {
  local what f
  what=$(ui_menu "Which services to show?" \
    "Running" \
    "Failed" \
    "Enabled at boot" \
    "Search by name" \
    "<- Back") || return
  case "$what" in
    "Running")
      $SUDO systemctl list-units --type=service --state=running --no-pager 2>&1 | page ;;
    "Failed"*)
      $SUDO systemctl list-units --type=service --state=failed --no-pager 2>&1 | page ;;
    "Enabled at boot")
      $SUDO systemctl list-unit-files --type=service --state=enabled --no-pager 2>&1 | page ;;
    "Search by name")
      f=$(ui_input "Part of the name" ""); [ -n "$f" ] || return
      $SUDO systemctl list-units --type=service --all --no-pager 2>&1 | grep -iF -- "$f" | page ;;
    *) return ;;
  esac
  pause
}

svc_manage() {
  local u act
  u=$(svc_pick) || return
  while :; do
    { printf '\n'; $SUDO systemctl --no-pager --full status "$u" 2>&1 | head -n 12; } >/dev/tty
    act=$(ui_menu "Service $u" \
      "Restart" \
      "Stop" \
      "Start" \
      "Autostart: enable" \
      "Autostart: disable" \
      "Show log" \
      "<- Back") || return
    case "$act" in
      "Restart") $SUDO systemctl restart "$u" >/dev/tty 2>&1 ;;
      "Stop")
        case "$u" in
          ssh*) ui_yesno "This is SSH - stopping it will cut remote access. Sure?" || continue ;;
        esac
        $SUDO systemctl stop "$u" >/dev/tty 2>&1 ;;
      "Start")     $SUDO systemctl start "$u" >/dev/tty 2>&1 ;;
      "Autostart: enable")  $SUDO systemctl enable "$u" >/dev/tty 2>&1 ;;
      "Autostart: disable") $SUDO systemctl disable "$u" >/dev/tty 2>&1 ;;
      "Show log")  $SUDO journalctl -u "$u" -n 200 --no-pager 2>&1 | page; pause ;;
      *) return ;;
    esac
  done
}

svc_log() {
  local u n
  u=$(svc_pick) || return
  n=$(ui_input "How many last lines" "200")
  $SUDO journalctl -u "$u" -n "${n:-200}" --no-pager 2>&1 | page
  pause
}

svc_port() {
  local p
  p=$(ui_input "Port (empty - show all listening)" "")
  {
    if [ -n "$p" ]; then
      printf '# sockets on port %s\n' "$p"
      $SUDO ss -tulnp 2>/dev/null | awk -v p=":$p" 'NR==1 || index($5, p)'
      if command -v lsof >/dev/null 2>&1; then
        printf '\n# processes (lsof)\n'
        $SUDO lsof -i ":$p" -n -P 2>/dev/null
      else
        printf '\n(install the lsof package - I will show processes in more detail)\n'
      fi
    else
      printf '# all listening sockets\n'
      $SUDO ss -tulnp 2>/dev/null
    fi
  } 2>&1 | page
  pause
}

svc_kill() {
  local q pid list name
  q=$(ui_input "Process name or PID" ""); [ -n "$q" ] || return
  if [[ $q =~ ^[0-9]+$ ]]; then
    pid=$q
  else
    list=$(pgrep -a -f -- "$q" 2>/dev/null | head -n 20)
    [ -n "$list" ] || { ui_msg "Not found: $q"; pause; return; }
    { printf '\n%s\n' "$list"; } >/dev/tty
    pid=$(ui_input "PID from the list above" "$(printf '%s' "$list" | awk 'NR==1{print $1}')")
  fi
  case "$pid" in ''|*[!0-9]*) ui_msg "The PID must be numeric."; pause; return ;; esac
  if [ "$pid" = 1 ]; then ui_msg "PID 1 (init) cannot be killed."; pause; return; fi
  name=$(ps -p "$pid" -o comm= 2>/dev/null)
  [ -n "$name" ] || { ui_msg "No process with PID $pid."; pause; return; }
  case "$name" in
    sshd|systemd) ui_msg "WARNING: $name - you may lose access to the server." ;;
  esac
  ui_yesno "Kill $pid ($name)?" || return
  $SUDO kill "$pid" 2>/dev/null
  sleep 1
  if ps -p "$pid" >/dev/null 2>&1; then
    if ui_yesno "Did not exit. Force kill -9?"; then $SUDO kill -9 "$pid" 2>/dev/null; fi
  fi
  ui_msg "Done."
  pause
}

svc_top() {
  local by
  by=$(ui_menu "Top processes" "By CPU" "By memory" "<- Back") || return
  case "$by" in
    "By CPU")    ps aux --sort=-%cpu 2>/dev/null | head -n 25 | page ;;
    "By memory") ps aux --sort=-%mem 2>/dev/null | head -n 25 | page ;;
    *) return ;;
  esac
  pause
}

# ===========================================================================
# DISKS AND STORAGE
# ===========================================================================

sec_disks() {
  local pick
  while :; do
    pick=$(ui_menu "Disks & storage" \
      "Disks & partitions overview" \
      "SMART - disk health" \
      "Mount a partition (+ fstab)" \
      "Unmount" \
      "Partition & format a disk" \
      "What is using space" \
      "Samba share (access from Windows)" \
      "NFS export (access from Linux)" \
      "<- Back") || return
    case "$pick" in
      "Disks & partitions"*)  dsk_overview ;;
      "SMART"*)         dsk_smart ;;
      "Mount"*)  dsk_mount ;;
      "Unmount")  dsk_umount ;;
      "Partition"*)     dsk_format ;;
      "What is using"*)    dsk_space ;;
      "Samba"*)         dsk_samba ;;
      "NFS"*)           dsk_nfs ;;
      *) return ;;
    esac
  done
}

dsk_overview() {
  {
    printf '\n# Disks and partitions\n'
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null
    printf '\n# Filesystem usage\n'
    df -hT -x tmpfs -x devtmpfs 2>/dev/null
    printf '\n# Inodes (if they run out - "no space" even with free gigabytes)\n'
    df -i -x tmpfs -x devtmpfs 2>/dev/null
    printf '\n# Partition UUIDs\n'
    $SUDO blkid 2>/dev/null
  } 2>&1 | page
  pause
}

dsk_smart() {
  ensure_pkg smartmontools || { pause; return; }
  local list=() line sel dev act
  while IFS= read -r line; do
    [ -n "$line" ] && list+=("$line")
  done < <(lsblk -dn -e 7,11 -o PATH,SIZE,MODEL 2>/dev/null)
  [ "${#list[@]}" -gt 0 ] || { ui_msg "No disks found."; pause; return; }
  sel=$(ui_menu "Choose a disk" "${list[@]}" "<- Back") || return
  if [ -z "$sel" ] || [ "$sel" = "<- Back" ]; then return; fi
  dev=${sel%% *}
  act=$(ui_menu "SMART: $dev" \
    "Health (brief)" \
    "All attributes" \
    "Run short test (~2 minutes)" \
    "Last test result" \
    "<- Back") || return
  case "$act" in
    "Health"*)
      {
        $SUDO smartctl -H -i "$dev"
        printf '\n# Key attributes (bad if non-zero: Reallocated, Pending, Uncorrectable)\n'
        $SUDO smartctl -A "$dev" 2>/dev/null | grep -Ei 'reallocated|pending|uncorrect|power_on|temperature'
      } 2>&1 | page ;;
    "All attributes")
      $SUDO smartctl -A "$dev" 2>&1 | page ;;
    "Run short"*)
      $SUDO smartctl -t short "$dev" >/dev/tty 2>&1
      ui_msg "Test started in the background. In a couple of minutes check 'Last test result'." ;;
    "Last test"*)
      $SUDO smartctl -l selftest "$dev" 2>&1 | page ;;
    *) return ;;
  esac
  pause
}

dsk_mount() {
  local list=() line sel dev uuid fstype mp
  while IFS= read -r line; do
    [ -n "$line" ] && list+=("$line")
  done < <(lsblk -pn -e 7,11 -o PATH,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null | awk 'NF==3')
  [ "${#list[@]}" -gt 0 ] || { ui_msg "No unmounted partitions with a filesystem."; pause; return; }
  sel=$(ui_menu "Which partition to mount?" "${list[@]}" "<- Back") || return
  if [ -z "$sel" ] || [ "$sel" = "<- Back" ]; then return; fi
  dev=${sel%% *}
  fstype=$(lsblk -dn -o FSTYPE "$dev" 2>/dev/null)
  uuid=$(lsblk -dn -o UUID "$dev" 2>/dev/null)
  mp=$(ui_input "Mount point" "/mnt/${dev##*/}")
  [ -n "$mp" ] || return
  $SUDO mkdir -p "$mp"
  if ! $SUDO mount "$dev" "$mp" >/dev/tty 2>&1; then
    ui_msg "Mount failed (filesystem: ${fstype:-unknown})."
    pause; return
  fi
  ui_msg "Mounted: $dev -> $mp"
  ui_yesno "Add to /etc/fstab (mount at boot)?" || { pause; return; }
  $SUDO cp -a /etc/fstab /etc/fstab.hh.bak
  if [ -n "$uuid" ]; then
    printf 'UUID=%s %s %s defaults,nofail 0 2\n' "$uuid" "$mp" "${fstype:-auto}" | $SUDO tee -a /etc/fstab >/dev/null
  else
    printf '%s %s %s defaults,nofail 0 2\n' "$dev" "$mp" "${fstype:-auto}" | $SUDO tee -a /etc/fstab >/dev/null
  fi
  if $SUDO mount -a >/dev/tty 2>&1; then
    ui_msg "Written to /etc/fstab with the nofail flag - the server boots even if the disk is missing." \
           "Backup of the old file: /etc/fstab.hh.bak"
  else
    ui_msg "Error in /etc/fstab - rolling back from backup so the server does not hang at boot."
    $SUDO cp -a /etc/fstab.hh.bak /etc/fstab
  fi
  pause
}

dsk_umount() {
  local list=() line sel mp
  while IFS= read -r line; do
    [ -n "$line" ] && list+=("$line")
  done < <(lsblk -pn -e 7,11 -o PATH,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null \
           | awk 'NF==4 && $4 != "/" && $4 != "[SWAP]" && $4 !~ /^\/boot/')
  [ "${#list[@]}" -gt 0 ] || { ui_msg "Nothing to unmount (I don't touch system partitions)."; pause; return; }
  sel=$(ui_menu "What to unmount?" "${list[@]}" "<- Back") || return
  if [ -z "$sel" ] || [ "$sel" = "<- Back" ]; then return; fi
  mp=$(printf '%s' "$sel" | awk '{print $4}')
  if $SUDO umount "$mp" 2>/dev/tty; then
    ui_msg "Unmounted: $mp" "If the partition is in /etc/fstab - it will mount again on reboot."
  else
    ui_msg "Partition is busy. Who holds it:"
    $SUDO fuser -vm "$mp" >/dev/tty 2>&1 || $SUDO lsof +D "$mp" 2>/dev/null | head -n 10 >/dev/tty
  fi
  pause
}

dsk_format() {
  ensure_pkg parted || { pause; return; }
  local sysdisk root dev conf label part
  root=$(findmnt -no SOURCE / 2>/dev/null)
  sysdisk=$(lsblk -no PKNAME "$root" 2>/dev/null | head -n 1)
  {
    printf '\n# Disks (system disk: %s)\n' "${sysdisk:-unknown}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null
  } >/dev/tty
  ui_msg "DANGER: the disk will be re-partitioned (GPT + one ext4 partition)." \
         "ALL DATA ON IT WILL BE DESTROYED PERMANENTLY."
  dev=$(ui_input "Whole device (e.g. /dev/sdb)" "")
  [ -n "$dev" ] || return
  [ -b "$dev" ] || { ui_msg "$dev is not a block device."; pause; return; }
  if [ "$(lsblk -dn -o TYPE "$dev" 2>/dev/null)" != "disk" ]; then
    ui_msg "I need a whole disk, not a partition."; pause; return
  fi
  if [ -n "$sysdisk" ] && [ "$dev" = "/dev/$sysdisk" ]; then
    ui_msg "This is the system disk ($dev) - refusing to format."; pause; return
  fi
  if lsblk -n -o MOUNTPOINT "$dev" 2>/dev/null | grep -q '[^[:space:]]'; then
    ui_msg "$dev has mounted partitions - unmount them first."; pause; return
  fi
  conf=$(ui_input "To confirm, type EXACTLY: $dev" "")
  [ "$conf" = "$dev" ] || { ui_msg "Mismatch - cancelled."; pause; return; }
  label=$(ui_input "Volume label (Latin letters)" "data")
  ui_msg "Partitioning $dev ..."
  $SUDO wipefs -a "$dev" >/dev/null 2>&1
  $SUDO parted -s "$dev" mklabel gpt mkpart primary ext4 1MiB 100% >/dev/tty 2>&1
  $SUDO partprobe "$dev" 2>/dev/null
  sleep 2
  part=$(lsblk -pn -o PATH,TYPE "$dev" 2>/dev/null | awk '$2=="part"{print $1; exit}')
  [ -n "$part" ] || { ui_msg "Partition did not appear - check manually (lsblk)."; pause; return; }
  $SUDO mkfs.ext4 -F -L "$label" "$part" >/dev/tty 2>&1
  ui_msg "Done: $part (ext4, label $label)." \
         "Now mount it via 'Mount a partition'."
  pause
}

dsk_space() {
  local d
  d=$(ui_input "Directory to analyze" "/")
  [ -n "$d" ] || return
  if command -v ncdu >/dev/null 2>&1 && ui_yesno "Open interactive ncdu on $d?"; then
    $SUDO ncdu "$d" </dev/tty >/dev/tty 2>&1
    pause; return
  fi
  {
    printf '\n# Top 20 directories in %s\n' "$d"
    $SUDO du -h --max-depth=1 "$d" 2>/dev/null | sort -hr | head -n 20
    printf '\n# Top 10 large files (same filesystem only)\n'
    $SUDO find "$d" -xdev -type f -printf '%s %p\n' 2>/dev/null \
      | sort -nr | head -n 10 \
      | awk '{sz=$1; $1=""; sub(/^ /,""); printf "%8.1f MB  %s\n", sz/1048576, $0}'
  } 2>&1 | page
  pause
}

dsk_samba() {
  ensure_pkg samba || { pause; return; }
  local dir name mode user host
  dir=$(ui_input "Which folder to share" "/srv/share"); [ -n "$dir" ] || return
  name=$(ui_input "Share name (how Windows will see it)" "$(basename "$dir")"); [ -n "$name" ] || return
  mode=$(ui_menu "Access" \
    "By login & password (read-write)" \
    "Guest, read-only" \
    "<- Cancel") || return
  $SUDO mkdir -p "$dir"
  case "$mode" in
    "By login"*)
      user=$(ui_input "User (must exist in the system)" "$USER"); [ -n "$user" ] || return
      if ! id "$user" >/dev/null 2>&1; then
        ui_msg "No system user $user - create it under 'Users & access'."
        pause; return
      fi
      $SUDO chown -R "$user:$user" "$dir"
      $SUDO chmod 2770 "$dir"
      $SUDO tee -a /etc/samba/smb.conf >/dev/null <<CONF

[${name}]
   path = ${dir}
   browseable = yes
   read only = no
   valid users = ${user}
   create mask = 0664
   directory mask = 0775
CONF
      ui_msg "Set a Samba password for $user (separate from the system one):"
      $SUDO smbpasswd -a "$user" </dev/tty
      $SUDO smbpasswd -e "$user" >/dev/null 2>&1
      ;;
    "Guest"*)
      $SUDO chmod 755 "$dir"
      $SUDO tee -a /etc/samba/smb.conf >/dev/null <<CONF

[${name}]
   path = ${dir}
   browseable = yes
   read only = yes
   guest ok = yes
CONF
      ;;
    *) return ;;
  esac
  if ! $SUDO testparm -s >/dev/null 2>&1; then
    ui_msg "WARNING: testparm complains about /etc/samba/smb.conf - check the config."
  fi
  $SUDO systemctl restart smbd 2>/dev/null || $SUDO systemctl restart samba 2>/dev/null
  command -v ufw >/dev/null 2>&1 && $SUDO ufw allow samba >/dev/null 2>&1
  host=$(hostname -I 2>/dev/null | awk '{print $1}')
  ui_msg "Share is ready. In Windows Explorer:  \\\\${host:-server-IP}\\${name}" "Directory: $dir"
  pause
}

dsk_nfs() {
  ensure_pkg nfs-kernel-server || { pause; return; }
  local dir net mode opts host defnet
  dir=$(ui_input "Which folder to export" "/srv/nfs"); [ -n "$dir" ] || return
  # ponytail: guessing the subnet by zeroing the last octet - correct for /24, edit by hand for other masks
  defnet=$(default_cidr | sed 's/\.[0-9]\{1,3\}\//.0\//')
  net=$(ui_input "Who to allow (IP or subnet)" "$defnet"); [ -n "$net" ] || return
  mode=$(ui_menu "Access" "Read-write" "Read-only" "<- Cancel") || return
  case "$mode" in
    "Read-write") opts="rw,sync,no_subtree_check" ;;
    "Read-only")   opts="ro,sync,no_subtree_check" ;;
    *) return ;;
  esac
  $SUDO mkdir -p "$dir"
  printf '%s %s(%s)\n' "$dir" "$net" "$opts" | $SUDO tee -a /etc/exports >/dev/null
  $SUDO exportfs -ra >/dev/tty 2>&1
  $SUDO systemctl enable --now nfs-kernel-server >/dev/null 2>&1
  command -v ufw >/dev/null 2>&1 && $SUDO ufw allow nfs >/dev/null 2>&1
  $SUDO exportfs -v 2>&1 | page
  host=$(hostname -I 2>/dev/null | awk '{print $1}')
  ui_msg "Export is ready. On the client:" "sudo mount -t nfs ${host:-server-IP}:$dir /mnt/mountpoint"
  pause
}

# ===========================================================================
# MAIN LOOP
# ===========================================================================

main() {
  fix_console_font
  require_tty
  require_apt
  init_sudo
  log "=== start HH Toolbox Linux v$VERSION (user $(id -un)) ==="
  ensure_ui
  banner
  local pick
  while :; do
    pick=$(ui_menu "Main menu - $(hostname)" \
      "System info" \
      "Network info" \
      "Install packages (checkboxes)" \
      "Server tweaks & hardening" \
      "Services & processes" \
      "Disks & storage" \
      "Network diagnostics" \
      "Docker & services" \
      "WireGuard VPN" \
      "Users & access" \
      "Network & web" \
      "Maintenance & monitoring" \
      "Command reference" \
      "Exit") || break
    [ -n "$pick" ] && [ "$pick" != "Exit" ] && log "section: $pick"
    case "$pick" in
      "System info")         sec_sysinfo ;;
      "Network info")            sec_netinfo ;;
      "Install packages (checkboxes)") sec_install ;;
      "Server tweaks & hardening")    sec_tweaks ;;
      "Services & processes")            sec_services ;;
      "Disks & storage")            sec_disks ;;
      "Network diagnostics")             sec_netdiag ;;
      "Docker & services")             sec_docker ;;
      "WireGuard VPN")                sec_wireguard ;;
      "Users & access")        sec_users ;;
      "Network & web")                   sec_netweb ;;
      "Maintenance & monitoring")    sec_maint ;;
      "Command reference")            sec_commands ;;
      "Exit"|"") break ;;
    esac
  done
  printf 'Bye!\n' >/dev/tty
}

# HH_NORUN=1 - only load functions/data (for tests), do not show the menu
if [ -z "${HH_NORUN:-}" ]; then
  main "$@"
fi
