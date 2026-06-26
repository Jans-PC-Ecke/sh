#!/bin/bash

# Prüfen, ob als Root ausgeführt
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31mFehler: Skript benötigt Root-Rechte. Bitte mit sudo ausführen.\033[0m"
    exit 1
fi

echo -e "\033[1;33m🚀 Systembereinigung startet...\033[0m"

# 1. Paket-Cache bereinigen
echo -e "\033[1;36m➡️  Bereinige APT-Cache...\033[0m"
apt-get clean
apt-get autoclean
apt-get autoremove --purge -y

# 2. Alte Konfigurationsreste entfernen
dpkg --list | grep "^rc" | cut -d" " -f3 | xargs apt-get purge -y &> /dev/null

# 3. Alte Kernel entfernen (außer aktuellem)
CURKERNEL=$(uname -r | sed 's/-generic//')
OLDKERNELS=$(dpkg -l | grep 'linux-image-' | awk '{print $2}' | grep -v "$CURKERNEL")
if [ -n "$OLDKERNELS" ]; then
    apt-get purge -y $OLDKERNELS
fi

# 4. Temporäre Dateien löschen
echo -e "\033[1;36m➡️  Leere /tmp und /var/tmp...\033[0m"
find /tmp /var/tmp -type f -mtime +3 -delete 2>/dev/null || true
find /tmp /var/tmp -type d -empty -mtime +3 -delete 2>/dev/null || true

# 5. Papierkorb leeren
echo -e "\033[1;36m➡️  Leere Papierkorb aller Nutzer...\033[0m"
rm -rf /home/*/.local/share/Trash/*/* 2>/dev/null
rm -rf /root/.local/share/Trash/*/* 2>/dev/null

# 6. System-Logs verkleinern
echo -e "\033[1;36m➡️  Bereinige System-Logs...\033[0m"
journalctl --vacuum-time=3d --vacuum-size=500M &> /dev/null
find /var/log -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null

# 7. Thumbnail-Cache löschen
echo -e "\033[1;36m➡️  Leere Bildvorschaucache...\033[0m"
find /home/*/.cache/thumbnails -type f -delete 2>/dev/null

# 8. Flatpak/Snap-Cache (falls vorhanden)
if command -v flatpak &> /dev/null; then
    flatpak uninstall --unused -y &> /dev/null
fi

# 9. Systemdatenbanken aktualisieren
echo -e "\033[1;36m➡️  Aktualisiere Systemdatenbanken...\033[0m"
update-icon-caches /usr/share/icons/* &> /dev/null
update-desktop-database &> /dev/null

echo -e "\033[1;32m✅ Bereinigung abgeschlossen!\033[0m"   
