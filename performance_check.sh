#!/bin/bash
# ── PERFORMANCE ANALYSIS TOOL ────────────────────────────────
# Analisi completa delle performance hardware del PC target.
# Eseguire dalla USB rescue su Linux come root.
# Richiede: sysbench, hdparm, fio, stress-ng, lm-sensors, dmidecode

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'

LOG="/logs/performance_$(date +%Y%m%d_%H%M%S).log"
REPORT="/logs/performance_report_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p /logs

log()       { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
separator() { echo -e "${CYAN}────────────────────────────────────────────────${NC}"; }

header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════╗"
  echo "║       PERFORMANCE ANALYSIS TOOL v1.0            ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# Ritorna un indicatore colorato in base a soglie
rating() {
  local val=$1 good=$2 warn=$3 unit=$4 invert=${5:-0}
  if [[ $invert -eq 0 ]]; then
    if   (( $(echo "$val >= $good" | bc -l 2>/dev/null || echo 0) )); then echo -e "${GREEN}${val}${unit} [OTTIMO]${NC}"
    elif (( $(echo "$val >= $warn" | bc -l 2>/dev/null || echo 0) )); then echo -e "${YELLOW}${val}${unit} [NELLA NORMA]${NC}"
    else echo -e "${RED}${val}${unit} [SCARSO]${NC}"; fi
  else
    if   (( $(echo "$val <= $good" | bc -l 2>/dev/null || echo 0) )); then echo -e "${GREEN}${val}${unit} [OTTIMO]${NC}"
    elif (( $(echo "$val <= $warn" | bc -l 2>/dev/null || echo 0) )); then echo -e "${YELLOW}${val}${unit} [NELLA NORMA]${NC}"
    else echo -e "${RED}${val}${unit} [LENTO]${NC}"; fi
  fi
}

# ── 1. PANORAMICA SISTEMA ─────────────────────────────────────

system_overview() {
  header
  separator
  echo -e "${BOLD}  PANORAMICA SISTEMA${NC}"
  separator
  echo ""

  # CPU
  CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
  CPU_CORES=$(nproc)
  CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo)
  CPU_FREQ=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}' | cut -d. -f1)
  CPU_CACHE=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)

  echo -e "  ${BOLD}CPU${NC}"
  echo -e "    Modello : $CPU_MODEL"
  echo -e "    Core    : $CPU_CORES  |  Thread: $CPU_THREADS"
  echo -e "    Freq    : ${CPU_FREQ} MHz  |  Cache: $CPU_CACHE"

  # Temperatura CPU
  TEMP=$(sensors 2>/dev/null | grep -E "Core 0|Package id 0|Tdie" | head -1 | grep -oP '[0-9]+\.[0-9]+(?=°C)' | head -1)
  if [[ -n "$TEMP" ]]; then
    TEMP_INT=${TEMP%.*}
    if   [[ $TEMP_INT -le 60 ]]; then echo -e "    Temp    : ${GREEN}${TEMP}°C [OK]${NC}"
    elif [[ $TEMP_INT -le 80 ]]; then echo -e "    Temp    : ${YELLOW}${TEMP}°C [ALTA]${NC}"
    else                               echo -e "    Temp    : ${RED}${TEMP}°C [CRITICA]${NC}"; fi
  else
    echo -e "    Temp    : N/A (installa lm-sensors)"
  fi

  echo ""
  # RAM
  TOTAL_RAM=$(free -m | awk '/^Mem/ {print $2}')
  USED_RAM=$(free -m  | awk '/^Mem/ {print $3}')
  FREE_RAM=$(free -m  | awk '/^Mem/ {print $4}')
  SWAP_TOTAL=$(free -m | awk '/^Swap/ {print $2}')
  RAM_TYPE=$(dmidecode --type memory 2>/dev/null | grep -m1 "Type:" | grep -v "Unknown\|Error" | awk '{print $2}')
  RAM_SPEED=$(dmidecode --type memory 2>/dev/null | grep -m1 "Speed:" | grep "MT/s" | awk '{print $2, $3}')

  echo -e "  ${BOLD}RAM${NC}"
  echo -e "    Totale  : ${TOTAL_RAM} MB  (${RAM_TYPE:-N/A} @ ${RAM_SPEED:-N/A})"
  RAM_PCT=$(echo "scale=0; $USED_RAM * 100 / $TOTAL_RAM" | bc 2>/dev/null)
  if   [[ ${RAM_PCT:-0} -le 60 ]]; then echo -e "    Uso     : ${GREEN}${USED_RAM} MB / ${TOTAL_RAM} MB (${RAM_PCT}%)${NC}"
  elif [[ ${RAM_PCT:-0} -le 85 ]]; then echo -e "    Uso     : ${YELLOW}${USED_RAM} MB / ${TOTAL_RAM} MB (${RAM_PCT}%)${NC}"
  else                                   echo -e "    Uso     : ${RED}${USED_RAM} MB / ${TOTAL_RAM} MB (${RAM_PCT}%) [PRESSIONE ALTA]${NC}"; fi
  echo -e "    Swap    : ${SWAP_TOTAL} MB"

  echo ""
  # Dischi
  echo -e "  ${BOLD}DISCHI${NC}"
  for disk in /dev/sd? /dev/nvme?n?; do
    [[ -b "$disk" ]] || continue
    SIZE=$(lsblk -dn -o SIZE "$disk" 2>/dev/null)
    MODEL=$(smartctl -i "$disk" 2>/dev/null | grep "Device Model\|Model Number" | cut -d: -f2 | xargs)
    RPM=$(smartctl -i "$disk" 2>/dev/null | grep "Rotation Rate" | cut -d: -f2 | xargs)
    [[ -z "$MODEL" ]] && MODEL="(non rilevato)"
    echo -e "    ${BOLD}$disk${NC}  $MODEL  $SIZE  ${RPM:+[$RPM]}"
  done

  echo ""
  # GPU
  echo -e "  ${BOLD}GPU${NC}"
  lspci | grep -iE "vga|3d|display" | sed 's/^/    /'
  nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.total \
    --format=csv,noheader 2>/dev/null | \
    awk -F',' '{printf "    NVIDIA: %s | Temp: %s | Uso: %s | VRAM: %s\n",$1,$2,$3,$4}' || true

  echo ""
  log "Panoramica sistema completata"
  read -p "Premi INVIO per continuare..."
}

