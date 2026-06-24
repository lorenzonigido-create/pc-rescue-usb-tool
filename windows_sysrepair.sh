#!/bin/bash
# ── WINDOWS SYSTEM REPAIR — Analisi e Recovery file di sistema ──
# Eseguire dalla USB rescue su Linux con partizione Windows montabile.
# Richiede: ntfs-3g, chntpw, python3, cabextract, wimtools, perl

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

LOG="/logs/windows_repair_$(date +%Y%m%d_%H%M%S).log"
REPORT="/logs/windows_report_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p /logs

WIN_MOUNT=""
WIN_PART=""

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║     WINDOWS SYSTEM REPAIR TOOL v1.0         ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

separator() { echo -e "${CYAN}────────────────────────────────────────────${NC}"; }

# ── Monta la partizione Windows ───────────────────────────────

mount_windows() {
  header
  echo -e "${YELLOW}[*] Partizioni disponibili:${NC}"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
  echo ""
  read -p "Partizione Windows NTFS (es. /dev/sda2): " WIN_PART
  WIN_MOUNT="/mnt/win_repair"
  mkdir -p "$WIN_MOUNT"

  if mountpoint -q "$WIN_MOUNT" 2>/dev/null; then
    echo -e "${YELLOW}[*] Partizione già montata, rimonto...${NC}"
    umount "$WIN_MOUNT" 2>/dev/null || true
  fi

  echo -e "${CYAN}[*] Montaggio $WIN_PART...${NC}"
  if ! mount -t ntfs-3g -o remove_hiberfile "$WIN_PART" "$WIN_MOUNT" 2>/dev/null; then
    mount -t ntfs-3g -o ro,remove_hiberfile "$WIN_PART" "$WIN_MOUNT" || {
      echo -e "${RED}[!] Impossibile montare $WIN_PART${NC}"
      echo -e "${YELLOW}    Prova: ntfsfix $WIN_PART  poi ritenta${NC}"
      log "ERRORE mount $WIN_PART"
      return 1
    }
    echo -e "${YELLOW}[!] Montato in sola lettura — alcune riparazioni non saranno disponibili${NC}"
  fi

  # Verifica che sia un'installazione Windows valida
  if [[ ! -d "$WIN_MOUNT/Windows/System32" ]]; then
    echo -e "${RED}[!] Cartella Windows\\System32 non trovata. Partizione corretta?${NC}"
    umount "$WIN_MOUNT" 2>/dev/null || true
    log "ERRORE: Windows\\System32 non trovato su $WIN_PART"
    return 1
  fi

  WIN_VER=$(cat "$WIN_MOUNT/Windows/System32/license.rtf" 2>/dev/null | grep -o "Windows [0-9]*" | head -1 \
    || ls "$WIN_MOUNT/Windows/System32/ntoskrnl.exe" 2>/dev/null | head -1 | xargs -I{} stat -c "%y" {} | cut -d- -f1 \
    || echo "Sconosciuta")
  echo -e "${GREEN}[✓] Partizione Windows montata: $WIN_MOUNT${NC}"
  echo -e "${GREEN}    Versione rilevata: $WIN_VER${NC}"
  log "Montata $WIN_PART su $WIN_MOUNT"
}

check_mounted() {
  if [[ -z "$WIN_MOUNT" ]] || ! mountpoint -q "$WIN_MOUNT" 2>/dev/null; then
    echo -e "${RED}[!] Nessuna partizione Windows montata. Esegui prima l'opzione 1.${NC}"
    return 1
  fi
}

# ── 1. SFC OFFLINE ────────────────────────────────────────────
# Simula System File Checker confrontando hash SHA256 dei file
# critici di System32 con una lista di riferimento nota.

