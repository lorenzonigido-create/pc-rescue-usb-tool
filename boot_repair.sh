#!/bin/bash
# ── RECOVERY BOOT — Windows & Linux ──────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

LOG="/logs/boot_repair_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /logs

header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════╗"
  echo "║     RIPARAZIONE BOOT SISTEMA        ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${NC}"
}

repair_windows_boot() {
  header
  echo -e "${YELLOW}[*] Riparazione Boot Windows${NC}"
  echo ""
  echo "Questo strumento ripara:"
  echo "  • MBR (Master Boot Record)"
  echo "  • BCD (Boot Configuration Data)"
  echo "  • File di sistema Windows"
  echo ""

  echo -e "${CYAN}[*] Rilevamento partizioni Windows...${NC}"
  lsblk -o NAME,SIZE,FSTYPE,LABEL | grep -i ntfs

  read -p "Partizione Windows (es. /dev/sda1): " WIN_PART
  MOUNT_POINT="/mnt/windows_repair"
  mkdir -p $MOUNT_POINT
  mount -t ntfs-3g $WIN_PART $MOUNT_POINT 2>/dev/null || \
    mount $WIN_PART $MOUNT_POINT

  echo -e "${CYAN}[*] Controllo file critici Windows...${NC}"
  WIN_DIR="$MOUNT_POINT/Windows"

  if [[ -d "$WIN_DIR" ]]; then
    echo -e "${GREEN}[✓] Installazione Windows trovata${NC}"

    # Verifica MBR
    echo -e "${CYAN}[*] Ripristino MBR...${NC}"
    DISK=$(echo $WIN_PART | sed 's/[0-9]*$//')
    ms-sys -w $DISK 2>/dev/null && \
      echo -e "${GREEN}[✓] MBR ripristinato${NC}" || \
      echo -e "${YELLOW}[!] ms-sys non disponibile, usa bootrec da WinPE${NC}"

    # Ripristino BCD (se tools disponibili)
    echo -e "${CYAN}[*] Controllo BCD...${NC}"
    BCD_PATH="$MOUNT_POINT/Boot/BCD"
    if [[ -f "$BCD_PATH" ]]; then
      echo -e "${GREEN}[✓] BCD trovato: $BCD_PATH${NC}"
    else
      echo -e "${RED}[!] BCD mancante. Crea da WinPE con:${NC}"
      echo "    bootrec /rebuildbcd"
      echo "    bootrec /fixmbr"
      echo "    bootrec /fixboot"
    fi

    echo "[$(date)] Riparazione boot Windows su $WIN_PART" >> $LOG
  else
    echo -e "${RED}[!] Installazione Windows non trovata su $WIN_PART${NC}"
  fi

  umount $MOUNT_POINT 2>/dev/null || true
}

repair_linux_grub() {
  header
  echo -e "${YELLOW}[*] Riparazione GRUB Linux${NC}"
  echo ""

  echo -e "${CYAN}[*] Partizioni Linux disponibili:${NC}"
  lsblk -o NAME,SIZE,FSTYPE,LABEL | grep -E "ext4|ext3|btrfs|xfs"
  echo ""

  read -p "Partizione root Linux (es. /dev/sda2): " LINUX_PART
  read -p "Disco di installazione GRUB (es. /dev/sda): " GRUB_DISK

  CHROOT="/mnt/linux_chroot"
  mkdir -p $CHROOT
  mount $LINUX_PART $CHROOT

  # Monta i filesystem necessari per chroot
  echo -e "${CYAN}[*] Preparazione ambiente chroot...${NC}"
  mount --bind /dev  $CHROOT/dev
  mount --bind /proc $CHROOT/proc
  mount --bind /sys  $CHROOT/sys

  # Monta /boot separato se esiste
  BOOT_PART=""
  read -p "Partizione /boot separata? (lascia vuoto se no): " BOOT_PART
  if [[ -n "$BOOT_PART" ]]; then
    mount $BOOT_PART $CHROOT/boot
  fi

  echo -e "${CYAN}[*] Reinstallazione GRUB in chroot...${NC}"
  chroot $CHROOT grub-install $GRUB_DISK && \
    chroot $CHROOT update-grub && \
    echo -e "${GREEN}[✓] GRUB reinstallato con successo${NC}" || \
    echo -e "${RED}[!] Errore durante reinstallazione GRUB${NC}"

  echo "[$(date)] GRUB reinstallato su $GRUB_DISK da $LINUX_PART" >> $LOG

  # Smontaggio
  umount $CHROOT/sys $CHROOT/proc $CHROOT/dev 2>/dev/null || true
  [[ -n "$BOOT_PART" ]] && umount $CHROOT/boot 2>/dev/null || true
  umount $CHROOT 2>/dev/null || true

  echo -e "${GREEN}[✓] Operazione completata${NC}"
}

repair_mbr() {
  header
  echo -e "${YELLOW}[*] Ripristino MBR / GPT${NC}"
  echo ""
  lsblk -o NAME,SIZE,TYPE | grep disk
  echo ""
  read -p "Disco target (es. /dev/sda): " MBR_DISK

  echo "  1) Scrivi MBR standard (ms-sys)"
  echo "  2) Ripristina GPT da backup (gdisk)"
  echo "  3) Cancella MBR completamente (dd)"
  read -p "Scelta: " MBR_CHOICE

  case $MBR_CHOICE in
    1) ms-sys -w $MBR_DISK && echo -e "${GREEN}[✓] MBR scritto${NC}" ;;
    2) gdisk $MBR_DISK ;;
    3)
      echo -e "${RED}[!] ATTENZIONE: cancellerà i primi 512 byte!${NC}"
      read -p "Confermi? (SI): " CONF
      [[ "$CONF" == "SI" ]] && dd if=/dev/zero of=$MBR_DISK bs=512 count=1
      ;;
  esac

  echo "[$(date)] Operazione MBR su $MBR_DISK" >> $LOG
}

# ── MAIN ──
header
echo "  1) Ripara Boot Windows"
echo "  2) Ripara GRUB Linux"
echo "  3) Ripristina MBR/GPT"
echo "  4) Esci"
read -p "Scelta: " MAIN_CHOICE

case $MAIN_CHOICE in
  1) repair_windows_boot ;;
  2) repair_linux_grub ;;
  3) repair_mbr ;;
  4) exit 0 ;;
esac

echo ""
echo -e "${GREEN}[✓] Log salvato: $LOG${NC}"