# ── 2. BENCHMARK CPU ──────────────────────────────────────────

benchmark_cpu() {
  header
  separator
  echo -e "${BOLD}  BENCHMARK CPU${NC}"
  separator
  echo ""

  if ! command -v sysbench &>/dev/null; then
    echo -e "${YELLOW}[!] sysbench non installato. Fallback su calcolo interno...${NC}"
    echo ""
    # Fallback: benchmark con bash + /proc
    echo -e "${CYAN}[*] Test calcolo (operazioni floating point)...${NC}"
    START=$(date +%s%N)
    python3 -c "
import math, time
t = time.time()
s = sum(math.sqrt(i) * math.sin(i) for i in range(1, 2000001))
elapsed = time.time() - t
print(f'  2.000.000 op in {elapsed:.3f}s  →  {2000000/elapsed/1000:.0f}k op/s')
" 2>/dev/null || echo "  (python3 non disponibile)"
    echo ""
    echo -e "${CYAN}[*] Compressione in-memory (stress test leggero)...${NC}"
    dd if=/dev/urandom bs=1M count=128 2>/dev/null | gzip > /dev/null && \
      echo -e "  ${GREEN}128 MB compressi OK${NC}"
    log "CPU benchmark: fallback bash"
  else
    CPU_CORES=$(nproc)

    echo -e "${CYAN}[*] Test single-thread...${NC}"
    ST=$(sysbench cpu --cpu-max-prime=20000 --threads=1 run 2>/dev/null | \
         grep "events per second" | awk '{print $NF}')
    echo -e "    Single-thread : $(rating ${ST%.*} 800 400 " ev/s")"

    echo ""
    echo -e "${CYAN}[*] Test multi-thread ($CPU_CORES core)...${NC}"
    MT=$(sysbench cpu --cpu-max-prime=20000 --threads="$CPU_CORES" run 2>/dev/null | \
         grep "events per second" | awk '{print $NF}')
    echo -e "    Multi-thread  : $(rating ${MT%.*} $((800*CPU_CORES/2)) $((400*CPU_CORES/2)) " ev/s")"

    echo ""
    echo -e "${CYAN}[*] Test memoria (lettura/scrittura)...${NC}"
    MEM_R=$(sysbench memory --memory-block-size=1K --memory-total-size=4G \
            --memory-oper=read run 2>/dev/null | grep "transferred" | grep -oP '[0-9.]+ MiB/sec')
    MEM_W=$(sysbench memory --memory-block-size=1K --memory-total-size=4G \
            --memory-oper=write run 2>/dev/null | grep "transferred" | grep -oP '[0-9.]+ MiB/sec')
    echo -e "    Lettura RAM   : ${GREEN}${MEM_R:-N/A}${NC}"
    echo -e "    Scrittura RAM : ${GREEN}${MEM_W:-N/A}${NC}"

    log "CPU benchmark: ST=$ST MT=$MT MEM_R=$MEM_R MEM_W=$MEM_W"
  fi

  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 3. BENCHMARK DISCO ────────────────────────────────────────

benchmark_disk() {
  header
  separator
  echo -e "${BOLD}  BENCHMARK DISCO${NC}"
  separator
  echo ""

  echo -e "${YELLOW}Dischi disponibili:${NC}"
  lsblk -o NAME,SIZE,TYPE,ROTA | grep disk
  echo ""
  read -p "Disco da testare (es. /dev/sda): " TEST_DISK

  [[ ! -b "$TEST_DISK" ]] && echo -e "${RED}[!] Disco non trovato${NC}" && return

  IS_SSD=$(cat /sys/block/$(basename $TEST_DISK)/queue/rotational 2>/dev/null)
  DISK_TYPE=$([[ "$IS_SSD" == "0" ]] && echo "SSD/NVMe" || echo "HDD")
  echo -e "  Tipo rilevato: ${BOLD}$DISK_TYPE${NC}"
  echo ""

  # Test 1: velocità lettura sequenziale con hdparm
  echo -e "${CYAN}[*] Test lettura sequenziale (hdparm)...${NC}"
  if command -v hdparm &>/dev/null; then
    READ_SPEED=$(hdparm -t --direct "$TEST_DISK" 2>/dev/null | grep "Timing" | \
                 grep -oP '[0-9.]+ MB/sec' | tail -1)
    READ_VAL=${READ_SPEED%% *}
    if [[ "$DISK_TYPE" == "SSD/NVMe" ]]; then
      echo -e "    Lettura seq  : $(rating ${READ_VAL%.*} 400 150 " MB/s")"
    else
      echo -e "    Lettura seq  : $(rating ${READ_VAL%.*} 120 60 " MB/s")"
    fi
  else
    echo -e "  ${YELLOW}hdparm non disponibile${NC}"
  fi

  # Test 2: lettura/scrittura con dd
  echo ""
  echo -e "${CYAN}[*] Test scrittura sequenziale (dd, 512 MB)...${NC}"
  TMPFILE=$(mktemp /tmp/perf_test_XXXXXX)
  WRITE_SPEED=$(dd if=/dev/zero of="$TMPFILE" bs=1M count=512 conv=fdatasync 2>&1 | \
                grep -oP '[0-9.]+ [MG]B/s' | tail -1)
  echo -e "    Scrittura seq: ${GREEN}${WRITE_SPEED:-N/A}${NC}"

  echo -e "${CYAN}[*] Test lettura (cache drop)...${NC}"
  sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
  READ_DD=$(dd if="$TMPFILE" of=/dev/null bs=1M 2>&1 | grep -oP '[0-9.]+ [MG]B/s' | tail -1)
  echo -e "    Lettura  seq : ${GREEN}${READ_DD:-N/A}${NC}"
  rm -f "$TMPFILE"

  # Test 3: IOPS con fio (se disponibile)
  echo ""
  if command -v fio &>/dev/null; then
    echo -e "${CYAN}[*] Test IOPS random 4K (fio, 10s)...${NC}"
    IOPS_R=$(fio --name=randread --ioengine=libaio --iodepth=32 --rw=randread \
               --bs=4k --direct=1 --size=256M --numjobs=1 --runtime=10 \
               --filename="$TEST_DISK" --group_reporting --output-format=terse 2>/dev/null | \
             cut -d\; -f8)
    IOPS_W=$(fio --name=randwrite --ioengine=libaio --iodepth=32 --rw=randwrite \
               --bs=4k --direct=1 --size=256M --numjobs=1 --runtime=10 \
               --filename="$TEST_DISK" --group_reporting --output-format=terse 2>/dev/null | \
             cut -d\; -f49)
    if [[ "$DISK_TYPE" == "SSD/NVMe" ]]; then
      echo -e "    IOPS lettura : $(rating ${IOPS_R:-0} 50000 10000 " IOPS")"
      echo -e "    IOPS scrittura: $(rating ${IOPS_W:-0} 30000 8000 " IOPS")"
    else
      echo -e "    IOPS lettura : $(rating ${IOPS_R:-0} 200 80 " IOPS")"
      echo -e "    IOPS scrittura: $(rating ${IOPS_W:-0} 150 60 " IOPS")"
    fi
    log "Disk benchmark: IOPS_R=$IOPS_R IOPS_W=$IOPS_W"
  else
    echo -e "  ${YELLOW}fio non installato — IOPS test saltato (apt install fio)${NC}"
  fi

  # Test 4: latenza accesso
  echo ""
  echo -e "${CYAN}[*] Test latenza accesso (seek time)...${NC}"
  LATENCY=$(dd if="$TEST_DISK" of=/dev/null bs=512 count=1000 iflag=direct 2>&1 | \
            grep -oP '[0-9.]+ s,' | head -1 | grep -oP '[0-9.]+')
  if [[ -n "$LATENCY" ]]; then
    LAT_MS=$(echo "scale=1; $LATENCY * 1000 / 1000" | bc 2>/dev/null)
    echo -e "    Latenza media: ${GREEN}${LATENCY}s per 1000 operazioni${NC}"
  fi

  # Stato SMART
  echo ""
  echo -e "${CYAN}[*] Stato S.M.A.R.T.:${NC}"
  HEALTH=$(smartctl -H "$TEST_DISK" 2>/dev/null | grep "overall-health" | awk '{print $NF}')
  REALLOCATED=$(smartctl -A "$TEST_DISK" 2>/dev/null | grep "Reallocated_Sector" | awk '{print $10}')
  PENDING=$(smartctl -A "$TEST_DISK" 2>/dev/null | grep "Current_Pending" | awk '{print $10}')
  HOURS=$(smartctl -A "$TEST_DISK" 2>/dev/null | grep "Power_On_Hours" | awk '{print $10}')

  [[ "$HEALTH" == "PASSED" ]] && \
    echo -e "    Salute       : ${GREEN}PASSED${NC}" || \
    echo -e "    Salute       : ${RED}${HEALTH:-N/A}${NC}"
  echo -e "    Settori rialloc.: ${REALLOCATED:-N/A}"
  echo -e "    Settori pending : ${PENDING:-N/A}"
  echo -e "    Ore acceso   : ${HOURS:-N/A}"

  log "Disk benchmark completato su $TEST_DISK ($DISK_TYPE)"
  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 4. ANALISI RAM ────────────────────────────────────────────

analyze_ram() {
  header
  separator
  echo -e "${BOLD}  ANALISI RAM${NC}"
  separator
  echo ""

  # Info fisiche
  echo -e "${CYAN}[*] Moduli RAM installati:${NC}"
  dmidecode --type memory 2>/dev/null | awk '
    /Memory Device/    { in_dev=1; slot=""; size=""; speed=""; type=""; loc="" }
    in_dev && /Size:/  { size=$2" "$3 }
    in_dev && /Speed:/ && /MT/ { speed=$2" "$3 }
    in_dev && /^[[:space:]]+Type:/ && !/Unknown/ { type=$2 }
    in_dev && /Locator:/ && !/Bank/ { loc=$2 }
    in_dev && /Manufacturer:/ { mfg=$2 }
    in_dev && size && size!="No Module" {
      printf "    Slot %-8s %s  %-8s %-10s %s\n", loc, size, type, speed, mfg
      in_dev=0
    }
  ' || echo "  (dmidecode non disponibile)"

  echo ""
  echo -e "${CYAN}[*] Uso memoria attuale:${NC}"
  free -h | awk '
    /^Mem/  { printf "    RAM  — Totale: %-8s  Usata: %-8s  Libera: %-8s  Cache: %s\n",$2,$3,$4,$6 }
    /^Swap/ { printf "    SWAP — Totale: %-8s  Usata: %-8s  Libera: %s\n",$2,$3,$4 }
  '

  echo ""
  echo -e "${CYAN}[*] Top 10 processi per uso RAM:${NC}"
  ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=11 {printf "    %-6s %-5s%%  %s\n",$1,$4,$11}' || \
    echo "  (ps non disponibile)"

  echo ""
  echo -e "${CYAN}[*] Pressione memoria (vmstat):${NC}"
  vmstat 1 3 2>/dev/null | tail -1 | awk '{
    printf "    Run queue: %s | Swap in: %s | Swap out: %s | Free: %s KB\n",$1,$7,$8,$4
  }' || echo "  N/A"

  echo ""
  echo -e "${CYAN}[*] Test velocità RAM (sysbench)...${NC}"
  if command -v sysbench &>/dev/null; then
    SPEED=$(sysbench memory --memory-block-size=4K --memory-total-size=2G run 2>/dev/null | \
            grep "transferred" | grep -oP '[0-9.]+ MiB/sec')
    echo -e "    Banda: ${GREEN}${SPEED:-N/A}${NC}"
  else
    # Fallback con dd
    SPEED=$(dd if=/dev/zero of=/dev/null bs=1M count=2048 2>&1 | grep -oP '[0-9.]+ [MG]B/s' | tail -1)
    echo -e "    Banda (stima): ${GREEN}${SPEED:-N/A}${NC}"
  fi

  log "Analisi RAM completata"
  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 5. ANALISI TERMICA ────────────────────────────────────────

thermal_analysis() {
  header
  separator
  echo -e "${BOLD}  ANALISI TERMICA${NC}"
  separator
  echo ""

  if ! command -v sensors &>/dev/null; then
    echo -e "${YELLOW}[!] lm-sensors non installato. Esegui: apt install lm-sensors && sensors-detect${NC}"
    echo ""
    # Fallback: leggi da sysfs
    echo -e "${CYAN}[*] Temperature da sysfs (/sys/class/thermal):${NC}"
    for f in /sys/class/thermal/thermal_zone*/temp; do
      [[ -f "$f" ]] || continue
      ZONE=$(dirname "$f" | xargs basename)
      TYPE=$(cat "$(dirname "$f")/type" 2>/dev/null || echo "unknown")
      TEMP=$(cat "$f" 2>/dev/null)
      TEMP_C=$((TEMP / 1000))
      if   [[ $TEMP_C -le 60 ]]; then echo -e "    $ZONE ($TYPE): ${GREEN}${TEMP_C}°C${NC}"
      elif [[ $TEMP_C -le 80 ]]; then echo -e "    $ZONE ($TYPE): ${YELLOW}${TEMP_C}°C${NC}"
      else                            echo -e "    $ZONE ($TYPE): ${RED}${TEMP_C}°C [CRITICA]${NC}"; fi
    done
  else
    echo -e "${CYAN}[*] Temperature sensori:${NC}"
    sensors 2>/dev/null | while IFS= read -r line; do
      if echo "$line" | grep -qE "°C"; then
        TEMP=$(echo "$line" | grep -oP '[0-9]+\.[0-9]+(?=°C)' | head -1)
        TEMP_INT=${TEMP%.*}
        if   [[ -z "$TEMP_INT" ]]; then echo "    $line"
        elif [[ $TEMP_INT -le 60 ]]; then echo -e "    ${GREEN}$line${NC}"
        elif [[ $TEMP_INT -le 80 ]]; then echo -e "    ${YELLOW}$line${NC}"
        else                              echo -e "    ${RED}$line [!]${NC}"; fi
      fi
    done
  fi

  echo ""
  echo -e "${CYAN}[*] Velocità ventole:${NC}"
  sensors 2>/dev/null | grep -iE "fan|rpm" | sed 's/^/    /' || \
    echo "    N/A (sensori ventole non rilevati)"

  # Stress test termico opzionale
  echo ""
  if command -v stress-ng &>/dev/null; then
    read -p "Avviare stress test termico 30s? (s/N): " STRESS_ANS
    if [[ "${STRESS_ANS,,}" == "s" ]]; then
      echo -e "${YELLOW}[*] Stress test CPU 30s — monitora temperatura...${NC}"
      CPU_CORES=$(nproc)
      stress-ng --cpu "$CPU_CORES" --timeout 30s --metrics-brief 2>/dev/null &
      STRESS_PID=$!
      for i in $(seq 1 6); do
        sleep 5
        TEMP=$(sensors 2>/dev/null | grep -E "Core 0|Package id 0|Tdie" | \
               head -1 | grep -oP '[0-9]+\.[0-9]+(?=°C)' | head -1)
        echo -e "    ${i}0s: ${TEMP:-N/A}°C"
      done
      wait $STRESS_PID 2>/dev/null
      echo -e "${GREEN}[✓] Stress test completato${NC}"
      log "Stress test termico eseguito"
    fi
  else
    echo -e "  ${YELLOW}stress-ng non installato — stress test non disponibile (apt install stress-ng)${NC}"
  fi

  log "Analisi termica completata"
  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 6. ANALISI RETE ───────────────────────────────────────────

network_performance() {
  header
  separator
  echo -e "${BOLD}  ANALISI PERFORMANCE RETE${NC}"
  separator
  echo ""

  echo -e "${CYAN}[*] Interfacce di rete:${NC}"
  ip -s link show 2>/dev/null | awk '
    /^[0-9]+:/ {
      name=$2; sub(/:$/,"",name)
    }
    /RX:/ { getline; rx=$1 }
    /TX:/ { getline; tx=$1; printf "    %-12s RX: %s byte | TX: %s byte\n", name, rx, tx }
  ' || ip link show | grep -E "^[0-9]" | awk '{print "    "$2}'

  echo ""
  echo -e "${CYAN}[*] Velocità interfacce fisiche:${NC}"
  for iface in $(ls /sys/class/net/ 2>/dev/null); do
    SPEED=$(cat /sys/class/net/$iface/speed 2>/dev/null)
    DUPLEX=$(cat /sys/class/net/$iface/duplex 2>/dev/null)
    STATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
    [[ -n "$SPEED" && "$SPEED" -gt 0 ]] 2>/dev/null && \
      echo -e "    $iface: ${BOLD}${SPEED} Mbps${NC} $DUPLEX — stato: $STATE"
  done

  echo ""
  echo -e "${CYAN}[*] Connettività e latenza:${NC}"
  for host in "8.8.8.8" "1.1.1.1"; do
    PING=$(ping -c 3 -W 2 "$host" 2>/dev/null | tail -1 | grep -oP '[0-9.]+/[0-9.]+/[0-9.]+')
    if [[ -n "$PING" ]]; then
      AVG=$(echo "$PING" | cut -d/ -f2)
      AVG_INT=${AVG%.*}
      if   [[ $AVG_INT -le 20  ]]; then echo -e "    $host: ${GREEN}${AVG}ms [ECCELLENTE]${NC}"
      elif [[ $AVG_INT -le 80  ]]; then echo -e "    $host: ${YELLOW}${AVG}ms [NELLA NORMA]${NC}"
      else                               echo -e "    $host: ${RED}${AVG}ms [ALTA LATENZA]${NC}"; fi
    else
      echo -e "    $host: ${RED}non raggiungibile${NC}"
    fi
  done

  echo ""
  echo -e "${CYAN}[*] DNS lookup:${NC}"
  DNS_T=$(TIMEFORMAT='%R'; { time nslookup google.com > /dev/null 2>&1; } 2>&1)
  echo -e "    Risoluzione google.com: ${DNS_T:-N/A}s"

  log "Analisi rete completata"
  echo ""
  read -p "Premi INVIO per continuare..."
}

# ── 7. REPORT COMPLETO ────────────────────────────────────────

generate_report() {
  header
  echo -e "${CYAN}[*] Generazione report completo performance...${NC}"
  echo ""

  strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

  {
    echo "=================================================="
    echo "  PERFORMANCE REPORT — $(date)"
    echo "  Host: $(hostname)  |  Kernel: $(uname -r)"
    echo "=================================================="
    echo ""

    echo "=== CPU ==="
    grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
    echo "Core: $(nproc)  Thread: $(grep -c '^processor' /proc/cpuinfo)"
    echo "Freq: $(grep 'cpu MHz' /proc/cpuinfo | head -1 | awk '{print $4}') MHz"
    echo ""

    echo "=== RAM ==="
    free -h | grep -E "Mem|Swap"
    dmidecode --type memory 2>/dev/null | grep -E "Size:|Speed:|Type:" | \
      grep -v "Unknown\|No Module\|Error" | head -8
    echo ""

    echo "=== DISCHI ==="
    for disk in /dev/sd? /dev/nvme?n?; do
      [[ -b "$disk" ]] || continue
      echo "$disk — $(smartctl -i "$disk" 2>/dev/null | grep 'Device Model\|Model Number' | cut -d: -f2 | xargs) — $(lsblk -dn -o SIZE "$disk" 2>/dev/null)"
      smartctl -H "$disk" 2>/dev/null | grep "overall-health"
      smartctl -A "$disk" 2>/dev/null | grep -E "Reallocated|Pending|Power_On_Hours" | awk '{printf "  %s: %s\n", $2, $10}'
    done
    echo ""

    echo "=== TEMPERATURE ==="
    sensors 2>/dev/null | grep "°C" || \
      for f in /sys/class/thermal/thermal_zone*/temp; do
        [[ -f "$f" ]] && echo "$(basename $(dirname "$f")): $(($(cat "$f")/1000))°C"
      done
    echo ""

    echo "=== RETE ==="
    ip link show | grep "state UP" | awk '{print $2}' | tr -d ':'
    ping -c 2 8.8.8.8 2>/dev/null | tail -1
    echo ""

    echo "=== LOG ==="
    echo "Log completo: $LOG"

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
  echo "  1) Panoramica sistema (CPU, RAM, dischi, GPU)"
  echo "  2) Benchmark CPU"
  echo "  3) Benchmark disco (velocità, IOPS, latenza)"
  echo "  4) Analisi RAM (moduli, banda, pressione)"
  echo "  5) Analisi termica (temperature, ventole, stress test)"
  echo "  6) Performance rete (latenza, banda, DNS)"
  echo "  7) Genera report completo"
  echo "  8) Esci"
  echo ""
  read -p "  Scelta: " MAIN

  case $MAIN in
    1) system_overview ;;
    2) benchmark_cpu ;;
    3) benchmark_disk ;;
    4) analyze_ram ;;
    5) thermal_analysis ;;
    6) network_performance ;;
    7) generate_report ;;
    8) break ;;
    *) echo -e "${RED}[!] Scelta non valida${NC}"; sleep 1 ;;
  esac
done

echo -e "\n${GREEN}[✓] Log salvato: $LOG${NC}"
