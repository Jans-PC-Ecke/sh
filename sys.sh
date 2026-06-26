#!/bin/bash
# ============================================================
# Sys-Mon – Universelle Temperaturerkennung (Intel/AMD/NVIDIA)
# Erweitert um System-Update, Backup-Scripts und Systembereinigung
# ============================================================

if ! command -v dialog &>/dev/null; then
    echo "Fehler: 'dialog' nicht installiert. Bitte nachinstallieren:"
    echo "  sudo pacman -S dialog"
    exit 1
fi

# Farben
R='\033[0;31m'
Y='\033[1;33m'
G='\033[0;32m'
O='\033[38;5;208m'
NC='\033[0m'

# ======================= UPDATE-FUNKTIONEN (aus update.sh) =======================

update_arch() {
    echo " _   _   _   _  "
    echo "|J| |P| |C| |E| "
    echo " -   -   -   -  "
    echo ""
    echo " Update wird gestartet..."

    # Arch Linux Update-Befehle
    sudo pacman -Syyu
    sudo pamac remove -o
    sudo pacman -Sc
    sudo snap refresh
    sudo flatpak update -y

    echo ""
    echo " Update beendet!"
    echo ""
}

update_debian() {
    echo " _   _   _   _  "
    echo "|J| |P| |C| |E| "
    echo " -   -   -   -  "
    echo ""
    echo " Update wird gestartet..."

    # Debian/Ubuntu Update-Befehle
    sudo apt update
    sudo apt upgrade -y
    sudo apt dist-upgrade -y
    sudo apt autoremove -y
    sudo flatpak update
    sudo snap refresh

    echo ""
    echo " Update beendet!"
    echo ""
}

update_system() {
    # Teste, ob der Rechner arch-based ist
    if [ -d /etc/pacman.d ]; then
        update_arch
    # Teste, ob der Rechner debian-basiert ist
    elif [ -d /etc/apt ]; then
        update_debian
    else
        echo "Kein unterstütztes System erkannt (weder Arch noch Debian)."
    fi
}

# ======================= BACKUP-FUNKTION (aus backup_scripts.sh) =======================

backup_scripts() {
    # Prüfe benötigte Werkzeuge
    if ! command -v rsync &>/dev/null; then
        echo "Fehler: rsync ist nicht installiert."
        return 1
    fi
    if ! command -v sshpass &>/dev/null; then
        echo "Fehler: sshpass ist nicht installiert."
        echo "Installation: sudo pacman -S sshpass  (oder apt install sshpass)"
        return 1
    fi

    # ===== KONFIGURATION – BITTE ANPASSEN! =====
    SERVER_USER="dieter2"
    SERVER_IP="192.168.178.22"
    PASSWORD="12041993"          # Sicherheitshinweis: besser SSH-Key oder interaktive Abfrage verwenden!
    SOURCE_DIR="/home/"          # Quellordner (rekursiv)
    DEST_DIR="/home/dieter2/backup-scripts/"  # Ziel auf Server
    # ==========================================

    echo "Starte Backup von .sh- und .py-Dateien nach $SERVER_USER@$SERVER_IP:$DEST_DIR"
    echo "Log wird nach ~/backup_scripts.log geschrieben."

    # Rsync: Nur .sh- und .py-Dateien und ihre Ordner, inkrementell, leere Ordner überspringen
    SSHPASS="$PASSWORD" sshpass -e rsync -avz --progress --prune-empty-dirs \
        --include='*.sh' --include='*.py' --include='*/' --exclude='*' \
        -e "ssh -o StrictHostKeyChecking=no" \
        "$SOURCE_DIR" "$SERVER_USER@$SERVER_IP:$DEST_DIR" >> ~/backup_scripts.log 2>&1

    # Status loggen
    if [ $? -eq 0 ]; then
        echo "Backup von .sh- und .py-Dateien erfolgreich am $(date)" >> ~/backup_scripts.log
        echo "Backup erfolgreich abgeschlossen."
    else
        echo "Backup von .sh- und .py-Dateien fehlgeschlagen am $(date)" >> ~/backup_scripts.log
        echo "Backup fehlgeschlagen – siehe ~/backup_scripts.log für Details."
    fi
}

# ======================= SYSTEMBEREINIGUNG (aus cleanup.sh) =======================

