# 🔧 PC RESCUE USB TOOL v1.0 — Guida Completa

## 📦 Cosa ti serve

| Elemento | Dettaglio |
|---|---|
| USB | Minimo **16 GB** (consigliato 32 GB) |
| OS per creare la USB | Linux (Ubuntu/Debian) |
| Permessi | Root (sudo) |
| Sistema base | Debian 12 Bookworm minimal |

---

## 🚀 Passo 1 — Prepara il sistema Linux host

```bash
# Installa i tool necessari
sudo apt update
sudo apt install -y \
  parted grub-pc-bin grub-common \
  testdisk gddrescue smartmontools \
  clamav chkrootkit rkhunter \
  gparted midnight-commander \
  python3 python3-curses \
  ms-sys gdisk ntfs-3g \
  openssh-server links2 rsync nmap \
  lm-sensors dmidecode
```

---

## 🚀 Passo 2 — Identifica la tua USB

```bash
# Inserisci la USB, poi:
lsblk
# oppure:
fdisk -l | grep "Disk /dev"
# Nota il dispositivo, es: /dev/sdb
```

---

## 🚀 Passo 3 — Crea la USB Rescue

```bash
# Clona il repository del tool
cd ~/pc-rescue-tool

# Rendi eseguibile lo script
chmod +x setup_rescue_usb.sh

# Esegui (sostituisci /dev/sdb con il tuo dispositivo)
sudo bash setup_rescue_usb.sh /dev/sdb
```

> ⚠️ **ATTENZIONE**: Tutti i dati sulla USB verranno cancellati!

---

## 🚀 Passo 4 — Installa il sistema base (Debian minimal)

```bash
# Scarica Debian netinst
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12-amd64-netinst.iso

# Oppure usa debootstrap per un sistema minimo
sudo debootstrap --arch=amd64 bookworm /mnt/rescue_sys \
  http://deb.debian.org/debian/

# Installa i pacchetti rescue
sudo chroot /mnt/rescue_sys bash -c "
  apt update
  apt install -y $(cat /mnt/rescue_sys/config/packages.txt | grep -v '#' | tr '\n' ' ')
"
```

---

## 🚀 Passo 5 — Configura l'avvio automatico del menu

```bash
# Nel sistema chroot
sudo chroot /mnt/rescue_sys bash << 'EOF'

# Crea servizio systemd per il menu
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

# Disabilita login automatico (usa solo il menu)
systemctl set-default multi-user.target

EOF
```

---

## 📋 Struttura file finale

```
USB (16GB)
├── [Partizione 1 FAT32 200MB] — Boot
│   └── boot/
│       ├── grub/
│       │   └── grub.cfg
│       ├── vmlinuz
│       └── initrd.img
│
└── [Partizione 2 EXT4 ~15GB] — Sistema
    ├── [sistema Debian minimal]
    ├── tools/
    │   ├── recovery/
    │   │   └── boot_repair.sh
    │   ├── data_recovery/
    │   │   └── recover_data.sh
    │   ├── diagnostics/
    │   │   └── diagnostics.sh
    │   ├── antivirus/
    │   ├── backup/
    │   ├── password/
    │   ├── network/
    │   └── advanced/
    ├── gui/
    │   └── rescue_menu.py
    ├── logs/
    └── config/
        └── packages.txt
```

---

## 💻 Come usare la USB su un PC da riparare

### Accedere al BIOS/Boot Menu

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

1. Inserisci USB → Accendi PC → Premi tasto boot menu
2. Seleziona la USB → GRUB si avvia
3. Scegli **"PC Rescue Tool"**
4. Il menu Python si apre automaticamente
5. Naviga con **↑↓** → Seleziona con **INVIO**

---

## 🛡️ Funzionalità dettagliate

### 1. Recovery Sistema
- Ripara MBR/BCD Windows (bootrec equivalente)
- Reinstalla GRUB per Linux
- Ripristina tabella partizioni GPT corrotta

### 2. Recupero Dati
- **TestDisk**: recupera partizioni e file cancellati
- **PhotoRec**: recupera foto, video, documenti da qualsiasi disco
- **ddrescue**: clona dischi fisicamente danneggiati byte per byte

### 3. Diagnostica
- Test RAM con Memtest86+
- S.M.A.R.T. per stato salute dischi
- Badblocks per settori danneggiati
- Report hardware completo

### 4. Antivirus
- ClamAV: scansione malware
- chkrootkit + rkhunter: rileva rootkit

### 5. Backup
- Clonezilla: backup/ripristino partizioni
- dd: immagine disco completa
- rsync: sincronizzazione dati

### 6. Reset Password
- Reset password Windows (chntpw)
- Reset password Linux (chroot)

---

## 🔧 Tool software inclusi

```
testdisk / photorec    — Recupero dati
gddrescue              — Clonazione dischi
smartmontools          — Diagnostica dischi
memtest86+             — Test RAM
gparted                — Editor partizioni
clamav                 — Antivirus
chkrootkit / rkhunter  — Anti-rootkit
chntpw                 — Reset password Windows
grub-repair            — Riparazione GRUB
ntfs-3g                — Accesso NTFS
midnight-commander     — File manager
openssh-server         — Accesso remoto
nmap                   — Diagnostica rete
rsync                  — Backup/sync
```

---

## ❓ FAQ

**Q: Funziona su PC UEFI?**
A: Sì, ma devi aggiungere il bootloader UEFI. Usa `grub-install --target=x86_64-efi` invece di `i386-pc`.

**Q: Posso aggiungere altri tool?**
A: Sì, copia gli script in `/tools/<categoria>/` e aggiornali in `rescue_menu.py`.

**Q: I log dove vengono salvati?**
A: In `/logs/` sulla partizione EXT4 della USB.

---

*PC Rescue Tool v1.0 — Creato con ❤️ per tecnici e appassionati*
