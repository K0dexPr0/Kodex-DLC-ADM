#!/bin/bash
# ==================================================
# KodexDev VPS Management System
# Style: Whiptail UI
# Author: Joel DLC
# ==================================================

### COLORES
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
WHITE="\e[97m"
RESET="\e[0m"

### VARIABLES
XRAY_CONFIG="/etc/xray/config.json"
SYSCTL_FILE="/etc/sysctl.d/99-kodexdev.conf"
BACKUP_DIR="/root/kodexdev_backup"
SCRIPT_PATH="/usr/local/bin/kodexdev"
SCRIPT_URL="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"

mkdir -p $BACKUP_DIR

### DEPENDENCIAS
install_deps() {
  apt update -y
  apt install -y curl jq socat vnstat net-tools lsb-release ufw cron whiptail
}

### INFO SISTEMA
system_info() {
  OS=$(lsb_release -ds | tr -d '"')
  KERNEL=$(uname -r)
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2)
  IP=$(curl -s ifconfig.me)
  UPTIME=$(uptime -p)
}

### BANNER
banner() {
  system_info
  clear
  echo -e "${RED}"
  echo "╔════════════════════════════════════════════╗"
  echo "║        KodexDev VPS Management System      ║"
  echo "║              Author: Joel_DLC              ║"
  echo "╠════════════════════════════════════════════╣"
  echo -e "║ OS      : ${WHITE}$OS"
  echo -e "║ Kernel  : ${WHITE}$KERNEL"
  echo -e "║ RAM     : ${WHITE}${RAM} MB"
  echo -e "║ CPU     : ${WHITE}$CPU"
  echo -e "║ IP      : ${WHITE}$IP"
  echo -e "║ Uptime  : ${WHITE}$UPTIME"
  echo "╚════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

pause(){ read -p "Presiona ENTER para continuar..."; }

# ==================================================
# OPTIMIZACIÓN VPS
# ==================================================
optimize_menu() {
while true; do
opt=$(whiptail --title "Optimización VPS" --menu "" 18 70 6 \
"1" "Perfil Básico (Seguro)" \
"2" "Perfil Baja Latencia / Gaming" \
"3" "Perfil VPN / Streaming" \
"4" "Ver configuración actual" \
"5" "Restaurar valores por defecto" \
"0" "Volver" 3>&1 1>&2 2>&3)

case $opt in
1)
cat <<EOF > $SYSCTL_FILE
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
EOF
sysctl --system
pause
;;
2)
cat <<EOF > $SYSCTL_FILE
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
EOF
sysctl --system
pause
;;
3)
cat <<EOF > $SYSCTL_FILE
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=1000000
EOF
sysctl --system
pause
;;
4)
sysctl -a | grep tcp_
pause
;;
5)
rm -f $SYSCTL_FILE
sysctl --system
pause
;;
0) break ;;
esac
done
}

# ==================================================
# XRAY
# ==================================================
xray_menu() {
while true; do
opt=$(whiptail --title "Gestión Xray" --menu "" 18 70 7 \
"1" "Instalar / Verificar Xray" \
"2" "Estado del servicio" \
"3" "Reiniciar Xray" \
"4" "Mostrar ruta config.json" \
"5" "Exportar links VLESS / VMESS" \
"0" "Volver" 3>&1 1>&2 2>&3)

case $opt in
1)
command -v xray >/dev/null || bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
systemctl enable xray && systemctl start xray
pause
;;
2)
systemctl status xray --no-pager
pause
;;
3)
systemctl restart xray
pause
;;
4)
echo -e "${GREEN}$XRAY_CONFIG${RESET}"
pause
;;
5)
jq -r '.inbounds[] | select(.protocol=="vless") |
"vless://\(.settings.clients[0].id)@DOMAIN:\(.port)?type=ws#VLESS-KodexDev"' $XRAY_CONFIG 2>/dev/null
jq -r '.inbounds[] | select(.protocol=="vmess") |
{v:"2",ps:"VMESS-KodexDev",add:"DOMAIN",port:(.port|tostring),id:.settings.clients[0].id,aid:"0",net:"ws",type:"none",host:"",path:"/",tls:"tls"} | @base64 | "vmess://"+.' $XRAY_CONFIG 2>/dev/null
pause
;;
0) break ;;
esac
done
}

# ==================================================
# PROTOCOLOS & PUERTOS
# ==================================================
protocol_menu() {
while true; do
opt=$(whiptail --title "Protocolos & Puertos" --menu "" 18 70 8 \
"1" "Ver protocolos activos" \
"2" "Ver puertos activos" \
"3" "Abrir puerto" \
"4" "Cerrar puerto" \
"5" "Instalar Dropbear" \
"6" "Instalar BadVPN" \
"0" "Volver" 3>&1 1>&2 2>&3)

case $opt in
1)
jq '.inbounds[].protocol' $XRAY_CONFIG 2>/dev/null
pause
;;
2)
ss -tulnp
pause
;;
3)
read -p "Puerto a abrir: " p
ufw allow $p
pause
;;
4)
read -p "Puerto a cerrar: " p
ufw delete allow $p
pause
;;
5)
apt install -y dropbear
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
systemctl restart dropbear
pause
;;
6)
echo "Instala BadVPN manualmente según tu uso."
pause
;;
0) break ;;
esac
done
}

# ==================================================
# CERTIFICADOS & DOMINIO
# ==================================================
cert_menu() {
opt=$(whiptail --title "Certificados & Dominio" --menu "" 15 70 4 \
"1" "Tengo dominio (Let's Encrypt)" \
"2" "No tengo dominio (DuckDNS)" \
"0" "Volver" 3>&1 1>&2 2>&3)

case $opt in
1)
read -p "Dominio: " DOM
apt install -y certbot
certbot certonly --standalone -d $DOM
pause
;;
2)
read -p "Subdominio DuckDNS: " SUB
read -p "Token DuckDNS: " TOKEN
curl https://get.acme.sh | sh
export DuckDNS_Token="$TOKEN"
~/.acme.sh/acme.sh --issue --dns dns_duckdns -d $SUB.duckdns.org
pause
;;
esac
}

# ==================================================
# ESTADÍSTICAS
# ==================================================
traffic_menu() {
vnstat
pause
}

# ==================================================
# UPDATE
# ==================================================
update_script() {
curl -fsSL $SCRIPT_URL -o $SCRIPT_PATH
chmod +x $SCRIPT_PATH
echo "Actualizado. Reinicia."
exit
}

# ==================================================
# MENU PRINCIPAL
# ==================================================
install_deps
while true; do
banner
opt=$(whiptail --title "KodexDev – Joel_DLC | VPS ADM" --menu "" 20 70 8 \
"1" "Optimización VPS" \
"2" "Gestión Xray" \
"3" "Protocolos & Puertos" \
"4" "Certificados & Dominio" \
"5" "Estadísticas de tráfico" \
"6" "Actualizar Script" \
"0" "Salir" 3>&1 1>&2 2>&3)

case $opt in
1) optimize_menu ;;
2) xray_menu ;;
3) protocol_menu ;;
4) cert_menu ;;
5) traffic_menu ;;
6) update_script ;;
0) clear; exit ;;
esac
done