cleanup_system() {
    # Prüfen, ob als Root ausgeführt
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[1;31mFehler: Systembereinigung benötigt Root-Rechte.\033[0m"
        echo "Bitte das Skript mit sudo ausführen: sudo $0"
        return 1
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
}

# ======================= SYSTEM MONITOR (original) =======================

system_monitor() {
    # Netzwerk initialisieren
    iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$iface" ]]; then
        rx_prev=$(</sys/class/net/"$iface"/statistics/rx_bytes)
        tx_prev=$(</sys/class/net/"$iface"/statistics/tx_bytes)
    else
        rx_prev=0; tx_prev=0
    fi

    cpu_load() {
        read -r _ user nice system idle iowait irq softirq _ < /proc/stat
        prev_total=$((user + nice + system + idle + iowait + irq + softirq))
        prev_idle=$idle
        sleep 1
        read -r _ user nice system idle iowait irq softirq _ < /proc/stat
        total=$((user + nice + system + idle + iowait + irq + softirq))
        idle=$idle
        ((diff_idle = idle - prev_idle))
        ((diff_total = total - prev_total))
        echo $((100 * (diff_total - diff_idle) / diff_total))
    }

    ram_info() {
        read -r _ total _ < <(grep '^MemTotal:' /proc/meminfo)
        read -r _ avail _ < <(grep '^MemAvailable:' /proc/meminfo)
        mem_used=$(( (total - avail) / 1024 ))
        mem_total=$((total / 1024))
        read -r _ swap_total _ < <(grep '^SwapTotal:' /proc/meminfo)
        read -r _ swap_free _ < <(grep '^SwapFree:' /proc/meminfo)
        swap_used=$(( (swap_total - swap_free) / 1024 ))
        echo "$mem_used $mem_total $swap_used"
    }

    # Temperatur aus sensors extrahieren (universell)
    get_temp_from_sensors() {
        local keyword="$1"
        local temp=""
        local sensors_out=$(sensors 2>/dev/null)
        local line=$(echo "$sensors_out" | grep -i "$keyword" | head -1)
        if [[ -n "$line" ]]; then
            temp=$(echo "$line" | grep -oP '[0-9]+[.,]?[0-9]*' | head -1)
            if [[ -n "$temp" ]]; then
                temp=$(echo "$temp" | tr ',' '.')
                if (( $(echo "$temp > 1000" | bc -l 2>/dev/null) )); then
                    temp=$(echo "$temp / 1000" | bc -l)
                fi
                temp=$(printf "%.0f" "$temp" 2>/dev/null)
                if [[ "$temp" =~ ^[0-9]+$ ]] && (( temp > 0 && temp < 100 )); then
                    echo "$temp"
                    return
                fi
            fi
        fi
        echo ""
    }

    # CPU-Temperatur
    cpu_temp() {
        local temp=""
        for key in "Tctl" "Package id 0" "CPUTIN" "Core 0" "CPU Temperature"; do
            temp=$(get_temp_from_sensors "$key")
            [[ -n "$temp" ]] && echo "$temp" && return
        done
        for t in /sys/class/thermal/thermal_zone*/temp; do
            [[ -f "$t" ]] || continue
            val=$(<"$t")
            (( val > 1000 )) && val=$((val / 1000))
            if (( val > 0 && val < 100 )); then
                echo "$val"
                return
            fi
        done
        echo "—"
    }

    # GPU-Temperatur
    gpu_temp() {
        if command -v nvidia-smi &>/dev/null; then
            t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
            if [[ -n "$t" ]] && [[ "$t" =~ ^[0-9]+$ ]] && (( t > 0 && t < 100 )); then
                echo "$t"
                return
            fi
        fi
        if command -v sensors &>/dev/null; then
            local amd_edge=$(sensors 2>/dev/null | awk '/amdgpu/ {flag=1} flag && /edge/ {print $2; exit}' | tr -d '+°C')
            if [[ -n "$amd_edge" ]]; then
                if (( $(echo "$amd_edge > 1000" | bc -l 2>/dev/null) )); then
                    amd_edge=$(echo "$amd_edge / 1000" | bc -l)
                fi
                amd_edge=$(printf "%.0f" "$amd_edge" 2>/dev/null)
                if [[ "$amd_edge" =~ ^[0-9]+$ ]] && (( amd_edge > 0 && amd_edge < 100 )); then
                    echo "$amd_edge"
                    return
                fi
            fi
            local edge=$(get_temp_from_sensors "edge")
            if [[ -n "$edge" ]]; then
                echo "$edge"
                return
            fi
            local temp1=$(get_temp_from_sensors "temp1")
            if [[ -n "$temp1" ]]; then
                echo "$temp1"
                return
            fi
        fi
        echo "—"
    }

    # GPU-Auslastung
    gpu_load() {
        if command -v nvidia-smi &>/dev/null; then
            g=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)
            if [[ -n "$g" ]] && [[ "$g" =~ ^[0-9]+$ ]]; then
                echo "$g"
                return
            fi
        fi
        if command -v radeontop &>/dev/null; then
            radeon_out=$(timeout 1.5 radeontop -d - -l 1 2>/dev/null)
            g=$(echo "$radeon_out" | grep -oP 'gpu\s+\K[0-9,\.]+' | head -1)
            if [[ -z "$g" ]]; then
                g=$(echo "$radeon_out" | grep -oP 'Grafik Pipeline\s+\K[0-9,]+' | head -1)
            fi
            if [[ -n "$g" ]]; then
                g_int=$(echo "$g" | tr ',' '.' | awk '{print int($1+0.5)}')
                [[ "$g_int" =~ ^[0-9]+$ ]] && echo "$g_int" && return
            fi
        fi
        echo "—"
    }

    # GPU-VRAM
    gpu_vram() {
        if command -v nvidia-smi &>/dev/null; then
            v=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{printf "%d/%dM",$1,$2}')
            [[ -n "$v" ]] && echo "$v" && return
        fi
        for card in /sys/class/drm/card*/device/mem_info_vram_used; do
            if [[ -f "$card" ]]; then
                vram_used=$(cat "$card")
                vram_total=$(cat "${card/mem_info_vram_used/mem_info_vram_total}")
                echo "$((vram_used/1024/1024))/$((vram_total/1024/1024))MiB"
                return
            fi
        done
        echo "—"
    }

    # Deutsche Uptime
    uptime_de() {
        local up=$(awk '{print int($1)}' /proc/uptime)
        local hours=$((up / 3600))
        local minutes=$(((up % 3600) / 60))
        if (( hours > 0 )); then
            echo "${hours} Std., ${minutes} Min."
        else
            echo "${minutes} Min."
        fi
    }

    tput civis
    while true; do
        clear
        printf "${O}┌─ Sys-Mon ─ $(date '+%H:%M:%S') ─ $(uptime_de) ─┐${NC}\n"

        # CPU
        cpu=$(cpu_load 2>/dev/null || echo "—")
        ctemp=$(cpu_temp)
        if [[ "$ctemp" =~ ^[0-9]+$ ]]; then
            (( ctemp > 90 )) && tc=$R
            (( ctemp > 75 )) && tc=$Y || tc=$G
        else
            tc=$NC; ctemp="—"
        fi
        printf "${O}│ CPU${NC} %6s%% Temp: ${tc}%3s°C${NC} ${O}│${NC}\n" "$cpu" "$ctemp"

        # GPU
        gpu=$(gpu_load)
        gtemp=$(gpu_temp)
        vram=$(gpu_vram)

        if [[ "$gtemp" =~ ^[0-9]+$ ]]; then
            (( gtemp > 90 )) && gtc=$R
            (( gtemp > 75 )) && gtc=$Y || gtc=$G
        else
            gtc=$NC; gtemp="—"
        fi

        printf "${O}│ GPU${NC} %3s%% Temp: ${gtc}%3s°C${NC} VRAM: %-10s ${O}│${NC}\n" "$gpu" "$gtemp" "$vram"

        # RAM + Swap
        read -r umem tmem uswap <<< $(ram_info)
        mem_percent=$(( umem * 100 / tmem ))
        printf "${O}│ RAM${NC} %5d/%-5d MiB (%2d%%) Swap %4d MiB ${O}│${NC}\n" "$umem" "$tmem" "$mem_percent" "$uswap"

        # Disk
        root=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3,$2,$5}')
        printf "${O}│ Disk /${NC} %-35s ${O}│${NC}\n" "$root"

        # Netzwerk
        if [[ -n "$iface" ]]; then
            rx_now=$(</sys/class/net/"$iface"/statistics/rx_bytes)
            tx_now=$(</sys/class/net/"$iface"/statistics/tx_bytes)
            rx_kb=$(( (rx_now - rx_prev) / 1024 ))
            tx_kb=$(( (tx_now - tx_prev) / 1024 ))
            rx_prev=$rx_now; tx_prev=$tx_now
            printf "${O}│ Net ${NC}%s ↓%6d ↑%6d KB/s ${O}│${NC}\n" "$iface" "$rx_kb" "$tx_kb"
        else
            printf "${O}│ Net${NC} offline ${O}│${NC}\n"
        fi

        # Top-Prozess
        read -r pid cmd cpuuse memuse _ < <(ps -eo pid,comm,%cpu,%mem --sort=-%cpu | awk 'NR==2')
        printf "${O}│ Top${NC} PID %-5s %-12s CPU %4s%% RAM %4s%% ${O}│${NC}\n" "$pid" "$cmd" "$cpuuse" "$memuse"

        printf "${O}└──────────────────────────────────────────────────────────┘${NC}\n"
        echo -e "${Y}Drücke 'q' um zum Hauptmenü zurückzukehren${NC}"

        read -t 2 -n 1 key
        [[ "$key" == "q" || "$key" == "Q" ]] && break
    done
    tput cnorm
}

