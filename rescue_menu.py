#!/usr/bin/env python3
"""
PC RESCUE TOOL v1.0
Interfaccia grafica TUI per il tool di recupero USB
"""

import curses
import subprocess
import os
import sys
import time
from datetime import datetime

LOG_FILE = "/logs/rescue_operations.log"

def log(message):
    os.makedirs("/logs", exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {message}\n")

def run_script(script_path, stdscr):
    curses.endwin()
    print(f"\n[*] Esecuzione: {script_path}\n")
    try:
        subprocess.run(["bash", script_path], check=False)
    except Exception as e:
        print(f"[!] Errore: {e}")
    input("\nPremi INVIO per tornare al menu...")
    stdscr.touchwin()
    stdscr.refresh()

def show_submenu(stdscr, title, items):
    curses.curs_set(0)
    current = 0
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        # Box
        stdscr.attron(curses.color_pair(2))
        stdscr.border()
        stdscr.attroff(curses.color_pair(2))
        # Title
        stdscr.attron(curses.color_pair(3) | curses.A_BOLD)
        stdscr.addstr(2, (w - len(title)) // 2, title)
        stdscr.attroff(curses.color_pair(3) | curses.A_BOLD)

        for i, (label, _) in enumerate(items):
            x = (w - 50) // 2
            y = 5 + i
            if i == current:
                stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
                stdscr.addstr(y, x, f"  ▶  {label:<44}")
                stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)
            else:
                stdscr.attron(curses.color_pair(4))
                stdscr.addstr(y, x, f"     {label:<44}")
                stdscr.attroff(curses.color_pair(4))

        back_y = 5 + len(items) + 1
        stdscr.attron(curses.color_pair(5))
        stdscr.addstr(back_y, (w - 20) // 2, "  [B] Torna al Menu  ")
        stdscr.attroff(curses.color_pair(5))

        stdscr.refresh()
        key = stdscr.getch()

        if key == curses.KEY_UP and current > 0:
            current -= 1
        elif key == curses.KEY_DOWN and current < len(items) - 1:
            current += 1
        elif key in [curses.KEY_ENTER, ord('\n'), ord('\r')]:
            _, script = items[current]
            log(f"Avviato: {items[current][0]}")
            run_script(script, stdscr)
        elif key in [ord('b'), ord('B'), 27]:
            break

def draw_header(stdscr, w):
    header = "██████╗ ███████╗ ██████╗██╗   ██╗███████╗"
    sub    = "RESCUE  USB  TOOL  v1.0  —  PC  REPAIR"
    stdscr.attron(curses.color_pair(3) | curses.A_BOLD)
    stdscr.addstr(1, (w - len(header)) // 2, header)
    stdscr.addstr(2, (w - len(sub)) // 2, sub)
    stdscr.attroff(curses.color_pair(3) | curses.A_BOLD)

def main_menu(stdscr):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()

    # Colori
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)    # selezione
    curses.init_pair(2, curses.COLOR_CYAN, -1)                    # bordo
    curses.init_pair(3, curses.COLOR_CYAN, -1)                    # titolo
    curses.init_pair(4, curses.COLOR_WHITE, -1)                   # voci menu
    curses.init_pair(5, curses.COLOR_RED, -1)                     # uscita

    MENU = [
        ("🔄  Recovery Sistema Operativo",   "recovery",   [
            ("Ripara avvio Windows (bootrec)",        "/tools/recovery/fix_windows_boot.sh"),
            ("Ripara GRUB Linux",                     "/tools/recovery/fix_grub.sh"),
            ("Reinstalla MBR",                        "/tools/recovery/fix_mbr.sh"),
            ("Ripara tabella partizioni GPT",         "/tools/recovery/fix_gpt.sh"),
            ("Modalità recovery Windows PE",          "/tools/recovery/winpe_boot.sh"),
        ]),
        ("🪟  Windows System Repair",        "winrepair",  [
            ("Avvia Windows System Repair Tool",      "/tools/windows/windows_sysrepair.sh"),
        ]),
        ("💾  Recupero Dati Persi",          "data",       [
            ("Recupera file cancellati (TestDisk)",   "/tools/data_recovery/testdisk.sh"),
            ("Recupera foto/video (PhotoRec)",        "/tools/data_recovery/photorec.sh"),
            ("Clona disco danneggiato (ddrescue)",    "/tools/data_recovery/ddrescue.sh"),
            ("Recupera partizione persa",             "/tools/data_recovery/recover_partition.sh"),
        ]),
        ("🔍  Diagnostica Sistema",          "diag",       [
            ("Test RAM (Memtest86+)",                 "/tools/diagnostics/memtest.sh"),
            ("Test disco (S.M.A.R.T.)",              "/tools/diagnostics/smartctl.sh"),
            ("Test disco (badblocks)",               "/tools/diagnostics/badblocks.sh"),
            ("Info hardware (hardinfo)",             "/tools/diagnostics/hardinfo.sh"),
            ("Log di sistema",                       "/tools/diagnostics/show_logs.sh"),
        ]),
        ("🛡️  Antivirus & Malware",          "av",         [
            ("Scansione ClamAV",                     "/tools/antivirus/clamav_scan.sh"),
            ("Rimuovi malware noti",                 "/tools/antivirus/remove_malware.sh"),
            ("Controllo rootkit (chkrootkit)",       "/tools/antivirus/chkrootkit.sh"),
            ("Controllo rootkit (rkhunter)",         "/tools/antivirus/rkhunter.sh"),
        ]),
        ("🗂️  Backup & Clonazione",          "backup",     [
            ("Backup partizione (Clonezilla)",       "/tools/backup/clonezilla.sh"),
            ("Crea immagine disco (dd)",             "/tools/backup/disk_image.sh"),
            ("Sincronizza cartelle (rsync)",         "/tools/backup/rsync_backup.sh"),
        ]),
        ("🔑  Reset Password",               "passwd",     [
            ("Reset password Windows",               "/tools/password/reset_win_password.sh"),
            ("Reset password Linux",                 "/tools/password/reset_linux_password.sh"),
            ("Visualizza hash SAM Windows",          "/tools/password/dump_sam.sh"),
        ]),
        ("🌐  Rete & Accesso Remoto",        "net",        [
            ("Configura rete WiFi/Ethernet",         "/tools/network/setup_network.sh"),
            ("Avvia SSH server",                     "/tools/network/start_ssh.sh"),
            ("Browser web (links2)",                 "/tools/network/browser.sh"),
            ("Trasferimento file (sftp/scp)",        "/tools/network/file_transfer.sh"),
        ]),
        ("📊  Analisi Performance",          "perf",       [
            ("Avvia Performance Analysis Tool",       "/tools/performance/performance_check.sh"),
        ]),
        ("⚙️  Strumenti Avanzati",           "adv",        [
            ("Editor partizioni (GParted)",          "/tools/advanced/gparted.sh"),
            ("Terminale bash",                       "/tools/advanced/terminal.sh"),
            ("Esplora file (Midnight Commander)",    "/tools/advanced/mc.sh"),
            ("Editor testo (nano/vim)",              "/tools/advanced/editor.sh"),
        ]),
    ]

    current = 0

    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()

        stdscr.attron(curses.color_pair(2))
        stdscr.border()
        stdscr.attroff(curses.color_pair(2))

        draw_header(stdscr, w)

        # Separatore
        stdscr.attron(curses.color_pair(2))
        stdscr.addstr(4, 1, "─" * (w - 2))
        stdscr.attroff(curses.color_pair(2))

        # Voci menu
        for i, (label, _, _) in enumerate(MENU):
            x = (w - 52) // 2
            y = 6 + i
            if i == current:
                stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
                stdscr.addstr(y, x, f"  ▶  {label:<46}")
                stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)
            else:
                stdscr.attron(curses.color_pair(4))
                stdscr.addstr(y, x, f"     {label:<46}")
                stdscr.attroff(curses.color_pair(4))

        # Footer
        footer_y = 6 + len(MENU) + 1
        stdscr.attron(curses.color_pair(2))
        stdscr.addstr(footer_y, 1, "─" * (w - 2))
        stdscr.attroff(curses.color_pair(2))

        help_text = "↑↓ Naviga   INVIO Seleziona   Q Esci"
        stdscr.attron(curses.color_pair(4))
        stdscr.addstr(footer_y + 1, (w - len(help_text)) // 2, help_text)
        stdscr.attroff(curses.color_pair(4))

        # Data/ora
        now = datetime.now().strftime("%d/%m/%Y  %H:%M:%S")
        stdscr.attron(curses.color_pair(4))
        stdscr.addstr(h - 2, w - len(now) - 2, now)
        stdscr.attroff(curses.color_pair(4))

        stdscr.refresh()
        key = stdscr.getch()

        if key == curses.KEY_UP and current > 0:
            current -= 1
        elif key == curses.KEY_DOWN and current < len(MENU) - 1:
            current += 1
        elif key in [curses.KEY_ENTER, ord('\n'), ord('\r')]:
            label, _, subitems = MENU[current]
            show_submenu(stdscr, label, subitems)
        elif key in [ord('q'), ord('Q')]:
            confirm_exit(stdscr)

def confirm_exit(stdscr):
    h, w = stdscr.getmaxyx()
    msg = "  Vuoi davvero uscire? (S/N)  "
    y, x = h // 2, (w - len(msg)) // 2
    stdscr.attron(curses.color_pair(5) | curses.A_BOLD)
    stdscr.addstr(y, x, msg)
    stdscr.attroff(curses.color_pair(5) | curses.A_BOLD)
    stdscr.refresh()
    key = stdscr.getch()
    if key in [ord('s'), ord('S'), ord('y'), ord('Y')]:
        curses.endwin()
        print("\n[*] Arrivederci. Riavvio sistema...\n")
        subprocess.run(["reboot"])
        sys.exit(0)

if __name__ == "__main__":
    try:
        curses.wrapper(main_menu)
    except KeyboardInterrupt:
        pass