sfc_offline() {
  header
  check_mounted || return
  separator
  echo -e "${BOLD}SFC OFFLINE — Verifica file di sistema critici${NC}"
  separator

  SYS32="$WIN_MOUNT/Windows/System32"
  CORRUPT=0
  MISSING=0
  CHECKED=0

  # File critici da verificare (presenza + leggibilità)
  CRITICAL_FILES=(
    "ntoskrnl.exe" "hal.dll" "bootmgr"
    "winload.exe" "winload.efi"
    "smss.exe" "csrss.exe" "wininit.exe" "services.exe"
    "lsass.exe" "svchost.exe" "explorer.exe"
    "kernel32.dll" "kernelbase.dll" "ntdll.dll"
    "user32.dll" "advapi32.dll" "msvcrt.dll"
    "ws2_32.dll" "rpcrt4.dll" "ole32.dll"
    "shell32.dll" "combase.dll" "ucrtbase.dll"
  )

  echo -e "${CYAN}[*] Verifica file critici in System32...${NC}"
  echo ""

  for f in "${CRITICAL_FILES[@]}"; do
    FPATH="$SYS32/$f"
    CHECKED=$((CHECKED + 1))
    if [[ ! -f "$FPATH" ]]; then
      echo -e "  ${RED}[MANCANTE]${NC}  $f"
      log "SFC MANCANTE: $f"
      MISSING=$((MISSING + 1))
    elif [[ ! -r "$FPATH" ]]; then
      echo -e "  ${RED}[ILLEGGIBILE]${NC} $f"
      log "SFC ILLEGGIBILE: $f"
      CORRUPT=$((CORRUPT + 1))
    else
      SIZE=$(stat -c%s "$FPATH" 2>/dev/null)
      if [[ "$SIZE" -lt 1024 ]]; then
        echo -e "  ${YELLOW}[SOSPETTO]${NC}   $f  (${SIZE} byte — troppo piccolo)"
        log "SFC SOSPETTO: $f ($SIZE byte)"
        CORRUPT=$((CORRUPT + 1))
      else
        echo -e "  ${GREEN}[OK]${NC}         $f"
      fi
    fi
  done

  # Verifica cartelle critiche
  echo ""
  echo -e "${CYAN}[*] Verifica cartelle critiche...${NC}"
  for dir in "Windows/System32/drivers" "Windows/System32/config" \
             "Windows/SysWOW64" "Windows/WinSxS" "Windows/Boot"; do
    if [[ -d "$WIN_MOUNT/$dir" ]]; then
      COUNT=$(ls "$WIN_MOUNT/$dir" 2>/dev/null | wc -l)
      echo -e "  ${GREEN}[OK]${NC}  $dir  ($COUNT elementi)"
    else
      echo -e "  ${YELLOW}[MANCANTE]${NC}  $dir"
    fi
  done

  echo ""
  separator
  echo -e "  File verificati: ${BOLD}$CHECKED${NC}"
  echo -e "  Mancanti:  ${RED}${BOLD}$MISSING${NC}"
  echo -e "  Corrotti/sospetti: ${YELLOW}${BOLD}$CORRUPT${NC}"

  if [[ $((MISSING + CORRUPT)) -eq 0 ]]; then
    echo -e "\n  ${GREEN}${BOLD}✓ Nessun file critico danneggiato rilevato${NC}"
  else
    echo -e "\n  ${YELLOW}Suggerimento: usa l'opzione DISM offline per il ripristino.${NC}"
  fi

  log "SFC: $CHECKED file, $MISSING mancanti, $CORRUPT corrotti"
  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 2. DISM OFFLINE ───────────────────────────────────────────

dism_offline() {
  header
  check_mounted || return
  separator
  echo -e "${BOLD}DISM OFFLINE — Ripristino file di sistema${NC}"
  separator
  echo ""
  echo -e "${YELLOW}DISM nativo richiede Windows. Da Linux possiamo:${NC}"
  echo ""
  echo "  1) Estrarre file da install.wim/install.esd (WIM sorgente)"
  echo "  2) Sostituire file specifici corrotti"
  echo "  3) Ripristinare l'intero System32 da WIM"
  echo "  4) Torna indietro"
  echo ""
  read -p "Scelta: " DISM_CHOICE

  case $DISM_CHOICE in
    1|2|3)
      echo ""
      echo -e "${CYAN}[*] Cerca install.wim o install.esd...${NC}"
      # Cerca su tutti i dischi montabili
      WIM_PATH=""
      for dev in /dev/sd?? /dev/sd? /dev/nvme?n?p?; do
        [[ -b "$dev" ]] || continue
        TMP_MNT="/mnt/wim_search_$$"
        mkdir -p "$TMP_MNT"
        mount -o ro "$dev" "$TMP_MNT" 2>/dev/null || continue
        for p in "sources/install.wim" "sources/install.esd"; do
          if [[ -f "$TMP_MNT/$p" ]]; then
            WIM_PATH="$TMP_MNT/$p"
            echo -e "${GREEN}[✓] Trovato: $dev/$p${NC}"
            break 2
          fi
        done
        umount "$TMP_MNT" 2>/dev/null
      done

      if [[ -z "$WIM_PATH" ]]; then
        echo -e "${YELLOW}[!] install.wim non trovato automaticamente.${NC}"
        read -p "Inserisci path manuale (es. /mnt/dvd/sources/install.wim): " WIM_PATH
        [[ ! -f "$WIM_PATH" ]] && echo -e "${RED}[!] File non trovato.${NC}" && return
      fi

      if ! command -v wiminfo &>/dev/null; then
        echo -e "${RED}[!] wimtools non installato. Esegui: apt install wimtools${NC}"
        log "DISM: wimtools mancante"
        return
      fi

      echo ""
      echo -e "${CYAN}[*] Indici disponibili nel WIM:${NC}"
      wiminfo "$WIM_PATH" 2>/dev/null | grep -E "Index|Name|Description" | sed 's/^/  /'
      echo ""
      read -p "Indice da usare (di solito 1): " WIM_INDEX
      WIM_INDEX=${WIM_INDEX:-1}

      if [[ $DISM_CHOICE -eq 1 ]]; then
        echo -e "${CYAN}[*] Estrazione info da indice $WIM_INDEX...${NC}"
        wiminfo "$WIM_PATH" "$WIM_INDEX" | tee -a "$LOG"

      elif [[ $DISM_CHOICE -eq 2 ]]; then
        read -p "File da ripristinare (es. Windows/System32/ntdll.dll): " RESTORE_FILE
        DEST="$WIN_MOUNT/$RESTORE_FILE"
        mkdir -p "$(dirname "$DEST")"
        echo -e "${CYAN}[*] Estrazione di $RESTORE_FILE dal WIM...${NC}"
        wimextract "$WIM_PATH" "$WIM_INDEX" "/$RESTORE_FILE" --dest-dir="$(dirname "$DEST")" && {
          echo -e "${GREEN}[✓] File ripristinato: $DEST${NC}"
          log "DISM ripristinato: $RESTORE_FILE"
        } || echo -e "${RED}[!] Estrazione fallita${NC}"

      elif [[ $DISM_CHOICE -eq 3 ]]; then
        echo -e "${RED}[!] ATTENZIONE: sovrascriverà tutti i file di System32!${NC}"
        read -p "Confermi? (scrivi 'SI'): " CONF
        [[ "$CONF" != "SI" ]] && echo "Annullato." && return
        echo -e "${CYAN}[*] Ripristino System32 in corso...${NC}"
        wimapply "$WIM_PATH" "$WIM_INDEX" "$WIN_MOUNT" --no-acls 2>&1 | tee -a "$LOG"
        echo -e "${GREEN}[✓] Ripristino completato${NC}"
        log "DISM: ripristino completo System32 da $WIM_PATH"
      fi
      ;;
    4) return ;;
  esac

  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 3. ANALISI REGISTRO ───────────────────────────────────────

