#!/bin/bash

# =============================================================================
# Script d'installation pour le Panneau de Contrôle du Serveur Raspberry Pi
# =============================================================================

# S'assurer que le script est exécuté avec les droits sudo
if [ "$EUID" -ne 0 ]; then 
  echo "ERREUR : Veuillez lancer ce script avec sudo." 
  echo "Usage: sudo ./setup.sh"
  exit 1
fi

# Récupérer le nom de l'utilisateur qui a lancé sudo (pas root)
if [ -z "$SUDO_USER" ]; then
    echo "ERREUR : Impossible de déterminer l'utilisateur. Utilisez sudo."
    exit 1
fi

# Le chemin absolu du dossier du projet
PROJECT_DIR=$(pwd)

echo "--- Début de l'installation du serveur Pi ---"

# --- 1. Installation des dépendances ---
echo "[1/5] Installation des paquets système et Python..."
apt update && apt upgrade -y
apt install -y hostapd dnsmasq samba python3-pip git
if [ $? -ne 0 ]; then echo "ERREUR: L'installation des paquets a échoué." >&2; exit 1; fi

apt install -y python3-flask
if [ $? -ne 0 ]; then echo "ERREUR: L'installation de Flask a échoué." >&2; exit 1; fi

echo "--- Paquets installés avec succès."

# --- 2. Configuration du réseau ---
echo "[2/5] Configuration du réseau (IP statique et DHCP)..."

# Configuration de l'IP statique pour wlan0
CONFIG_DHCPSCD="/etc/dhcpcd.conf"
if ! grep -q "interface wlan0" "$CONFIG_DHCPSCD"; then
    echo -e "\n# Configuration pour le Hotspot\ninterface wlan0\nstatic ip_address=192.168.4.1/24\nnohook wpa_supplicant" >> "$CONFIG_DHCPSCD"
fi

# Configuration de dnsmasq
CONFIG_DNSMASQ="/etc/dnsmasq.conf"
mv "$CONFIG_DNSMASQ" "${CONFIG_DNSMASQ}.orig" 2>/dev/null
cat > "$CONFIG_DNSMASQ" << EOL
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=wlan
address=/gw.wlan/192.168.4.1
EOL

# Activer les services réseau
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

echo "--- Réseau configuré."

# --- 3. Configuration des permissions Sudo ---
echo "[3/5] Configuration des permissions sudo pour l'application..."

CONFIG_SUDOERS="/etc/sudoers.d/010_pi-server-manager"

# Donne à l'utilisateur le droit d'exécuter les scripts de mise à jour sans mot de passe
# Utilise des chemins absolus pour la sécurité
cat > "$CONFIG_SUDOERS" << EOL
# Autorise l'utilisateur '$SUDO_USER' à gérer les services du Pi via l'app web
$SUDO_USER ALL=(ALL) NOPASSWD: /bin/bash $PROJECT_DIR/scripts/update_wifi.sh, /bin/bash $PROJECT_DIR/scripts/update_samba.sh
EOL

chmod 0440 "$CONFIG_SUDOERS"

echo "--- Permissions configurées."

# --- 4. Création du service de l'application web ---
echo "[4/5] Création du service pour le lancement automatique de l'application..."

CONFIG_SYSTEMD="/etc/systemd/system/pi-manager.service"

cat > "$CONFIG_SYSTEMD" << EOL
[Unit]
Description=Serveur web pour la gestion du Pi
After=network.target

[Service]
User=$SUDO_USER
Group=www-data
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Activer et démarrer le service
systemctl daemon-reload
systemctl enable pi-manager.service
systemctl start pi-manager.service

echo "--- Service de l'application créé et démarré."

# --- 5. Finalisation ---
echo "[5/5] Finalisation de l'installation..."

# S'assurer que les scripts sont exécutables
chmod +x $PROJECT_DIR/scripts/*.sh

echo -e "\n\n=================================================="
echo "  Installation terminée avec succès !"
echo "=================================================="
echo "L'application web est en cours d'exécution."
echo "Pour y accéder, connectez-vous au hotspot Wi-Fi du Pi (le nom par défaut est 'Pi-Hotspot') et ouvrez un navigateur à l'adresse :"
echo "\n    http://192.168.4.1:5000\n"
echo "Il est recommandé de redémarrer le Raspberry Pi pour s'assurer que tous les services démarrent correctement."
echo "Commande de redémarrage : sudo reboot"
