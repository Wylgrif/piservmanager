#!/bin/bash

# Script pour mettre à jour la configuration du partage de fichiers (Samba)
# À exécuter avec sudo

# Arguments attendus : <périphérique> <mot_de_passe_partage>
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <périphérique_à_partager> <mot_de_passe>"
    exit 1
fi

DEVICE_PATH=$1
SHARE_PASSWORD=$2
SHARE_USER="shareuser" # Nom de l'utilisateur dédié au partage
MOUNT_POINT="/mnt/usb_share" # Point de montage unique
SAMBA_CONF="/etc/samba/smb.conf"

# --- 1. Gestion de l'utilisateur pour le partage ---
echo "Configuration de l'utilisateur de partage..."
# Crée l'utilisateur s'il n'existe pas, sans dossier personnel, sans shell de login
id -u $SHARE_USER &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin $SHARE_USER

# Définit le mot de passe Samba pour cet utilisateur
echo -e "$SHARE_PASSWORD\n$SHARE_PASSWORD" | smbpasswd -s -a $SHARE_USER

echo "Utilisateur '$SHARE_USER' configuré."

# --- 2. Montage du disque ---
echo "Configuration du montage du disque..."
# Crée le dossier de montage s'il n'existe pas
mkdir -p $MOUNT_POINT

# Trouve l'UUID du périphérique pour un montage fiable
DEVICE_UUID=$(lsblk -no UUID $DEVICE_PATH)
if [ -z "$DEVICE_UUID" ]; then
    echo "Erreur : Impossible de trouver l'UUID pour $DEVICE_PATH."
    exit 1
fi

# Sauvegarde fstab et supprime les anciennes configurations pour ce point de montage
cp /etc/fstab /etc/fstab.bak
sed -i "#$MOUNT_POINT#d" /etc/fstab

# Ajoute la nouvelle entrée à fstab pour un montage automatique au démarrage
# L'option `nofail` empêche le Pi de bloquer au démarrage si le disque n'est pas branché
echo "UUID=$DEVICE_UUID $MOUNT_POINT auto defaults,nofail,uid=$SHARE_USER,gid=users,umask=007 0 2" >> /etc/fstab

# Monte le disque
umount $MOUNT_POINT &>/dev/null # D'abord on démonte au cas où
mount $MOUNT_POINT

if ! mountpoint -q $MOUNT_POINT; then
    echo "Erreur : Le montage de $DEVICE_PATH à $MOUNT_POINT a échoué."
    exit 1
fi

echo "Disque $DEVICE_PATH monté sur $MOUNT_POINT."

# --- 3. Configuration de Samba ---
echo "Génération de la configuration Samba..."

# Sauvegarde de la configuration existante
mv $SAMBA_CONF "$SAMBA_CONF.bak_$(date +%F)"

# Création de la nouvelle configuration
cat > $SAMBA_CONF << EOL
[global]
   workgroup = WORKGROUP
   server string = %h server (Samba)
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter*new*password:* %n\n *Retype*new*password:* %n\n *password*updated*successfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = yes

[PiShare]
   comment = Disque USB partagé
   path = $MOUNT_POINT
   browseable = yes
   writeable = yes
   read only = no
   create mask = 0775
   directory mask = 0775
   valid users = $SHARE_USER
EOL

echo "Fichier de configuration Samba créé."

# --- 4. Redémarrage des services Samba ---
echo "Redémarrage des services Samba..."
systemctl restart smbd
systemctl restart nmbd

echo "Configuration du partage de fichiers terminée !"
exit 0
