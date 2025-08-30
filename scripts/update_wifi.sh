#!/bin/bash

# Script pour mettre à jour la configuration du hotspot Wi-Fi (hostapd)
# À exécuter avec sudo

# Vérifie qu'on a bien les 2 arguments nécessaires
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ssid> <mot_de_passe>"
    exit 1
fi

SSID="$1"
PASSWORD="$2"
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"

# Validation simple
if [ -z "$SSID" ]; then
    echo "Erreur : Le SSID ne peut pas être vide."
    exit 1
fi

if [ ${#PASSWORD} -lt 8 ]; then
    echo "Erreur : Le mot de passe doit contenir au moins 8 caractères."
    exit 1
fi

echo "Configuration du hotspot Wi-Fi..."
echo "SSID : $SSID"
echo "Mot de passe : [caché]"

# Création du nouveau fichier de configuration pour hostapd
# Ce fichier est très basique et peut être enrichi (ex: choix du canal)
cat > $HOSTAPD_CONF << EOL
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOL

echo "Fichier de configuration hostapd créé à $HOSTAPD_CONF"

# Redémarrage du service pour appliquer les changements
echo "Redémarrage du service hostapd..."
systemctl restart hostapd

echo "La configuration Wi-Fi a été mise à jour."
exit 0
