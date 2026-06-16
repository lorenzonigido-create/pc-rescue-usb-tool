# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

**PC Rescue USB Tool v1.0** — a bootable USB toolkit for PC repair technicians. It runs a minimal Debian 12 system from a USB stick, launching a Python TUI (`rescue_menu.py`) automatically at boot via systemd. All scripts are designed to run on the *target machine being repaired*, not on the development machine.

## Setup: creating the USB

Must run on a Linux host with root. The USB will be completely wiped.

```bash
sudo bash setup_rescue_usb.sh /dev/sdX
```

Then install a Debian 12 minimal base system into the EXT4 partition via `debootstrap` or a netinst ISO, and enable the systemd service (see [INSTALL_GUIDE.md](INSTALL_GUIDE.md) for full steps).

## Running the TUI menu (on the rescue USB system)

```bash
python3 /tools/gui/rescue_menu.py
```

Navigate with arrow keys, ENTER to select, B/ESC to go back, Q to quit (triggers reboot).

## Architecture

```
setup_rescue_usb.sh     — partitions USB (FAT32 boot + EXT4 system), installs GRUB, copies files
rescue_menu.py          — Python curses TUI; main entry point on the live USB
boot_repair.sh          — interactive boot repair (Windows MBR/BCD, Linux GRUB, GPT)
diagnostics.sh          — hardware diagnostics (SMART, RAM, logs, hardware info)
recover_data.sh         — data recovery launcher (TestDisk, PhotoRec, ddrescue)
INSTALL_GUIDE.md        — full step-by-step setup guide
```

### USB partition layout

| Partition | FS | Size | Label | Purpose |
|---|---|---|---|---|
| /dev/sdX1 | FAT32 | 200 MB | RESCUE_BOOT | GRUB bootloader |
| /dev/sdX2 | EXT4 | ~15 GB | RESCUE_SYS | Debian system + tools |

### Tool categories (on the live system at `/tools/`)

`recovery/`, `data_recovery/`, `diagnostics/`, `antivirus/`, `backup/`, `password/`, `network/`, `advanced/`

Each sub-script is invoked by `rescue_menu.py` via `subprocess.run(["bash", script_path])`. To add a new tool: place the script in the relevant `/tools/<category>/` directory and add an entry to the `MENU` list in `rescue_menu.py`.

### Logging

All operations log to `/logs/rescue_operations.log` (TUI) and timestamped files under `/logs/` (individual scripts).

## Testing (Windows, senza Linux/WSL)

Syntax check di tutti gli script bash:
```powershell
foreach ($f in @("setup_rescue_usb.sh","boot_repair.sh","diagnostics.sh","recover_data.sh")) {
  $r = & bash -n $f 2>&1
  if ($LASTEXITCODE -eq 0) { Write-Host "OK  $f" } else { Write-Host "ERR $f"; $r }
}
```

Simulazione struttura e navigazione del menu Python (senza curses):
```powershell
$env:PYTHONIOENCODING="utf-8"; python test_menu_sim.py
```

`test_menu_sim.py` esegue 3 test automatici (struttura, duplicati, categorie) e offre una simulazione interattiva testuale del menu. Non richiede Linux né curses.

## Key constraints

- All scripts assume they run as **root** on the live rescue system (Linux).
- `boot_repair.sh` and `recover_data.sh` are interactive — they use `read` prompts, not arguments.
- GRUB is installed in BIOS/MBR mode (`i386-pc`). For UEFI systems, use `--target=x86_64-efi` instead (see FAQ in INSTALL_GUIDE.md).
- The Python TUI requires `python3-curses` (included in `config/packages.txt`).
