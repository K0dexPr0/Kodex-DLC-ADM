#!/bin/bash
# ==========================================================
# KodexDev VPS Management System
# Author  : Joel_DLC
# Edition : Monolithic ADM (VPS*MX Style)
# ==========================================================

### COLORES (LEGIBLES)
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

### VARIABLES
SCRIPT_PATH="/usr/local/bin/kodexdev"
SCRIPT_RAW="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"
XRAY_CONFIG="/etc/xray/config.json"
BACKUP_DIR="/root/kodexdev_backups"
DOMAIN_FILE="/root/.duckdns_domain"

mkdir -p "$BACKUP_DIR"

### DEPENDENCIAS
install_deps() {
  apt update -y >/dev/null 2>&1
  apt install -y curl jq socat cron vnstat net-tools \
                 ufw fail2ban lsb-release qrencode >/dev/null 2>&1
}

### INFO SISTEMA
system_info() {
  OS=$(lsb_release -ds | tr -d '"')
  KERNEL=$(uname -r)
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
  IP=$(curl -s ifconfig.me)
  UPTIME=$(uptime -p)
}

### BANNER
banner() {
  system_info
  clear
  echo -e "${RED}"
  echo "╔════════════════════════════════════════════╗"
  echo "║   KodexDev VPS Management System           ║"
  echo "║   Author : Joel_DLC                        ║"
  echo "║   Build  : Monolithic ADM                 ║"
  echo "╠════════════════════════════════════════════╣"
  echo -e "║ OS      : ${GREEN}$OS${RED}"
  echo -e "║ Kernel  : ${GREEN}$KERNEL${RED}"
  echo -e "║ RAM     : ${GREEN}${RAM}MB${RED}"
  echo -e "║ CPU     : ${GREEN}$CPU${RED}"
  echo -e "║ IP      : ${GREEN}$IP${RED}"
  echo -e "║ Uptime  : ${GREEN}$UPTIME${RED}"
  echo "╚════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

pause(){ read -p "Presiona ENTER para continuar..."; }

# ==========================================================
# OPTIMIZACIÓN VPS
# ==========================================================
optimize_menu() {
while true; do
banner
echo "01) Perfil Seguro (BBR)"
echo "02) Perfil Alto Rendimiento"
echo "03) Restaurar valores"
echo "00) Volver"
read -p "Opción: " o
case $o in
1)
cat >/etc/sysctl.d/99-kodexdev.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
EOF
sysctl --system >/dev/null
echo -e "${GREEN}Perfil seguro aplicado.${RESET}"; pause;;
2)
cat >/etc/sysctl.d/99-kodexdev.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
fs.file-max=1000000
EOF
sysctl --system >/dev/null
echo -e "${GREEN}Perfil alto rendimiento aplicado.${RESET}"; pause;;
3)
rm -f /etc/sysctl.d/99-kodexdev.conf
sysctl --system >/dev/null
echo -e "${YELLOW}Valores restaurados.${RESET}"; pause;;
0) break;;
esac
done
}

# ==========================================================
# XRAY
# ==========================================================
xray_menu() {
while true; do
banner
echo "01) Instalar / Verificar Xray"
echo "02) Estado del servicio"
echo "03) Reiniciar Xray"
echo "04) Mostrar ruta config.json"
echo "05) Ver config.json"
echo "06) Exportar links VLESS / VMESS"
echo "00) Volver"
read -p "Opción: " x
case $x in
1)
if command -v xray >/dev/null; then
echo -e "${GREEN}Xray ya está instalado.${RESET}"
else
bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
systemctl enable xray && systemctl start xray
fi
pause;;
2) systemctl status xray --no-pager; pause;;
3) systemctl restart xray; echo -e "${GREEN}Xray reiniciado.${RESET}"; pause;;
4)
echo -e "${YELLOW}Ruta del config.json:${RESET}"
echo -e "${GREEN}$XRAY_CONFIG${RESET}"
pause;;
5)
[ -f "$XRAY_CONFIG" ] && less "$XRAY_CONFIG" || echo "No existe config.json"
pause;;
6)
if [[ -f "$XRAY_CONFIG" ]]; then
DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null)
jq -r '
.inbounds[] |
select(.protocol=="vless" or .protocol=="vmess") |
.protocol + "://" +
.users[0].id + "@" + "'$DOMAIN'" + ":" +
.port + "?encryption=none&type=ws&path=" +
.streamSettings.wsSettings.path
' "$XRAY_CONFIG" | tee /root/xray_links.txt

qrencode -t ANSIUTF8 < /root/xray_links.txt
echo -e "${GREEN}Links exportados en /root/xray_links.txt${RESET}"
else
echo "config.json no encontrado"
fi
pause;;
0) break;;
esac
done
}

# ==========================================================
# DUCKDNS + TLS
# ==========================================================
duckdns_menu() {
banner
read -p "Dominio DuckDNS (ej: midominio.duckdns.org): " DOMAIN
read -p "Token DuckDNS: " TOKEN
echo "$DOMAIN" > "$DOMAIN_FILE"

mkdir -p /root/duckdns
cat >/root/duckdns/duck.sh <<EOF
echo url="https://www.duckdns.org/update?domains=${DOMAIN%%.*}&token=$TOKEN&ip=" | curl -k -o /root/duckdns/duck.log -K -
EOF

chmod +x /root/duckdns/duck.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/duckdns/duck.sh") | crontab -

curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN"
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
--key-file /etc/xray/xray.key \
--fullchain-file /etc/xray/xray.crt

echo -e "${GREEN}DuckDNS + TLS configurado.${RESET}"
pause
}

# ==========================================================
# AUTO UPDATE
# ==========================================================
update_script() {
curl -fsSL "$SCRIPT_RAW" -o "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}Script actualizado correctamente.${RESET}"
pause
}

# ==========================================================
# MENÚ PRINCIPAL
# ==========================================================
install_deps

while true; do
banner
echo "01) Optimización VPS"
echo "02) Gestión Xray"
echo "03) DuckDNS + TLS"
echo "04) Actualizar Script"
echo "00) Salir"
read -p "Selecciona: " m
case $m in
1) optimize_menu;;
2) xray_menu;;
3) duckdns_menu;;
4) update_script;;
0) exit;;
esac
done
