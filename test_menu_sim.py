#!/usr/bin/env python3
"""
Simulatore testuale di rescue_menu.py per test su Windows (senza curses).
Replica la struttura del menu e la logica di navigazione via input() standard.
Non esegue script reali — stampa il path che verrebbe lanciato.
"""

import os
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace") if hasattr(sys.stdout, "reconfigure") else None

MENU = [
    ("Recovery Sistema Operativo", "recovery", [
        ("Ripara avvio Windows (bootrec)",        "/tools/recovery/fix_windows_boot.sh"),
        ("Ripara GRUB Linux",                     "/tools/recovery/fix_grub.sh"),
        ("Reinstalla MBR",                        "/tools/recovery/fix_mbr.sh"),
        ("Ripara tabella partizioni GPT",         "/tools/recovery/fix_gpt.sh"),
        ("Modalita recovery Windows PE",          "/tools/recovery/winpe_boot.sh"),
    ]),
    ("Recupero Dati Persi", "data", [
        ("Recupera file cancellati (TestDisk)",   "/tools/data_recovery/testdisk.sh"),
        ("Recupera foto/video (PhotoRec)",        "/tools/data_recovery/photorec.sh"),
        ("Clona disco danneggiato (ddrescue)",    "/tools/data_recovery/ddrescue.sh"),
        ("Recupera partizione persa",             "/tools/data_recovery/recover_partition.sh"),
    ]),
    ("Diagnostica Sistema", "diag", [
        ("Test RAM (Memtest86+)",                 "/tools/diagnostics/memtest.sh"),
        ("Test disco (S.M.A.R.T.)",              "/tools/diagnostics/smartctl.sh"),
        ("Test disco (badblocks)",               "/tools/diagnostics/badblocks.sh"),
        ("Info hardware (hardinfo)",             "/tools/diagnostics/hardinfo.sh"),
        ("Log di sistema",                       "/tools/diagnostics/show_logs.sh"),
    ]),
    ("Antivirus & Malware", "av", [
        ("Scansione ClamAV",                     "/tools/antivirus/clamav_scan.sh"),
        ("Rimuovi malware noti",                 "/tools/antivirus/remove_malware.sh"),
        ("Controllo rootkit (chkrootkit)",       "/tools/antivirus/chkrootkit.sh"),
        ("Controllo rootkit (rkhunter)",         "/tools/antivirus/rkhunter.sh"),
    ]),
    ("Backup & Clonazione", "backup", [
        ("Backup partizione (Clonezilla)",       "/tools/backup/clonezilla.sh"),
        ("Crea immagine disco (dd)",             "/tools/backup/disk_image.sh"),
        ("Sincronizza cartelle (rsync)",         "/tools/backup/rsync_backup.sh"),
    ]),
    ("Reset Password", "passwd", [
        ("Reset password Windows",               "/tools/password/reset_win_password.sh"),
        ("Reset password Linux",                 "/tools/password/reset_linux_password.sh"),
        ("Visualizza hash SAM Windows",          "/tools/password/dump_sam.sh"),
    ]),
    ("Rete & Accesso Remoto", "net", [
        ("Configura rete WiFi/Ethernet",         "/tools/network/setup_network.sh"),
        ("Avvia SSH server",                     "/tools/network/start_ssh.sh"),
        ("Browser web (links2)",                 "/tools/network/browser.sh"),
        ("Trasferimento file (sftp/scp)",        "/tools/network/file_transfer.sh"),
    ]),
    ("Strumenti Avanzati", "adv", [
        ("Editor partizioni (GParted)",          "/tools/advanced/gparted.sh"),
        ("Terminale bash",                       "/tools/advanced/terminal.sh"),
        ("Esplora file (Midnight Commander)",    "/tools/advanced/mc.sh"),
        ("Editor testo (nano/vim)",              "/tools/advanced/editor.sh"),
    ]),
]

# ── Test 1: struttura dati ────────────────────────────────────