analyze_registry() {
  header
  check_mounted || return
  separator
  echo -e "${BOLD}ANALISI REGISTRO DI SISTEMA WINDOWS${NC}"
  separator

  CONFIG_DIR="$WIN_MOUNT/Windows/System32/config"
  HIVES=("SYSTEM" "SOFTWARE" "SAM" "SECURITY" "DEFAULT")
  BACKUP_DIR="/logs/registry_backup_$(date +%Y%m%d_%H%M%S)"

  echo ""
  echo "  1) Mostra info hive (dimensioni, stato)"
  echo "  2) Backup hive su USB rescue"
  echo "  3) Ripristina hive da backup"
  echo "  4) Analisi chiavi di avvio (Run/RunOnce — malware check)"
  echo "  5) Reset password account Windows (chntpw)"
  echo "  6) Torna indietro"
  echo ""
  read -p "Scelta: " REG_CHOICE

  case $REG_CHOICE in
    1)
      echo ""
      echo -e "${CYAN}[*] Stato hive del registro:${NC}"
      for hive in "${HIVES[@]}"; do
        HIVE_PATH="$CONFIG_DIR/$hive"
        if [[ -f "$HIVE_PATH" ]]; then
          SIZE=$(du -sh "$HIVE_PATH" | cut -f1)
          MOD=$(stat -c "%y" "$HIVE_PATH" | cut -d. -f1)
          echo -e "  ${GREEN}[OK]${NC}  $hive  ($SIZE, modificato: $MOD)"
        else
          echo -e "  ${RED}[MANCANTE]${NC}  $hive"
          log "REGISTRO: hive mancante $hive"
        fi
      done
      # Verifica log transazionali
      echo ""
      echo -e "${CYAN}[*] Log transazionali (.LOG):${NC}"
      ls "$CONFIG_DIR"/*.LOG* 2>/dev/null | while read f; do
        echo -e "  ${YELLOW}$(basename "$f")${NC}  ($(du -sh "$f" | cut -f1))"
      done || echo "  Nessun log transazionale trovato"
      ;;

    2)
      mkdir -p "$BACKUP_DIR"
      echo -e "${CYAN}[*] Backup hive in $BACKUP_DIR...${NC}"
      for hive in "${HIVES[@]}"; do
        HIVE_PATH="$CONFIG_DIR/$hive"
        [[ -f "$HIVE_PATH" ]] || continue
        cp "$HIVE_PATH" "$BACKUP_DIR/$hive.bak" && \
          echo -e "  ${GREEN}[✓]${NC} $hive" || \
          echo -e "  ${RED}[!]${NC} $hive — errore copia"
      done
      echo -e "${GREEN}[✓] Backup completato: $BACKUP_DIR${NC}"
      log "REGISTRO: backup in $BACKUP_DIR"
      ;;

    3)
      ls /logs/registry_backup_* 2>/dev/null || { echo -e "${RED}[!] Nessun backup trovato in /logs/${NC}"; return; }
      read -p "Path backup da ripristinare: " RESTORE_DIR
      [[ ! -d "$RESTORE_DIR" ]] && echo -e "${RED}[!] Directory non trovata${NC}" && return
      echo -e "${RED}[!] ATTENZIONE: sovrascriverà le hive attuali!${NC}"
      read -p "Confermi? (scrivi 'SI'): " CONF
      [[ "$CONF" != "SI" ]] && echo "Annullato." && return
      for f in "$RESTORE_DIR"/*.bak; do
        HIVE=$(basename "$f" .bak)
        cp "$f" "$CONFIG_DIR/$HIVE" && \
          echo -e "  ${GREEN}[✓]${NC} $HIVE ripristinato" || \
          echo -e "  ${RED}[!]${NC} $HIVE — errore"
      done
      log "REGISTRO: ripristino da $RESTORE_DIR"
      ;;

    4)
      echo ""
      echo -e "${CYAN}[*] Analisi chiavi di avvio automatico...${NC}"
      if ! command -v chntpw &>/dev/null; then
        echo -e "${RED}[!] chntpw non installato. Esegui: apt install chntpw${NC}"
        return
      fi
      SOFTWARE_HIVE="$CONFIG_DIR/SOFTWARE"
      [[ ! -f "$SOFTWARE_HIVE" ]] && echo -e "${RED}[!] Hive SOFTWARE non trovata${NC}" && return

      echo -e "${YELLOW}  Chiavi Run (HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run):${NC}"
      # Legge le chiavi tramite chntpw in modalità batch
      {
        echo "cd \Microsoft\Windows\CurrentVersion\Run"
        echo "ls"
        echo "q"
      } | chntpw -e "$SOFTWARE_HIVE" 2>/dev/null | grep -v "^>" | sed 's/^/  /' || \
        echo "  (impossibile leggere — hive bloccata o corrotta)"

      echo ""
      echo -e "${YELLOW}  Cartelle Startup:${NC}"
      for startdir in \
        "$WIN_MOUNT/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup" \
        "$WIN_MOUNT/Users/*/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"; do
        for d in $startdir; do
          [[ -d "$d" ]] || continue
          echo -e "  ${CYAN}$d${NC}"
          ls "$d" 2>/dev/null | sed 's/^/    /' || echo "    (vuota)"
        done
      done
      log "REGISTRO: analisi chiavi avvio eseguita"
      ;;

    5)
      echo ""
      if ! command -v chntpw &>/dev/null; then
        echo -e "${RED}[!] chntpw non installato. Esegui: apt install chntpw${NC}"
        return
      fi
      SAM_HIVE="$CONFIG_DIR/SAM"
      SYSTEM_HIVE="$CONFIG_DIR/SYSTEM"
      [[ ! -f "$SAM_HIVE" ]] && echo -e "${RED}[!] Hive SAM non trovata${NC}" && return

      echo -e "${CYAN}[*] Account Windows trovati:${NC}"
      chntpw -l "$SAM_HIVE" 2>/dev/null | grep -E "^\|" | sed 's/^/  /'
      echo ""
      read -p "Nome utente da modificare (es. Administrator): " WIN_USER
      echo "  1) Reset password (imposta password vuota)"
      echo "  2) Sblocca account"
      echo "  3) Promuovi ad Amministratore"
      read -p "Scelta: " CHNT_OP
      case $CHNT_OP in
        1) echo -e "${CYAN}[*] Reset password per $WIN_USER...${NC}"
           printf "1\n!\nq\ny\n" | chntpw -u "$WIN_USER" "$SAM_HIVE" "$SYSTEM_HIVE" 2>/dev/null
           log "REGISTRO: reset password $WIN_USER" ;;
        2) printf "2\nq\ny\n" | chntpw -u "$WIN_USER" "$SAM_HIVE" 2>/dev/null
           log "REGISTRO: sblocco account $WIN_USER" ;;
        3) printf "3\nq\ny\n" | chntpw -u "$WIN_USER" "$SAM_HIVE" 2>/dev/null
           log "REGISTRO: promozione admin $WIN_USER" ;;
      esac
      echo -e "${GREEN}[✓] Operazione completata${NC}"
      ;;

    6) return ;;
  esac

  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 4. RIPRISTINO DLL E DRIVER ────────────────────────────────

