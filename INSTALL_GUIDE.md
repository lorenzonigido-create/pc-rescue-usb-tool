# PC RESCUE USB TOOL v1.0 — Guida Completa

## Cosa ti serve

| Elemento | Dettaglio |
|---|---|
| USB | Minimo **16 GB** (consigliato 32 GB) |
| OS per creare la USB | Linux (Ubuntu/Debian) con accesso root |
| Sistema base | Debian 12 Bookworm minimal |

---

## Passo 1 — Clona il repository

```bash
git clone https://github.com/lorenzonigido-create/pc-rescue-usb-tool.git
cd pc-rescue-usb-tool
```

---

## Passo 2 — Installa le dipendenze sull'host Linux

```bash
sudo apt update
sudo apt install -y \
  parted grub-pc-bin grub-common \
  testdisk gddrescue smartmontools \
  clamav chkrootkit rkhunter \
  gparted midnight-commander \
  python3 python3-curses \
  ms-sys gdisk ntfs-3g \
  openssh-server links2 rsync nmap \
  lm-sensors dmidecode \
  chntpw wimtools cabextract python3-pip

pip3 install python-evtx
```

---

## Passo 3 — Identifica la USB

```bash
lsblk
# oppure:
fdisk -l | grep "Disk /dev"
# Annota il dispositivo, es: /dev/sdb
```

> **ATTENZIONE**: il passo successivo cancella tutti i dati sulla USB. Assicurati di aver scelto il dispositivo corretto.

---

## Passo 4 — Crea la struttura USB

Lo script partiziona la USB (FAT32 200 MB per GRUB + EXT4 per il sistema), installa GRUB e copia tutti gli script nella posizione corretta.

```bash
chmod +x setup_rescue_usb.sh
sudo bash setup_rescue_usb.sh /dev/sdb
```

Al termine vedrai:

```
✓  USB RESCUE TOOL CREATA CON SUCCESSO!
```

---

## Passo 5 — Installa il sistema base Debian

La partizione EXT4 è pronta ma vuota. Installa Debian 12 minimal con debootstrap:

```bash
sudo debootstrap --arch=amd64 bookworm /mnt/rescue_sys \
  http://deb.debian.org/debian/
```

Poi installa i pacchetti rescue leggendoli da `config/packages.txt`:

```bash
sudo chroot /mnt/rescue_sys bash -c "
  apt update
  apt install -y \$(grep -v '#' /config/packages.txt | tr '\n' ' ')
  pip3 install python-evtx
"
```

---

## Passo 6 — Configura l'avvio automatico del menu

```bash
sudo chroot /mnt/rescue_sys bash << 'EOF'

cat > /etc/systemd/system/rescue-menu.service << 'SVC'
[Unit]
Description=PC Rescue Menu
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /tools/gui/rescue_menu.py
StandardInput=tty
TTYPath=/dev/tty1
Restart=always

[Install]
WantedBy=multi-user.target
SVC

systemctl enable rescue-menu.service
systemctl set-default multi-user.target

EOF
```

---

## Struttura file sulla USB

```
USB
├── [Partizione 1 — FAT32 200 MB — RESCUE_BOOT]
│   └── boot/
│       ├── grub/grub.cfg
│       ├── vmlinuz
│       └── initrd.img
│
└── [Partizione 2 — EXT4 ~15 GB — RESCUE_SYS]
    ├── [sistema Debian 12 minimal]
    ├── tools/
    │   ├── recovery/          — Riparazione boot Windows/Linux
    │   ├── windows/
    │   │   └── windows_sysrepair.sh
    │   ├── performance/
    │   │   └── performance_check.sh
    │   ├── data_recovery/     — TestDisk, PhotoRec, ddrescue
    │   ├── diagnostics/       — SMART, RAM, badblocks, hardware
    │   ├── antivirus/         — ClamAV, chkrootkit, rkhunter
    │   ├── backup/            — Clonezilla, dd, rsync
    │   ├── password/          — chntpw, reset Linux
    │   ├── network/           — WiFi, SSH, links2
    │   └── advanced/          — GParted, MC, editor
    ├── gui/
    │   └── rescue_menu.py
    ├── logs/
    └── config/
        └── packages.txt
```

---

## Come usare la USB su un PC da riparare

### Tasto boot menu per marca

| Marca PC | Tasto |
|---|---|
| Dell | F12 |
| HP | F9 o F10 |
| Lenovo | F12 o F1 |
| ASUS | F8 o ESC |
| Acer | F12 |
| MSI | F11 |
| BIOS generico | F2, DEL, ESC |

### Sequenza di avvio

1. Inserisci USB → accendi il PC → premi il tasto boot menu
2. Seleziona la USB → GRUB si avvia
3. Scegli **"PC Rescue Tool"**
4. Il menu si apre automaticamente
5. Naviga con **↑↓**, seleziona con **INVIO**, torna indietro con **B**