# ======================= PROZESS MANAGER (original) =======================

process_manager() {
    while true; do
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu | awk 'NR<=20 {printf "%s\t%s\tCPU:%s%% RAM:%s%%\n", $1, $2, $3, $4}' > /tmp/procs.txt
        exec 3>&1
        choice=$(dialog --title " Prozess Manager " --menu "Wählen Sie eine PID:" 20 70 12 $(awk '{print $1 "\t" $2}' /tmp/procs.txt) 2>&1 1>&3)
        exec 3>&-
        [[ -z "$choice" ]] && break
        action=$(dialog --title "Aktion für PID $choice" --menu "Was tun?" 10 40 3 \
            "kill" "Beenden (SIGKILL)" \
            "stop" "Anhalten (SIGSTOP)" \
            "cont" "Fortsetzen (SIGCONT)" 2>&1)
        case $action in
            kill) kill -9 "$choice" 2>/dev/null ;;
            stop) kill -STOP "$choice" 2>/dev/null ;;
            cont) kill -CONT "$choice" 2>/dev/null ;;
        esac
        dialog --msgbox "Aktion '$action' auf PID $choice ausgeführt." 6 40
    done
}

# ======================= AUTOSTART MANAGER (original) =======================

autostart_manager() {
    local dir="$HOME/.config/autostart"
    mkdir -p "$dir"

    while true; do
        entries=()
        for f in "$dir"/*.desktop; do
            [[ -f "$f" ]] || continue
            name=$(grep -m1 '^Name=' "$f" | cut -d= -f2)
            [[ -z "$name" ]] && name=$(basename "$f" .desktop)
            entries+=("$name" "$f" "off")
        done

        if [[ ${#entries[@]} -eq 0 ]]; then
            dialog --msgbox "Keine Autostart-Einträge vorhanden." 6 40
        else
            exec 3>&1
            selected=$(dialog --title " Autostart Manager " \
                --checklist "Einträge zum LÖSCHEN auswählen (Leertaste):" \
                18 70 10 "${entries[@]}" 2>&1 1>&3)
            exec 3>&-
            if [[ -n "$selected" ]]; then
                dialog --yesno "Ausgewählte Einträge endgültig löschen?" 6 50
                if [[ $? -eq 0 ]]; then
                    IFS='"' read -ra names <<< "$selected"
                    for name in "${names[@]}"; do
                        for file in "$dir"/*.desktop; do
                            fname=$(grep -m1 '^Name=' "$file" | cut -d= -f2)
                            [[ -z "$fname" ]] && fname=$(basename "$file" .desktop)
                            if [[ "$fname" == "$name" ]]; then
                                rm -f "$file"
                                break
                            fi
                        done
                    done
                    dialog --msgbox "Markierte Einträge gelöscht." 6 40
                else
                    dialog --msgbox "Löschen abgebrochen." 6 40
                fi
            fi
        fi

        dialog --yesno "Neuen Autostart-Eintrag hinzufügen?" 6 50
        if [[ $? -eq 0 ]]; then
            name=$(dialog --inputbox "Name:" 8 40 3>&1 1>&2 2>&3)
            [[ -z "$name" ]] && continue
            cmd=$(dialog --inputbox "Befehl:" 8 40 3>&1 1>&2 2>&3)
            [[ -z "$cmd" ]] && continue
            comment=$(dialog --inputbox "Kommentar (optional):" 8 40 3>&1 1>&2 2>&3)
            cat > "$dir/${name// /_}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$cmd
Comment=$comment
X-GNOME-Autostart-enabled=true
EOF
            dialog --msgbox "Eintrag '$name' hinzugefügt." 6 40
        else
            break
        fi
    done
}

# ======================= NETZWERK INFO (original) =======================

network_info() {
    while true; do
        ip -br link | awk '{print $1 "\t" $2}' > /tmp/ifaces.txt
        exec 3>&1
        iface=$(dialog --title " Netzwerk " --menu "Interface wählen:" 15 50 5 $(cat /tmp/ifaces.txt) 2>&1 1>&3)
        exec 3>&-
        [[ -z "$iface" ]] && break
        ip -br addr show "$iface" > /tmp/iface_detail.txt
        dialog --title "Details für $iface" --textbox /tmp/iface_detail.txt 12 60
        if command -v iw &>/dev/null && iw dev 2>/dev/null | grep -q Interface; then
            dialog --yesno "WLAN-Scan durchführen?" 6 30
            if [[ $? -eq 0 ]]; then
                iw dev wlan0 scan | grep -E 'SSID:|signal:' | paste -d ' ' - - | awk '{print $2, $5}' > /tmp/wifi.txt
                dialog --title "Verfügbare WLANs" --textbox /tmp/wifi.txt 20 70
            fi
        fi
    done
}

# ======================= PAKET MONITOR (original) =======================

packet_monitor() {
    if ! command -v tcpdump &>/dev/null; then
        dialog --msgbox "tcpdump nicht installiert.\n\nInstallation: sudo pacman -S tcpdump" 8 50
        return
    fi
    if [[ $EUID -ne 0 ]]; then
        dialog --msgbox "Packet Monitor benötigt Root-Rechte.\nStarte mit sudo." 8 50
        return
    fi
    clear
    echo -e "${O}Live-Paketanalyse (tcpdump -i any -n -c 100) - STRG+C beendet${NC}"
    sudo tcpdump -i any -n -c 100 -l | while read line; do
        echo -e "\033[0;36m$(date '+%H:%M:%S')\033[0m $line"
    done
    echo -e "\n${G}Analyse beendet. Drücke Enter für Hauptmenü.${NC}"
    read
}

# ======================= HAUPTMENÜ (erweitert) =======================

while true; do
    choice=$(dialog --title "${O} Sys-Mon ${NC}" \
        --menu "Hauptmenü" 19 60 9 \
        1 "📊 System Monitor (GPU/CPU)" \
        2 "⚙️  Prozess Manager" \
        3 "🚀 Autostart Manager" \
        4 "🌐 Netzwerk Informationen" \
        5 "🔍 Packet Monitor" \
        6 "🔄 System aktualisieren" \
        7 "💾 Backup Scripts" \
        8 "🧹 Systembereinigung" \
        9 "❌ Beenden" \
        2>&1 >/dev/tty)

    case "$choice" in
        1) system_monitor ;;
        2) process_manager ;;
        3) autostart_manager ;;
        4) network_info ;;
        5) packet_monitor ;;
        6) clear
           update_system
           echo -e "\nDrücke Enter, um zurück zum Menü zu gelangen."
           read
           ;;
        7) clear
           backup_scripts
           echo -e "\nDrücke Enter, um zurück zum Menü zu gelangen."
           read
           ;;
        8) clear
           cleanup_system
           echo -e "\nDrücke Enter, um zurück zum Menü zu gelangen."
           read
           ;;
        9) break ;;
        *) break ;;
    esac
done

clear
echo -e "${O}Sys-Mon beendet. Auf Wiedersehen!${NC}"