def test_menu_structure():
    print("=" * 55)
    print("TEST 1: Struttura menu")
    print("=" * 55)
    errors = []
    for cat_label, cat_key, items in MENU:
        if not items:
            errors.append(f"  [!] Categoria '{cat_label}' ha 0 voci")
        for label, path in items:
            if not path.endswith(".sh"):
                errors.append(f"  [!] Path non .sh: {path}")
            if not path.startswith("/tools/"):
                errors.append(f"  [!] Path fuori da /tools/: {path}")
    if errors:
        for e in errors: print(e)
    else:
        total = sum(len(items) for _, _, items in MENU)
        print(f"  OK  {len(MENU)} categorie, {total} voci totali")
        print(f"  OK  Tutti i path iniziano con /tools/ e terminano con .sh")

# ── Test 2: duplicati ────────────────────────────────────────

def test_duplicates():
    print()
    print("=" * 55)
    print("TEST 2: Duplicati (label e path)")
    print("=" * 55)
    all_labels = [label for _, _, items in MENU for label, _ in items]
    all_paths  = [path  for _, _, items in MENU for _, path in items]
    dup_labels = [x for x in set(all_labels) if all_labels.count(x) > 1]
    dup_paths  = [x for x in set(all_paths)  if all_paths.count(x)  > 1]
    if dup_labels: print(f"  [!] Label duplicate: {dup_labels}")
    else:          print(f"  OK  Nessuna label duplicata")
    if dup_paths:  print(f"  [!] Path duplicati: {dup_paths}")
    else:          print(f"  OK  Nessun path duplicato")

# ── Test 3: copertura categorie ──────────────────────────────

def test_categories():
    print()
    print("=" * 55)
    print("TEST 3: Categorie attese")
    print("=" * 55)
    expected = {"recovery", "data", "diag", "av", "backup", "passwd", "net", "adv"}
    found    = {key for _, key, _ in MENU}
    missing  = expected - found
    extra    = found - expected
    if missing: print(f"  [!] Categorie mancanti: {missing}")
    else:       print(f"  OK  Tutte le {len(expected)} categorie presenti")
    if extra:   print(f"  [i] Categorie extra: {extra}")

# ── Test 4: simulazione navigazione interattiva ──────────────

def show_submenu(title, items):
    while True:
        print()
        print(f"  ┌── {title} ──")
        for i, (label, path) in enumerate(items):
            print(f"  │  {i+1}) {label}")
        print(f"  └── B) Torna al menu principale")
        choice = input("  Scelta: ").strip().upper()
        if choice == "B" or choice == "":
            return
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(items):
                label, path = items[idx]
                print(f"\n  [SIM] Lancerebbe: bash {path}")
                print(f"  [SIM] (in modalita reale: curses.endwin() → subprocess → input() → touchwin/refresh)")
                input("  Premi INVIO per tornare...")
            else:
                print("  [!] Scelta non valida")
        except ValueError:
            print("  [!] Inserisci un numero o B")

def interactive_sim():
    print()
    print("=" * 55)
    print("TEST 4: Simulazione menu interattivo")
    print("=" * 55)
    print("  (Q = esci, numero = entra nella categoria)")
    while True:
        print()
        print("  ╔══ PC RESCUE TOOL v1.0 — SIMULATORE ══╗")
        for i, (label, _, _) in enumerate(MENU):
            print(f"  {i+1:2}) {label}")
        print("  ╚════════════════════════════════════════╝")
        print("  Q) Esci dal simulatore")
        choice = input("  Scelta: ").strip().upper()
        if choice == "Q" or choice == "":
            print("\n  [SIM] Uscita (in modalita reale: reboot)")
            break
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(MENU):
                label, _, items = MENU[idx]
                show_submenu(label, items)
            else:
                print("  [!] Scelta non valida")
        except ValueError:
            print("  [!] Inserisci un numero o Q")

# ── MAIN ─────────────────────────────────────────────────────

if __name__ == "__main__":
    print()
    print("  PC RESCUE TOOL — Test Simulator (Windows / no-curses)")
    print()

    test_menu_structure()
    test_duplicates()
    test_categories()

    print()
    ans = input("Vuoi avviare la simulazione interattiva del menu? (s/N): ").strip().lower()
    if ans == "s":
        interactive_sim()
    else:
        print("Simulazione interattiva saltata.")

    print()
    print("Tutti i test completati.")