---

## Funzionalità

### Recovery Sistema Operativo
- Ripara MBR/BCD Windows
- Reinstalla GRUB Linux
- Ripristina tabella partizioni GPT corrotta

### Windows System Repair
Monta la partizione NTFS del PC target e offre:
- **SFC Offline**: verifica 25+ file critici di sistema (kernel, DLL, eseguibili)
- **DISM Offline**: estrae e ripristina file da `install.wim` / `install.esd`
- **Registro**: backup/restore hive, analisi chiavi di avvio (Run/RunOnce), reset password account Windows
- **DLL & Driver**: scansione DLL critiche mancanti o corrotte, analisi driver `.sys` sospetti
- **Log eventi**: lettura file `.evtx` con filtri per BSOD, errori disco, crash applicazioni
- **Report completo**: output pulito salvato in `/logs/`

### Recupero Dati
- **TestDisk**: recupera partizioni e file system
- **PhotoRec**: recupera foto, video, documenti
- **ddrescue**: clona dischi fisicamente danneggiati

### Diagnostica
- Test RAM (Memtest86+), S.M.A.R.T., badblocks, report hardware completo

### Antivirus & Malware
- ClamAV, chkrootkit, rkhunter

### Backup & Clonazione
- Clonezilla, dd, rsync

### Reset Password
- Windows (chntpw), Linux (chroot)

### Analisi Performance
- **Panoramica sistema**: CPU (modello, frequenza, temperatura), RAM (tipo, velocità, uso), dischi, GPU
- **Benchmark CPU**: single-thread e multi-thread (sysbench), test banda RAM
- **Benchmark disco**: lettura/scrittura sequenziale (hdparm, dd), IOPS random 4K (fio), latenza, stato S.M.A.R.T.
- **Analisi RAM**: moduli fisici installati, banda, top processi per memoria, pressione swap
- **Analisi termica**: temperature sensori, velocità ventole, stress test termico opzionale (stress-ng)
- **Performance rete**: velocità interfacce, latenza ping, risoluzione DNS
- **Report completo**: salvato in `/logs/`

### Rete & Accesso Remoto
- Configurazione WiFi/Ethernet, SSH server, browser testuale, trasferimento file

---

## Tool software inclusi

```
testdisk / photorec    — Recupero dati e partizioni
gddrescue              — Clonazione dischi danneggiati
smartmontools          — Diagnostica S.M.A.R.T.
memtest86+             — Test RAM
gparted                — Editor partizioni grafico
clamav                 — Antivirus
chkrootkit / rkhunter  — Anti-rootkit
ntfs-3g                — Lettura/scrittura NTFS
chntpw                 — Gestione registro e password Windows
wimtools               — Estrazione file da install.wim (DISM offline)
cabextract             — Estrazione archivi CAB Windows
python-evtx            — Lettura log eventi .evtx
sysbench               — Benchmark CPU e RAM
hdparm                 — Benchmark lettura disco
fio                    — Benchmark IOPS disco
stress-ng              — Stress test termico
lm-sensors             — Temperature e ventole
bc                     — Calcoli numerici negli script bash
grub-pc-bin            — Bootloader GRUB BIOS/MBR
midnight-commander     — File manager testuale
openssh-server         — Accesso remoto SSH
nmap                   — Scansione rete
rsync                  — Backup/sincronizzazione
```

---

## FAQ

**Q: Funziona su PC UEFI?**
A: Sì, ma devi modificare il comando GRUB. In `setup_rescue_usb.sh`, nella funzione `install_grub`, sostituisci:
```bash
grub-install --target=i386-pc ...
```
con:
```bash
grub-install --target=x86_64-efi --efi-directory=$MOUNT_BOOT --bootloader-id=RESCUE
```

**Q: Windows System Repair non riesce a montare la partizione.**
A: Il PC potrebbe avere la funzione Avvio Rapido (Fast Startup) attiva. Prova prima:
```bash
ntfsfix /dev/sdaX
```
poi ritenta il montaggio. Se il disco è ibernato, il flag `remove_hiberfile` viene già passato automaticamente.

**Q: DISM offline non trova install.wim.**
A: Il file si trova sul supporto di installazione Windows (DVD o ISO). Collega il DVD o monta l'ISO:
```bash
mount -o loop /path/to/windows.iso /mnt/winiso
```
poi indica il path `/mnt/winiso/sources/install.wim` quando richiesto.

**Q: Come aggiungo un nuovo tool al menu?**
A: Copia lo script in `/tools/<categoria>/` sulla USB e aggiungi una voce al `MENU` in `rescue_menu.py`.

**Q: I log dove vengono salvati?**
A: In `/logs/` sulla partizione EXT4 della USB. Ogni operazione genera un file con timestamp.

---

*PC Rescue Tool v1.0 — Lorenzo Nigido*
