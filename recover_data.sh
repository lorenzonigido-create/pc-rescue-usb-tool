#!/bin/bash
# ── RECUPERO DATI — TestDisk & PhotoRec ──────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

LOG="/logs/data_recovery_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /logs

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════╗"
echo "║     RECUPERO DATI AVANZATO      ║"
echo "╚══════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}[*] Dischi disponibili:${NC}"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
echo ""

read -p "Su quale disco operare? (es. /dev/sda): " TARGET_DISK
read -p "Dove salvare i dati recuperati? (es. /mnt/usb_backup): " OUTPUT_DIR
mkdir -p "$OUTPUT_DIR"

echo ""
echo -e "${CYAN}Scegli operazione:${NC}"
echo "  1) TestDisk — Recupera partizioni e file system"
echo "  2) PhotoRec  — Recupera foto, video, documenti"
echo "  3) ddrescue  — Clona disco danneggiato"
echo "  4) Torna al menu"
read -p "Scelta: " CHOICE

case $CHOICE in
  1)
    echo -e "${CYAN}[*] Avvio TestDisk su $TARGET_DISK...${NC}"
    echo "[$(date)] TestDisk su $TARGET_DISK" >> $LOG
    testdisk $TARGET_DISK
    ;;
  2)
    echo -e "${CYAN}[*] Avvio PhotoRec su $TARGET_DISK → $OUTPUT_DIR${NC}"
    echo "[$(date)] PhotoRec su $TARGET_DISK → $OUTPUT_DIR" >> $LOG
    photorec /d "$OUTPUT_DIR" $TARGET_DISK
    ;;
  3)
    IMAGE_FILE="$OUTPUT_DIR/disk_clone_$(date +%Y%m%d).img"
    echo -e "${CYAN}[*] Clonazione disco con ddrescue...${NC}"
    echo -e "${YELLOW}Sorgente: $TARGET_DISK → Destinazione: $IMAGE_FILE${NC}"
    echo "[$(date)] ddrescue $TARGET_DISK → $IMAGE_FILE" >> $LOG
    ddrescue -d -r3 \
      "$TARGET_DISK" "$IMAGE_FILE" "$OUTPUT_DIR/ddrescue_map.log"
    echo -e "${GREEN}[✓] Clonazione completata: $IMAGE_FILE${NC}"
    ;;
  4)
    exit 0
    ;;
esac

echo ""
echo -e "${GREEN}[✓] Operazione completata. Log: $LOG${NC}"
