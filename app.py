

from flask import Flask, render_template, request, jsonify
import subprocess
import os
import json

app = Flask(__name__)

def get_available_drives():
    """
    Détecte les disques branchés. Sur Windows, cela liste les lecteurs logiques.
    Sur le Pi, cette fonction utilisera 'lsblk' pour trouver les vrais disques USB.
    """
    drives = []
    if os.name == 'nt': # Si le système est Windows
        import string
        available_drives = [f'{d}:\\' for d in string.ascii_uppercase if os.path.exists(f'{d}:')]
        # On simule une sortie plus proche de ce qu'on aura sur Linux
        for i, drive_letter in enumerate(available_drives):
            drives.append({
                "name": f"/dev/sd{chr(97+i)}1",
                "label": f"Lecteur {drive_letter}",
                "size": "N/A"
            })
    else: # Pour Linux (Raspberry Pi)
        try:
            # Commande pour lister les périphériques de bloc en format JSON
            lsblk_cmd = ["lsblk", "-J", "-o", "NAME,SIZE,MOUNTPOINT,LABEL,PARTLABEL"]
            process = subprocess.run(lsblk_cmd, capture_output=True, text=True, check=True)
            devices = json.loads(process.stdout).get("blockdevices", [])
            # On filtre pour garder les partitions qui sont montées (ou peuvent l'être)
            for dev in devices:
                if dev.get("children"):
                    for part in dev.get("children", []):
                        if part.get("mountpoint") or not part.get("name", "").startswith("zram"):
                             drives.append({
                                "name": f"/dev/{part['name']}",
                                "label": part.get("label") or part.get("partlabel") or f"Partition {part['name']}",
                                "size": part.get("size", "N/A")
                            })
        except (FileNotFoundError, subprocess.CalledProcessError) as e:
            print(f"Erreur lors de l'exécution de lsblk: {e}")
            # Retourner des données fictives en cas d'erreur
            drives.append({"name": "/dev/sda1", "label": "Disque Fictif (erreur)", "size": "1TB"})
            
    return drives

@app.route('/')
def index():
    """Affiche la page de configuration principale."""
    # Ici, nous lirons les configurations actuelles pour les afficher (simulation)
    current_ssid = "Pi-Hotspot"
    
    drives = get_available_drives()
    return render_template('index.html', drives=drives, current_ssid=current_ssid)

@app.route('/save', methods=['POST'])
def save_settings():
    """Reçoit les données du formulaire et (plus tard) applique les changements."""
    wifi_ssid = request.form.get('wifi_ssid')
    wifi_password = request.form.get('wifi_password')
    drive_to_share = request.form.get('drive_to_share')
    share_password = request.form.get('share_password')

    print(f"SSID reçu : {wifi_ssid}")
    print(f"Mot de passe Wi-Fi : {'*' * len(wifi_password) if wifi_password else 'N/A'}")
    print(f"Disque à partager : {drive_to_share}")
    print(f"Mot de passe de partage : {'*' * len(share_password) if share_password else 'N/A'}")

    # --- Application des changements sur le Pi ---
    try:
        # Mise à jour du Wi-Fi (uniquement si les deux champs sont remplis)
        if wifi_ssid and wifi_password:
            print(f"Exécution du script de mise à jour Wi-Fi pour le SSID : {wifi_ssid}")
            result_wifi = subprocess.run(
                ["sudo", "bash", "scripts/update_wifi.sh", wifi_ssid, wifi_password],
                check=True, capture_output=True, text=True
            )
            print(f"Sortie du script Wi-Fi : {result_wifi.stdout}")

        # Mise à jour de Samba (uniquement si les deux champs sont remplis)
        if drive_to_share and share_password:
             print(f"Exécution du script de mise à jour Samba pour le disque : {drive_to_share}")
             result_samba = subprocess.run(
                ["sudo", "bash", "scripts/update_samba.sh", drive_to_share, share_password],
                check=True, capture_output=True, text=True
            )
             print(f"Sortie du script Samba : {result_samba.stdout}")
        
        return jsonify({"status": "success", "message": "Paramètres appliqués avec succès ! Les services sont en cours de redémarrage."}) 

    except subprocess.CalledProcessError as e:
        # Si un des scripts échoue, on log l'erreur et on la renvoie au client
        error_output = e.stderr
        print(f"ERREUR lors de l'exécution du script : {error_output}")
        return jsonify({"status": "error", "message": f"Une erreur est survenue :\n{error_output}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
