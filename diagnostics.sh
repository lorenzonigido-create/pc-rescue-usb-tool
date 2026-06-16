#!/bin/bash
# ── DIAGNOSTICA HARDWARE ─────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

LOG="/logs/diagnostics_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /logs
REPORT="/logs/hardware_report_$(date +%Y%m%d_%H%M%S).txt"

separator() { echo -e "${CYAN}──────────────────────────────────────${NC}"; }

header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════╗"
  echo "║       DIAGNOSTICA HARDWARE          ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${NC}"
}

check_cpu() {
  separator
  echo -e "${BOLD}CPU:${NC}"
  grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
  echo "  Core: $(nproc)  |  Freq: $(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}') MHz"
  echo "  Temperatura: $(sensors 2>/dev/null | grep -i "core 0" | head -1 || echo "N/A (installa lm-sensors)")"
}

check_ram() {
  separator
  echo -e "${BOLD}RAM:${NC}"
  free -h | grep Mem | awk '{printf "  Totale: %s | Usata: %s | Libera: %s\n", $2, $3, $4}'
  dmidecode --type memory 2>/dev/null | grep -E "Size:|Speed:|Type:" | head -12 | sed 's/^/  /'
}

check_disks() {
  separator
  echo -e "${BOLD}DISCHI:${NC}"
  for disk in /dev/sd? /dev/nvme?n?; do
    [[ -b "$disk" ]] || continue
    SIZE=$(lsblk -dn -o SIZE $disk 2>/dev/null)
    MODEL=$(smartctl -i $disk 2>/dev/null | grep "Device Model" | cut -d: -f2 | xargs)
    HEALTH=$(smartctl -H $disk 2>/dev/null | grep "overall-health" | awk '{print $NF}')
    echo -e "  ${BOLD}$disk${NC} — $MODEL ($SIZE) — Salute: ${GREEN}$HEALTH${NC}"
    # SMART dettagliato
    smartctl -A $disk 2>/dev/null | grep -E "Reallocated|Pending|Uncorrectable" | sed 's/^/    /'
  done
}

check_gpu() {
  separator
  echo -e "${BOLD}GPU:${NC}"
  lspci | grep -i "vga\|3d\|display" | sed 's/^/  /'
  # NVIDIA
  nvidia-smi 2>/dev/null | head -10 | sed 's/^/  /' || true
}

check_network() {
  separator
  echo -e "${BOLD}RETE:${NC}"
  ip link show | grep -E "^[0-9]" | awk '{print "  "$2}' | tr -d ':'
  echo "  IP: $(hostname -I 2>/dev/null | awk '{print $1}')"
}

check_pci_usb() {
  separator
  echo -e "${BOLD}PCI/USB:${NC}"
  echo "  PCI devices principali:"
  lspci | grep -v "00\." | head -10 | sed 's/^/    /'
  echo "  USB connessi:"
  lsusb | sed 's/^/    /'
}

check_os() {
  separator
  echo -e "${BOLD}SISTEMA OPERATIVO (target):${NC}"
  for part in /dev/sd?? /dev/nvme?n?p?; do
    [[ -b "$part" ]] || continue
    FSTYPE=$(lsblk -no FSTYPE $part 2>/dev/null)
    LABEL=$(lsblk -no LABEL $part 2>/dev/null)
    echo "  $part — $FSTYPE $LABEL"
  done
}

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

generate_report() {
  header
  echo -e "${CYAN}[*] Generazione report completo...${NC}"
  {
    echo "=========================================="
    echo "  REPORT DIAGNOSTICA — $(date)"
    echo "=========================================="
    check_cpu
    check_ram
    check_disks
    check_gpu
    check_network
    check_pci_usb
    check_os
    echo ""
    echo "Log: $LOG"
  } | tee >(strip_ansi > $REPORT)
  echo -e "${GREEN}[✓] Report salvato: $REPORT${NC}"
}

disk_smart_test() {
  header
  echo -e "${YELLOW}Test S.M.A.R.T. disco${NC}"
  lsblk -o NAME,SIZE,TYPE | grep disk
  read -p "Disco da testare (es. /dev/sda): " SMART_DISK
  echo "  1) Test breve (~2 min)"
  echo "  2) Test lungo (~1-3 ore)"
  echo "  3) Test conveyance"
  read -p "Tipo test: " ST
  case $ST in
    1) smartctl -t short $SMART_DISK ;;
    2) smartctl -t long  $SMART_DISK ;;
    3) smartctl -t conveyance $SMART_DISK ;;
  esac
  echo -e "${YELLOW}[*] Test avviato. Controlla risultati con:${NC}"
  echo "    smartctl -a $SMART_DISK"
}

badblocks_test() {
  header
  echo -e "${RED}[!] ATTENZIONE: test scrittura distrugge dati!${NC}"
  lsblk -o NAME,SIZE,TYPE | grep disk
  read -p "Partizione da testare (es. /dev/sda2): " BB_PART
  echo "  1) Test sola lettura (sicuro)"
  echo "  2) Test lettura/scrittura non distruttivo"
  read -p "Tipo: " BB_TYPE
  case $BB_TYPE in
    1) badblocks -sv $BB_PART 2>&1 | tee -a $LOG ;;
    2) badblocks -nsv $BB_PART 2>&1 | tee -a $LOG ;;
  esac
  echo -e "${GREEN}[✓] Test completato. Log: $LOG${NC}"
}

# ── MAIN ──
header
echo "  1) Report hardware completo"
echo "  2) Test S.M.A.R.T. disco"
echo "  3) Test settori danneggiati (badblocks)"
echo "  4) Info sistema rapide"
echo "  5) Esci"
read -p "Scelta: " MAIN

case $MAIN in
  1) generate_report ;;
  2) disk_smart_test ;;
  3) badblocks_test ;;
  4)
    check_cpu
    check_ram
    check_disks
    ;;
  5) exit 0 ;;
esac

echo "[$(date)] Diagnostica eseguita" >> $LOG
