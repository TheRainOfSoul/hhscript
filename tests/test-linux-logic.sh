#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154
# Тесты данных/логики linux.sh (без сети). Запуск в CI (bash job).
# Грузим linux.sh с HH_NORUN=1 — только функции/данные, без меню.
set -u
export HH_NORUN=1
source "$(dirname "$0")/../linux.sh"

fail=0
check() { # $1=описание $2=факт $3=ожидание
  if [ "$2" = "$3" ]; then echo "  OK   $1 = $2"
  else echo "::error::FAIL $1 -> получено '$2', ожидалось '$3'"; fail=$((fail + 1)); fi
}

# APT_ITEMS: каждый пункт бьётся на «пакет|описание»
apt_bad=0
for it in "${APT_ITEMS[@]}"; do
  p=${it%%|*}; d=${it#*|}
  { [ -n "$p" ] && [ -n "$d" ] && [ "$p" != "$it" ]; } || apt_bad=$((apt_bad + 1))
done
check "APT_ITEMS разбор пакет|описание" "$apt_bad" "0"

# TWEAK_ITEMS: у каждого tag есть функция tw_<tag>
tw_bad=0
for it in "${TWEAK_ITEMS[@]}"; do
  t=${it%%|*}
  declare -F "tw_$t" >/dev/null || { echo "  нет tw_$t"; tw_bad=$((tw_bad + 1)); }
done
check "TWEAK_ITEMS -> tw_* определены" "$tw_bad" "0"

# CMDS: команда после @@ синтаксически валидна
cmd_bad=0
for it in "${CMDS[@]}"; do
  c=${it#*@@}
  bash -n -c "$c" 2>/dev/null || { echo "  битая команда: $c"; cmd_bad=$((cmd_bad + 1)); }
done
check "CMDS синтаксис команд" "$cmd_bad" "0"

# Ключевые секции/функции определены
for fn in main sec_netdiag nd_doctor sec_docker sec_wireguard sec_users dl; do
  if declare -F "$fn" >/dev/null; then echo "  OK   функция $fn определена"
  else echo "::error::FAIL нет функции $fn"; fail=$((fail + 1)); fi
done

if [ "$fail" = 0 ]; then echo "Все bash-тесты логики пройдены."; exit 0
else echo "Провалено: $fail"; exit 1; fi
