#!/bin/bash
# ============================================================
#  PC RESCUE TOOL — Setup Script
#  Crea la struttura completa sulla USB
#  Utilizzo: sudo bash setup_rescue_usb.sh /dev/sdX
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════╗"
  echo "║       PC RESCUE USB — SETUP v1.0        ║"
  echo "╚══════════════════════════════════════════╝"
  echo -e "${NC}"
}

check_root() {
  [[ $EUID -ne 0 ]] && echo -e "${RED}[!] Esegui come root: sudo bash $0${NC}" && exit 1
}

check_deps() {
  echo -e "${CYAN}[*] Controllo dipendenze...${NC}"
  for dep in parted mkfs.fat mkfs.ext4 wget curl rsync; do
    command -v $dep &>/dev/null || { echo -e "${RED}[!] Mancante: $dep${NC}"; exit 1; }
  done
  echo -e "${GREEN}[✓] Dipendenze OK${NC}"
}

select_device() {
  if [[ -n "$1" ]]; then
    DEVICE="$1"
  else
    echo -e "${YELLOW}Dispositivi USB disponibili:${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part"
    read -p "Inserisci il dispositivo (es. /dev/sdb): " DEVICE
  fi
  [[ ! -b "$DEVICE" ]] && echo -e "${RED}[!] Dispositivo non trovato: $DEVICE${NC}" && exit 1
  echo -e "${YELLOW}[!] ATTENZIONE: tutti i dati su $DEVICE verranno cancellati!${NC}"
  read -p "Confermi? (scrivi 'SI' per continuare): " CONFIRM
  [[ "$CONFIRM" != "SI" ]] && echo "Operazione annullata." && exit 0
}

partition_usb() {
  echo -e "${CYAN}[*] Partizionamento USB...${NC}"
  umount ${DEVICE}* 2>/dev/null || true
  parted -s $DEVICE mklabel msdos
  # Partizione 1: Boot FAT32 (200MB) — per Ventoy/GRUB
  parted -s $DEVICE mkpart primary fat32 1MiB 201MiB
  parted -s $DEVICE set 1 boot on
  # Partizione 2: Sistema EXT4 (resto)
  parted -s $DEVICE mkpart primary ext4 201MiB 100%
  partprobe $DEVICE
  sleep 2
  mkfs.fat -F32 -n "RESCUE_BOOT" ${DEVICE}1
  mkfs.ext4 -L "RESCUE_SYS" ${DEVICE}2
  echo -e "${GREEN}[✓] Partizionamento completato${NC}"
}

mount_usb() {
  echo -e "${CYAN}[*] Montaggio partizioni...${NC}"
  MOUNT_BOOT="/mnt/rescue_boot"
  MOUNT_SYS="/mnt/rescue_sys"
  mkdir -p $MOUNT_BOOT $MOUNT_SYS
  mount ${DEVICE}1 $MOUNT_BOOT
  mount ${DEVICE}2 $MOUNT_SYS
  echo -e "${GREEN}[✓] Montaggio OK${NC}"
}

create_structure() {
  echo -e "${CYAN}[*] Creazione struttura cartelle...${NC}"
  mkdir -p $MOUNT_SYS/{tools,gui,logs,config}
  mkdir -p $MOUNT_SYS/tools/{recovery,data_recovery,diagnostics,antivirus,backup,password,network,advanced}
  echo -e "${GREEN}[✓] Struttura creata${NC}"
}

install_scripts() {
  echo -e "${CYAN}[*] Installazione script...${NC}"
  SCRIPT_DIR="$(dirname "$0")/tools"

  # Copia tutti gli script se esistono
  if [[ -d "$SCRIPT_DIR" ]]; then
    cp -r $SCRIPT_DIR/* $MOUNT_SYS/tools/
    find $MOUNT_SYS/tools -name "*.sh" -exec chmod +x {} \;
  fi

  # Copia il menu GUI
  cp "$(dirname "$0")/rescue_menu.py" $MOUNT_SYS/gui/
  chmod +x $MOUNT_SYS/gui/rescue_menu.py

  echo -e "${GREEN}[✓] Script installati${NC}"
}

install_grub() {
  echo -e "${CYAN}[*] Installazione GRUB...${NC}"
  grub-install --target=i386-pc --boot-directory=$MOUNT_BOOT/boot $DEVICE
  cat > $MOUNT_BOOT/boot/grub/grub.cfg << 'GRUBCFG'
set timeout=5
set default=0

menuentry "PC Rescue Tool" {
  linux /boot/vmlinuz root=LABEL=RESCUE_SYS rw quiet splash
  initrd /boot/initrd.img
}

menuentry "Memtest86+" {
  linux16 /boot/memtest86+.bin
}

menuentry "Avvio da disco fisso" {
  chainloader +1
}
GRUBCFG
  echo -e "${GREEN}[✓] GRUB installato${NC}"
}

install_packages_list() {
  echo -e "${CYAN}[*] Creazione lista pacchetti...${NC}"
  cat > $MOUNT_SYS/config/packages.txt << 'EOF'
# Strumenti di recupero
testdisk
photorec
gddrescue
clonezilla

# Diagnostica
smartmontools
memtest86+
gparted
hardinfo

# Sicurezza
clamav
chkrootkit
rkhunter

# Rete
openssh-server
links2
rsync
nmap

# Utilità
midnight-commander
nano
vim
htop
python3
python3-curses
EOF
  echo -e "${GREEN}[✓] Lista pacchetti creata${NC}"
}

write_readme() {
  cat > $MOUNT_SYS/README.txt << 'EOF'
======================================
   PC RESCUE TOOL v1.0
   Guida rapida
======================================

1. Inserisci la USB nel PC da riparare
2. Accedi al BIOS/UEFI (F2, F12, DEL, ESC)
3. Seleziona la USB come dispositivo di boot
4. Il menu si avvierà automaticamente
5. Usa le frecce per navigare, INVIO per selezionare

FUNZIONI PRINCIPALI:
- Recovery: ripara boot Windows/Linux
- Dati: recupera file cancellati
- Diagnostica: test RAM/disco
- Antivirus: scansione malware
- Backup: clona o salva dati
- Password: reset accesso

Log: /logs/rescue_operations.log
EOF
  echo -e "${GREEN}[✓] README scritto${NC}"
}

unmount_usb() {
  echo -e "${CYAN}[*] Smontaggio...${NC}"
  sync
  umount $MOUNT_BOOT
  umount $MOUNT_SYS
  echo -e "${GREEN}[✓] USB pronta!${NC}"
}

# ── MAIN ──────────────────────────────────────────
banner
check_root
check_deps
select_device "$1"
partition_usb
mount_usb
create_structure
install_scripts
install_grub
install_packages_list
write_readme
unmount_usb

echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓  USB RESCUE TOOL CREATA CON SUCCESSO!${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Dispositivo: $DEVICE${NC}"
echo -e "${YELLOW}  Prossimo step: installa il sistema base${NC}"
echo -e "${YELLOW}  Vedi: INSTALL_GUIDE.md${NC}"
echo ""
