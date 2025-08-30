# Panneau de Contrôle pour Serveur Raspberry Pi

Ce projet transforme un Raspberry Pi 4 en un serveur multifonction :
- Hotspot Wi-Fi configurable.
- Serveur de fichiers (NAS) partageant un disque USB sur le réseau.
- Interface web simple pour gérer les configurations.

---

## 1. Prérequis Matériels et Logiciels

### Matériel
- Raspberry Pi 4
- Carte SD avec Raspberry Pi OS (recommandé : version "Lite" 64-bit)
- Une alimentation USB-C adéquate
- Un disque dur ou une clé USB

### Logiciels (à installer sur le Pi)
- `python3` et `python3-pip`
- `git` (pour cloner le projet)
- Les services : `hostapd`, `dnsmasq`, `samba`

---

## 2. Installation sur le Raspberry Pi

Connectez-vous au Pi en SSH ou ouvrez un terminal.

### Étape A : Mise à jour du système
```bash
sudo apt update && sudo apt upgrade -y
```

### Étape B : Installation des services
```bash
sudo apt install hostapd dnsmasq samba -y
```

### Étape C : Installation des dépendances Python
```bash
sudo apt install python3-pip -y
pip3 install Flask
```

### Étape D : Récupération des fichiers du projet
Vous devrez transférer le dossier `pi-server-manager` sur votre Pi (par exemple, avec `scp` ou une clé USB). Placez-le dans le dossier personnel de l'utilisateur (ex: `/home/pi`).

---

## 3. Configuration Initiale (Crucial)

Ces étapes configurent le Pi pour qu'il agisse comme un point d'accès.

### Étape A : Configurer une IP statique pour l'interface Wi-Fi
1.  Ouvrez le fichier de configuration de `dhcpcd` :
    ```bash
    sudo nano /etc/dhcpcd.conf
    ```
2.  Ajoutez ces lignes à la **fin** du fichier pour l'interface `wlan0` :
    ```
    interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
    ```
3.  Enregistrez (`Ctrl+O`) et quittez (`Ctrl+X`).

### Étape B : Configurer `dnsmasq` (serveur DHCP)
1.  Renommez le fichier de configuration original pour en créer un nouveau :
    ```bash
    sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
    sudo nano /etc/dnsmasq.conf
    ```
2.  Ajoutez le contenu suivant :
    ```
    interface=wlan0
    dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
    domain=wlan
    address=/gw.wlan/192.168.4.1
    ```
3.  Enregistrez et quittez.

### Étape C : Activer les services
```bash
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
```

### Étape D : Donner les permissions à l'application web
L'application a besoin de redémarrer des services système. Nous allons l'autoriser à le faire sans mot de passe de manière sécurisée.

1.  Créez un nouveau fichier de configuration pour `sudo` :
    ```bash
    sudo nano /etc/sudoers.d/010_pi-server-manager
    ```
2.  Ajoutez la ligne suivante. Remplacez `pi` par votre nom d'utilisateur si différent.
    ```
    # Autorise l'utilisateur 'pi' à exécuter les scripts de mise à jour
    pi ALL=(ALL) NOPASSWD: /bin/bash /home/pi/pi-server-manager/scripts/update_wifi.sh, /bin/bash /home/pi/pi-server-manager/scripts/update_samba.sh
    ```
3.  Enregistrez et quittez.

---

## 4. Lancement du Serveur Web

1.  Naviguez dans le dossier du projet :
    ```bash
    cd /home/pi/pi-server-manager
    ```
2.  Lancez l'application :
    ```bash
    python3 app.py
    ```

L'application est maintenant accessible à l'adresse `http://192.168.4.1:5000` depuis un appareil connecté au hotspot Wi-Fi du Pi.

### Lancement automatique au démarrage (Recommandé)

Pour que le serveur web se lance tout seul au démarrage du Pi, nous allons créer un service `systemd`.

1.  Créez le fichier de service :
    ```bash
    sudo nano /etc/systemd/system/pi-manager.service
    ```
2.  Collez-y le contenu suivant (vérifiez que les chemins correspondent) :
    ```ini
    [Unit]
    Description=Serveur web pour la gestion du Pi
    After=network.target

    [Service]
    User=pi
    Group=www-data
    WorkingDirectory=/home/pi/pi-server-manager
    ExecStart=/usr/bin/python3 app.py
    Restart=always

    [Install]
    WantedBy=multi-user.target
    ```
3.  Activez le service :
    ```bash
    sudo systemctl enable pi-manager.service
    sudo systemctl start pi-manager.service
    ```

---

## 5. Prochaines Étapes

Les scripts `update_wifi.sh` et `update_samba.sh` ne sont pas encore créés. Ils contiendront la logique pour écrire dans les fichiers de configuration `/etc/hostapd/hostapd.conf` et `/etc/samba/smb.conf`.
