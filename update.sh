#!/bin/bash
clear

# Beende das Skript sofort, wenn ein Befehl fehlschlägt
set -e

# Funktion für arch-basierte Systeme
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

# Funktion für debian-basierte Systeme
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

# Teste, ob der Rechner arch-based ist
if [ -d /etc/pacman.d ]; then
    update_arch
fi

# Teste, ob der Rechner debian-basiert ist 
if [ -d /etc/apt ]; then
    update_debian
fi