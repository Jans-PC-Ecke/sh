#!/bin/bash

SERVER_USER="dieter2"  
SERVER_IP="192.168.178.22"  
PASSWORD="12041993"     # SSH-Passwort 
SOURCE_DIR="/home/"  # Quellordner: /home und alle Unterordner
DEST_DIR="/home/dieter2/backup-scripts/"  # Ziel auf Server 

# Rsync: Nur .sh- und .py-Dateien und ihre Ordner, inkrementell, leere Ordner überspringen
SSHPASS="$PASSWORD" sshpass -e rsync -avz --progress --prune-empty-dirs --include='*.sh' --include='*.py' --include='*/' --exclude='*' -e "ssh -o StrictHostKeyChecking=no" "$SOURCE_DIR" "$SERVER_USER@$SERVER_IP:$DEST_DIR" >> ~/backup_scripts.log 2>&1

# Status loggen
if [ $? -eq 0 ]; then
    echo "Backup von .sh- und .py-Dateien erfolgreich am $(date)" >> ~/backup_scripts.log
else
    echo "Backup von .sh- und .py-Dateien fehlgeschlagen am $(date)" >> ~/backup_scripts.log
fi