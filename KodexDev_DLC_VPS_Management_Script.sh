#!/bin/bash

# =====================================================
# KodexDev - Joel_DLC | VPS Management Script
# XRAY | Dropbear | BadVPN | Optimization
# =====================================================

# ===== PROTECCIONES =====
[[ $EUID -ne 0 ]] && echo "Ejecuta como root" && exit 1
exec 9>/var/run/kodexdev.lock
flock -n 9 || exit 1

# ===== VARIABLES =====
XRAY_CONFIG="/usr/local/etc/xray/config.json"
BACKUP_DIR="/root/kodex_backups"
LOG="/var/log/kodexdev.log"
mkdir -p "$BACKUP_DIR"

# ===== COLORES =====
red="\e[1;31m"
green="\e[1;32m"
yellow="\e[1;33m"
blue="\e[1;34m"
cyan="\e[1;36m"
reset="\e[0m"

# ===== FUNCIONES BASE =====
log() {
  echo "$(date '+%F %T') - $1" >> "$LOG"
}

banner() {
clear
echo -e "${cyan}"
echo " ╔══════════════════════════════════════╗"
echo " ║        KodexDev - Joel_DLC            ║"
echo " ║   XRAY | VPS | Network Tools          ║"
echo " ╚══════════════════════════════════════╝"
echo -e "${reset}"
}

pause() {
read -p "Presiona ENTER para continuar..."
}

# =====================================================
# INSTALACION XRAY
# =====================================================
instalar_xray() {
banner
echo -e "${yellow}Instalando XRAY...${reset}"
sleep 1

apt update -y
apt install curl jq -y

bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

mkdir -p /usr/local/etc/xray

UUID=$(cat /proc/sys/kernel/random/uuid)

cat > "$XRAY_CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID", "level": 0 }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/kodex" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
EOF

systemctl enable xray
systemctl restart xray

log "XRAY instalado"
echo -e "${green}XRAY instalado correctamente${reset}"
echo "UUID inicial: $UUID"
pause
}

# =====================================================
# DROPBEAR
# =====================================================
instalar_dropbear() {
banner
echo -e "${yellow}Instalando Dropbear...${reset}"

apt install dropbear -y

sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=222/' /etc/default/dropbear
sed -i 's|DROPBEAR_EXTRA_ARGS=.*|DROPBEAR_EXTRA_ARGS="-p 222 -p 80 -p 8080"|' /etc/default/dropbear

systemctl restart dropbear
log "Dropbear instalado"

echo -e "${green}Dropbear activo en puertos 222, 80, 8080${reset}"
pause
}

# =====================================================
# BADVPN
# =====================================================
instalar_badvpn() {
banner
echo -e "${yellow}Instalando BadVPN...${reset}"

apt install wget screen -y

wget -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw

cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable badvpn
systemctl start badvpn

log "BadVPN instalado"
echo -e "${green}BadVPN activo en puerto 7300${reset}"
pause
}

# =====================================================
# ESTADO SERVICIOS
# =====================================================
estado_servicios() {
banner
echo -e "${yellow}Estado de servicios${reset}\n"

for svc in xray dropbear badvpn; do
  if systemctl is-active --quiet $svc; then
    echo -e "$svc : ${green}ONLINE${reset}"
  else
    echo -e "$svc : ${red}OFFLINE${reset}"
  fi
done

pause
}

# =====================================================
# REINICIO SERVICIOS
# =====================================================
reiniciar_servicios() {
banner
echo "1) XRAY"
echo "2) Dropbear"
echo "3) BadVPN"
read -p "Opcion: " r

case $r in
 1) systemctl restart xray ;;
 2) systemctl restart dropbear ;;
 3) systemctl restart badvpn ;;
esac

pause
}

# =====================================================
# OPTIMIZACION
# =====================================================
perfil_opt() {
banner
echo "1) LOW"
echo "2) BALANCED"
echo "3) AGGRESSIVE"
read -p "Perfil: " p

case $p in
 1)
  sysctl -w net.ipv4.tcp_fastopen=3
  ;;
 2)
  sysctl -w net.core.default_qdisc=fq
  sysctl -w net.ipv4.tcp_congestion_control=bbr
  ;;
 3)
  sysctl -w net.ipv4.tcp_tw_reuse=1
  sysctl -w net.ipv4.tcp_fin_timeout=10
  ;;
esac

log "Perfil optimizacion aplicado"
pause
}

# =====================================================
# LIMPIEZA
# =====================================================
limpieza_sistema() {
banner
apt autoremove -y
apt clean
journalctl --vacuum-time=7d
log "Limpieza ejecutada"
pause
}

# =====================================================
# GESTION XRAY
# =====================================================
backup_xray() {
cp "$XRAY_CONFIG" "$BACKUP_DIR/config_$(date +%F_%H-%M).json"
}

menu_xray() {
banner
echo "1) Agregar usuario"
echo "2) Eliminar usuario"
echo "3) Exportar links"
echo "4) Volver"
read -p "Opcion: " x

case $x in
 1) agregar_usuario_xray ;;
 2) eliminar_usuario_xray ;;
 3) exportar_links ;;
esac
}

agregar_usuario_xray() {
backup_xray
UUID=$(cat /proc/sys/kernel/random/uuid)

jq ".inbounds[0].settings.clients += [{\"id\":\"$UUID\",\"level\":0}]" \
"$XRAY_CONFIG" > /tmp/xray.tmp && mv /tmp/xray.tmp "$XRAY_CONFIG"

systemctl restart xray
echo "UUID agregado: $UUID"
pause
}

eliminar_usuario_xray() {
backup_xray
jq -r '.inbounds[0].settings.clients[].id' "$XRAY_CONFIG"
read -p "UUID a eliminar: " DEL

jq "del(.inbounds[0].settings.clients[] | select(.id==\"$DEL\"))" \
"$XRAY_CONFIG" > /tmp/xray.tmp && mv /tmp/xray.tmp "$XRAY_CONFIG"

systemctl restart xray
pause
}

exportar_links() {
banner
IP=$(curl -s ifconfig.me)
PORT=$(jq -r '.inbounds[0].port' "$XRAY_CONFIG")
PATH=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' "$XRAY_CONFIG")

jq -r '.inbounds[0].settings.clients[].id' "$XRAY_CONFIG" | while read id; do
 echo "vless://$id@$IP:$PORT?encryption=none&type=ws&path=$PATH#KodexDev"
done

pause
}

# =====================================================
# INFO SISTEMA
# =====================================================
info_sistema() {
banner
echo "IP       : $(curl -s ifconfig.me)"
echo "Uptime   : $(uptime -p)"
echo "RAM      : $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
echo "Load     : $(uptime | awk -F'load average:' '{print $2}')"
pause
}

# =====================================================
# MENU PRINCIPAL
# =====================================================
menu() {
banner
echo "10) Instalar XRAY"
echo "11) Instalar Dropbear"
echo "12) Instalar BadVPN"
echo "13) Estado de servicios"
echo "14) Reiniciar servicios"
echo "15) Perfiles de optimizacion"
echo "16) Limpieza del sistema"
echo "17) Gestion XRAY"
echo "18) Informacion del sistema"
echo "0)  Salir"
read -p "Opcion: " op

case $op in
 10) instalar_xray ;;
 11) instalar_dropbear ;;
 12) instalar_badvpn ;;
 13) estado_servicios ;;
 14) reiniciar_servicios ;;
 15) perfil_opt ;;
 16) limpieza_sistema ;;
 17) menu_xray ;;
 18) info_sistema ;;
 0) exit ;;
esac
}

while true; do menu; done