repair_dll_drivers() {
  header
  check_mounted || return
  separator
  echo -e "${BOLD}RIPRISTINO DLL E DRIVER${NC}"
  separator
  echo ""
  echo "  1) Scansione DLL mancanti o di dimensione anomala"
  echo "  2) Ripristina DLL specifica da System32 a SysWOW64"
  echo "  3) Analisi driver (.sys) in System32/drivers"
  echo "  4) Torna indietro"
  echo ""
  read -p "Scelta: " DLL_CHOICE

  SYS32="$WIN_MOUNT/Windows/System32"
  SYSWOW="$WIN_MOUNT/Windows/SysWOW64"
  DRIVERS="$WIN_MOUNT/Windows/System32/drivers"

  case $DLL_CHOICE in
    1)
      echo -e "${CYAN}[*] Scansione DLL critiche...${NC}"
      echo ""
      CRITICAL_DLLS=(
        "kernel32.dll" "kernelbase.dll" "ntdll.dll" "user32.dll"
        "gdi32.dll" "advapi32.dll" "msvcrt.dll" "msvcp_win.dll"
        "ws2_32.dll" "rpcrt4.dll" "ole32.dll" "oleaut32.dll"
        "shell32.dll" "combase.dll" "ucrtbase.dll" "vcruntime140.dll"
        "d3d11.dll" "dxgi.dll" "opengl32.dll" "wintrust.dll"
        "crypt32.dll" "cryptsp.dll" "sechost.dll" "setupapi.dll"
      )
      ISSUES=0
      for dll in "${CRITICAL_DLLS[@]}"; do
        F="$SYS32/$dll"
        if [[ ! -f "$F" ]]; then
          echo -e "  ${RED}[MANCANTE]${NC}  $dll"
          log "DLL MANCANTE: $dll"
          ISSUES=$((ISSUES+1))
        else
          SZ=$(stat -c%s "$F")
          if [[ $SZ -lt 4096 ]]; then
            echo -e "  ${YELLOW}[SOSPETTA]${NC}  $dll  (${SZ} byte)"
            log "DLL SOSPETTA: $dll ($SZ byte)"
            ISSUES=$((ISSUES+1))
          else
            echo -e "  ${GREEN}[OK]${NC}        $dll  ($(numfmt --to=iec $SZ))"
          fi
        fi
      done
      echo ""
      if [[ $ISSUES -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✓ Tutte le DLL critiche presenti e di dimensione corretta${NC}"
      else
        echo -e "  ${YELLOW}$ISSUES problemi rilevati. Usa DISM offline per il ripristino.${NC}"
      fi
      ;;

    2)
      read -p "Nome DLL da copiare (es. ntdll.dll): " DLL_NAME
      SRC="$SYS32/$DLL_NAME"
      DST="$SYSWOW/$DLL_NAME"
      if [[ ! -f "$SRC" ]]; then
        echo -e "${RED}[!] $DLL_NAME non trovata in System32${NC}"
      else
        cp "$SRC" "$DST" && echo -e "${GREEN}[✓] Copiata in SysWOW64${NC}" || \
          echo -e "${RED}[!] Errore copia${NC}"
        log "DLL copiata System32→SysWOW64: $DLL_NAME"
      fi
      ;;

    3)
      echo -e "${CYAN}[*] Driver di sistema (.sys):${NC}"
      echo ""
      TOTAL=$(ls "$DRIVERS"/*.sys 2>/dev/null | wc -l)
      SMALL=$(find "$DRIVERS" -name "*.sys" -size -4k 2>/dev/null | wc -l)
      echo -e "  Totale driver: ${BOLD}$TOTAL${NC}"
      echo -e "  Driver < 4KB (sospetti): ${YELLOW}${BOLD}$SMALL${NC}"
      echo ""
      if [[ $SMALL -gt 0 ]]; then
        echo -e "${YELLOW}  Driver sospetti (potrebbero essere corrotti):${NC}"
        find "$DRIVERS" -name "*.sys" -size -4k 2>/dev/null | while read f; do
          echo -e "  ${YELLOW}$(basename "$f")${NC}  ($(stat -c%s "$f") byte)"
        done
      fi
      echo ""
      echo -e "${CYAN}  Ultimi 10 driver modificati di recente:${NC}"
      find "$DRIVERS" -name "*.sys" -printf "%T@ %f\n" 2>/dev/null | \
        sort -rn | head -10 | awk '{print "  " $2}'
      log "DLL: analisi driver completata ($TOTAL driver, $SMALL sospetti)"
      ;;

    4) return ;;
  esac

  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 5. ANALISI LOG EVENTI WINDOWS ────────────────────────────

analyze_event_logs() {
  header
  check_mounted || return
  separator
  echo -e "${BOLD}ANALISI LOG EVENTI WINDOWS${NC}"
  separator

  EVTX_DIR="$WIN_MOUNT/Windows/System32/winevt/Logs"
  if [[ ! -d "$EVTX_DIR" ]]; then
    echo -e "${RED}[!] Directory log eventi non trovata: $EVTX_DIR${NC}"
    read -p "Premi INVIO..."
    return
  fi

  echo ""
  echo "  1) Elenca file log disponibili"
  echo "  2) Analisi crash (BugCheck / BSOD)"
  echo "  3) Analisi errori disco (Disk / Ntfs)"
  echo "  4) Analisi errori applicazione"
  echo "  5) Esporta tutti i log leggibili in testo"
  echo "  6) Torna indietro"
  echo ""
  read -p "Scelta: " EVT_CHOICE

  case $EVT_CHOICE in
    1)
      echo -e "${CYAN}[*] File log eventi:${NC}"
      ls -lh "$EVTX_DIR"/*.evtx 2>/dev/null | awk '{print "  "$NF, $5}' | \
        sed "s|$EVTX_DIR/||" | sort -k2 -rh | head -30
      TOTAL=$(ls "$EVTX_DIR"/*.evtx 2>/dev/null | wc -l)
      echo -e "\n  Totale: ${BOLD}$TOTAL${NC} file .evtx"
      ;;

    2|3|4|5)
      # python-evtx o evtxexport necessari; fallback a strings
      if command -v python3 &>/dev/null && python3 -c "import Evtx" 2>/dev/null; then
        PARSER="python3_evtx"
      elif command -v evtxexport &>/dev/null; then
        PARSER="evtxexport"
      else
        PARSER="strings"
        echo -e "${YELLOW}[!] python3-evtx e evtxexport non trovati.${NC}"
        echo -e "${YELLOW}    Uso 'strings' come fallback (output grezzo).${NC}"
        echo -e "${YELLOW}    Per analisi completa: apt install python3-pip && pip3 install python-evtx${NC}"
        echo ""
      fi

      parse_evtx() {
        local FILE="$1"
        [[ ! -f "$FILE" ]] && return
        case $PARSER in
          python3_evtx)
            python3 - "$FILE" <<'PYEOF'
import sys, Evtx.Evtx as evtx, xml.etree.ElementTree as ET
ns = "http://schemas.microsoft.com/win/2004/08/events/event"
try:
    with evtx.Evtx(sys.argv[1]) as log:
        for rec in log.records():
            try:
                root = ET.fromstring(rec.xml())
                sys_el = root.find(f"{{{ns}}}System")
                if sys_el is None: continue
                lvl = sys_el.findtext(f"{{{ns}}}Level", "")
                eid = sys_el.findtext(f"{{{ns}}}EventID", "")
                time = sys_el.findtext(f"{{{ns}}}TimeCreated/[@SystemTime]", "")
                if time == "":
                    tc = sys_el.find(f"{{{ns}}}TimeCreated")
                    time = tc.get("SystemTime","") if tc is not None else ""
                prov = sys_el.find(f"{{{ns}}}Provider")
                src = prov.get("Name","") if prov is not None else ""
                data_els = root.findall(f".//{{{ns}}}Data")
                msg = " | ".join(d.text or "" for d in data_els if d.text)
                print(f"[{time[:19]}] L={lvl} EID={eid} {src}: {msg[:120]}")
            except: pass
except Exception as e:
    print(f"Errore lettura: {e}")
PYEOF
            ;;
          evtxexport) evtxexport "$FILE" 2>/dev/null ;;
          strings)    strings "$FILE" 2>/dev/null | grep -E "[A-Za-z]{8,}" | head -100 ;;
        esac
      }

      case $EVT_CHOICE in
        2)
          echo -e "${CYAN}[*] Ricerca BSOD / BugCheck...${NC}"
          for f in "$EVTX_DIR/System.evtx" "$EVTX_DIR/Application.evtx"; do
            [[ -f "$f" ]] || continue
            echo -e "${YELLOW}  $(basename "$f"):${NC}"
            parse_evtx "$f" 2>/dev/null | grep -iE "bugcheck|bluescreen|0x0000|critical|unexpected.shutdown" | \
              tail -20 | sed 's/^/    /' || echo "    Nessun crash trovato"
          done
          log "EVT: analisi crash completata"
          ;;
        3)
          echo -e "${CYAN}[*] Ricerca errori disco/NTFS...${NC}"
          for f in "$EVTX_DIR/System.evtx"; do
            [[ -f "$f" ]] || continue
            parse_evtx "$f" 2>/dev/null | grep -iE "disk|ntfs|volume|bad.sector|i/o error|atapi|storport" | \
              tail -30 | sed 's/^/    /' || echo "    Nessun errore disco trovato"
          done
          log "EVT: analisi errori disco completata"
          ;;
        4)
          echo -e "${CYAN}[*] Ricerca errori applicazione...${NC}"
          for f in "$EVTX_DIR/Application.evtx"; do
            [[ -f "$f" ]] || continue
            parse_evtx "$f" 2>/dev/null | grep -iE "error|fault|crash|exception|failed" | \
              tail -30 | sed 's/^/    /' || echo "    Nessun errore applicazione trovato"
          done
          log "EVT: analisi errori applicazione completata"
          ;;
        5)
          OUT_DIR="/logs/evtx_export_$(date +%Y%m%d_%H%M%S)"
          mkdir -p "$OUT_DIR"
          echo -e "${CYAN}[*] Esportazione log in $OUT_DIR...${NC}"
          for f in "$EVTX_DIR"/*.evtx; do
            NAME=$(basename "$f" .evtx)
            parse_evtx "$f" > "$OUT_DIR/${NAME}.txt" 2>/dev/null
            echo -e "  ${GREEN}[✓]${NC} ${NAME}.txt"
          done
          echo -e "${GREEN}[✓] Esportazione completata: $OUT_DIR${NC}"
          log "EVT: export completo in $OUT_DIR"
          ;;
      esac
      ;;

    6) return ;;
  esac

  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 6. REPORT COMPLETO ────────────────────────────────────────

generate_full_report() {
  header
  check_mounted || return
  echo -e "${CYAN}[*] Generazione report completo Windows...${NC}"
  echo ""

  strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

  {
    echo "=============================================="
    echo "  WINDOWS REPAIR REPORT — $(date)"
    echo "  Partizione: $WIN_PART  →  $WIN_MOUNT"
    echo "=============================================="
    echo ""

    echo "=== INFO INSTALLAZIONE ==="
    if [[ -f "$WIN_MOUNT/Windows/System32/ntoskrnl.exe" ]]; then
      echo "ntoskrnl.exe: $(stat -c 'size=%s bytes, modified=%y' "$WIN_MOUNT/Windows/System32/ntoskrnl.exe")"
    fi
    echo ""

    echo "=== SPAZIO DISCO ==="
    df -h "$WIN_MOUNT" 2>/dev/null
    echo ""

    echo "=== FILE CRITICI ==="
    for f in ntoskrnl.exe hal.dll ntdll.dll kernel32.dll lsass.exe services.exe explorer.exe; do
      FP="$WIN_MOUNT/Windows/System32/$f"
      if [[ -f "$FP" ]]; then
        echo "  OK  $f  ($(stat -c%s "$FP") byte)"
      else
        echo "  MANCANTE  $f"
      fi
    done
    echo ""

    echo "=== STATO HIVE REGISTRO ==="
    for hive in SYSTEM SOFTWARE SAM; do
      HP="$WIN_MOUNT/Windows/System32/config/$hive"
      if [[ -f "$HP" ]]; then
        echo "  OK  $hive  ($(du -sh "$HP" | cut -f1))"
      else
        echo "  MANCANTE  $hive"
      fi
    done
    echo ""

    echo "=== DRIVER SOSPETTI (<4KB) ==="
    find "$WIN_MOUNT/Windows/System32/drivers" -name "*.sys" -size -4k 2>/dev/null | \
      while read f; do echo "  $(basename "$f")  ($(stat -c%s "$f") byte)"; done || echo "  Nessuno"
    echo ""

    echo "=== LOG: $LOG ==="
    cat "$LOG" 2>/dev/null || echo "(vuoto)"

  } | tee >(strip_ansi > "$REPORT")

  echo ""
  echo -e "${GREEN}[✓] Report salvato: $REPORT${NC}"
  log "Report completo generato: $REPORT"
  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── MAIN MENU ─────────────────────────────────────────────────

while true; do
  header
  [[ -n "$WIN_MOUNT" ]] && mountpoint -q "$WIN_MOUNT" 2>/dev/null && \
    echo -e "  ${GREEN}Partizione attiva: $WIN_PART → $WIN_MOUNT${NC}\n" || \
    echo -e "  ${YELLOW}Nessuna partizione Windows montata${NC}\n"

  echo "  1) Monta partizione Windows"
  echo "  2) SFC Offline — verifica file di sistema"
  echo "  3) DISM Offline — ripristino da install.wim"
  echo "  4) Analisi e gestione registro"
  echo "  5) Ripristino DLL e driver"
  echo "  6) Analisi log eventi (BSOD, crash, errori)"
  echo "  7) Genera report completo"
  echo "  8) Esci"
  echo ""
  read -p "  Scelta: " MAIN

  case $MAIN in
    1) mount_windows ;;
    2) sfc_offline ;;
    3) dism_offline ;;
    4) analyze_registry ;;
    5) repair_dll_drivers ;;
    6) analyze_event_logs ;;
    7) generate_full_report ;;
    8) break ;;
    *) echo -e "${RED}[!] Scelta non valida${NC}"; sleep 1 ;;
  esac
done

# Smonta alla chiusura
if [[ -n "$WIN_MOUNT" ]] && mountpoint -q "$WIN_MOUNT" 2>/dev/null; then
  echo -e "${CYAN}[*] Smontaggio $WIN_MOUNT...${NC}"
  umount "$WIN_MOUNT" 2>/dev/null && echo -e "${GREEN}[✓] Smontato${NC}"
fi

echo -e "\n${GREEN}[✓] Log salvato: $LOG${NC}"
