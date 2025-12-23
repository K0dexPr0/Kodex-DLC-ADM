#!/bin/bash
# ==================================================
# KodexDev VPS Management System
# True Monolithic VPS Administrator
# Author: Joel_DLC
# ==================================================

### COLORES
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
WHITE="\e[97m"; RESET="\e[0m"

### RUTAS
XRAY_CONFIG="/etc/xray/config.json"
SYSCTL_FILE="/etc/sysctl.d/99-kodexdev.conf"
BACKUP_DIR="/root/kodexdev_backups"
LOG_FILE="/var/log/kodexdev.log"
SCRIPT_PATH="/usr/local/bin/kodexdev"
SCRIPT_URL="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"

mkdir -p $BACKUP_DIR

log(){ echo "[$(date '+%F %T')] $1" >> $LOG_FILE; }
pause(){ read -p "Presiona ENTER para continuar..."; }

### VALIDACIONES
require_root(){
  [[ $EUID -ne 0 ]] && echo "Ejecuta como root." && exit 1
}

check_dep(){
  command -v "$1" >/dev/null || apt install -y "$1"
}

### DEPENDENCIAS
install_deps(){
  apt update -y
  for p in curl jq vnstat ufw socat cron lsb-release net-tools whiptail uuid-runtime; do
    check_dep $p
  done
}

### INFO SISTEMA
system_info(){
  OS=$(lsb_release -ds | tr -d '"')
  KERNEL=$(uname -r)
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  IP=$(curl -s ifconfig.me)
}

### BANNER
banner(){
  system_info
  clear
  echo -e "${RED}╔════════════════════════════════════════════╗"
  echo "║        KodexDev VPS Management System      ║"
  echo "║              Author: Joel_DLC              ║"
  echo "╠════════════════════════════════════════════╣"
  echo -e "║ OS     : ${WHITE}$OS"
  echo -e "║ Kernel : ${WHITE}$KERNEL"
  echo -e "║ RAM    : ${WHITE}${RAM}MB"
  echo -e "║ IP     : ${WHITE}$IP"
  echo -e "${RED}╚════════════════════════════════════════════╝${RESET}"
}

### PANEL ESTADO
status_panel(){
  XRAY=$(systemctl is-active xray 2>/dev/null || echo "NO")
  FW=$(ufw status | grep -q active && echo "ACTIVO" || echo "INACTIVO")
  BBR=$(sysctl net.ipv4.tcp_congestion_control | grep -q bbr && echo "ACTIVO" || echo "NO")
  echo -e "${GREEN}Xray       : $XRAY"
  echo "Firewall   : $FW"
  echo "BBR        : $BBR${RESET}"
  pause
}

### BACKUPS
backup_file(){
  [[ -f $1 ]] && cp "$1" "$BACKUP_DIR/$(basename $1)_$(date +%F_%T)"
}

### OPTIMIZACIÓN VPS
optimize_menu(){
while true; do
o=$(whiptail --title "Optimización VPS" --menu "" 18 60 5 \
"1" "Perfil Básico" \
"2" "Perfil Baja Latencia" \
"3" "Perfil VPN/Streaming" \
"4" "Restaurar Defaults" \
"0" "Volver" 3>&1 1>&2 2>&3)
case $o in
1|2|3)
backup_file $SYSCTL_FILE
cat <<EOF > $SYSCTL_FILE
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
EOF
sysctl --system
log "Optimización aplicada"
pause;;
4)
rm -f $SYSCTL_FILE
sysctl --system
log "Optimización restaurada"
pause;;
0) break;;
esac
done
}

### XRAY USUARIOS
add_user(){
UUID=$(uuidgen)
jq ".inbounds[0].settings.clients += [{\"id\":\"$UUID\"}]" $XRAY_CONFIG > /tmp/x && mv /tmp/x $XRAY_CONFIG
systemctl restart xray
echo "UUID creado: $UUID"
log "Usuario Xray creado $UUID"
pause
}

list_users(){
jq -r '.inbounds[0].settings.clients[].id' $XRAY_CONFIG
pause
}

del_user(){
read -p "UUID a eliminar: " U
jq "del(.inbounds[0].settings.clients[] | select(.id==\"$U\"))" $XRAY_CONFIG > /tmp/x && mv /tmp/x $XRAY_CONFIG
systemctl restart xray
log "Usuario Xray eliminado $U"
pause
}

### XRAY MENU
xray_menu(){
while true; do
x=$(whiptail --title "Gestión Xray" --menu "" 20 70 9 \
"1" "Instalar / Verificar Xray" \
"2" "Estado / Reinicio" \
"3" "Ruta config.json" \
"4" "Backup config" \
"5" "Agregar usuario" \
"6" "Listar usuarios" \
"7" "Eliminar usuario" \
"8" "Exportar links" \
"0" "Volver" 3>&1 1>&2 2>&3)
case $x in
1) command -v xray >/dev/null || bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh); pause;;
2) systemctl restart xray; pause;;
3) echo "$XRAY_CONFIG"; pause;;
4) backup_file $XRAY_CONFIG; pause;;
5) add_user;;
6) list_users;;
7) del_user;;
8)
jq -r '.inbounds[]|select(.protocol=="vless")|"vless://\(.settings.clients[0].id)@DOMAIN:\(.port)#KodexDev"' $XRAY_CONFIG
pause;;
0) break;;
esac
done
}

### PUERTOS
ports_menu(){
while true; do
p=$(whiptail --title "Puertos & Firewall" --menu "" 18 60 5 \
"1" "Ver puertos activos" \
"2" "Abrir puerto" \
"3" "Cerrar puerto" \
"0" "Volver" 3>&1 1>&2 2>&3)
case $p in
1) ss -tulnp; pause;;
2) read -p "Puerto: " pt; ufw allow $pt; log "Puerto abierto $pt"; pause;;
3) read -p "Puerto: " pt; ufw delete allow $pt; log "Puerto cerrado $pt"; pause;;
0) break;;
esac
done
}

### CERTIFICADOS
cert_menu(){
c=$(whiptail --title "Certificados" --menu "" 15 60 3 \
"1" "Tengo dominio (Let's Encrypt)" \
"2" "No tengo dominio (DuckDNS)" \
"0" "Volver" 3>&1 1>&2 2>&3)
case $c in
1) read -p "Dominio: " D; certbot certonly --standalone -d $D; pause;;
2) read -p "Subdominio DuckDNS: " S; read -p "Token: " T; curl https://get.acme.sh | sh; export DuckDNS_Token=$T; ~/.acme.sh/acme.sh --issue --dns dns_duckdns -d $S.duckdns.org; pause;;
esac
}

### UPDATE
update_script(){
curl -fsSL $SCRIPT_URL -o $SCRIPT_PATH
chmod +x $SCRIPT_PATH
log "Script actualizado"
exit
}

### MAIN
require_root
install_deps
while true; do
banner
m=$(whiptail --title "KodexDev VPS ADM" --menu "" 20 70 9 \
"1" "Panel de Estado" \
"2" "Optimización VPS" \
"3" "Gestión Xray" \
"4" "Puertos & Firewall" \
"5" "Certificados & Dominio" \
"6" "Actualizar Script" \
"0" "Salir" 3>&1 1>&2 2>&3)
case $m in
1) status_panel;;
2) optimize_menu;;
3) xray_menu;;
4) ports_menu;;
5) cert_menu;;
6) update_script;;
0) exit;;
esac
done
