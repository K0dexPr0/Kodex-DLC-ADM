#!/bin/bash
# ==================================================
# KodexDev VPS Management System
# Monolithic ADM - KODEXPRO
# Author: Joel_DLC
# ==================================================

### COLORES
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
WHITE="\e[97m"
RESET="\e[0m"

### VARIABLES
XRAY_CONFIG="/etc/xray/config.json"
SCRIPT_PATH="/usr/local/bin/kodexdev"
SCRIPT_URL="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"
DUCKDNS_DIR="/root/.duckdns"
ACME="$HOME/.acme.sh/acme.sh"

### DEPENDENCIAS
install_deps() {
  apt update -y
  apt install -y curl jq socat cron vnstat lsb-release net-tools whiptail
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
# XRAY
# ==================================================
xray_menu() {
while true; do
opt=$(whiptail --title "KodexDev | Xray Manager" --menu "" 20 70 10 \
"1" "Instalar / Verificar Xray" \
"2" "Estado del servicio" \
"3" "Reiniciar Xray" \
"4" "Mostrar ruta config.json" \
"5" "Exportar links VLESS / VMESS" \
"0" "Volver" 3>&1 1>&2 2>&3)

case $opt in
1)
  if command -v xray >/dev/null; then
    echo -e "${GREEN}Xray ya está instalado.${RESET}"
  else
    bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    systemctl enable xray && systemctl start xray
  fi
  pause
;;
2)
  systemctl status xray --no-pager
  pause
;;
3)
  systemctl restart xray && echo -e "${GREEN}Xray reiniciado.${RESET}"
  pause
;;
4)
  if [[ -f $XRAY_CONFIG ]]; then
    echo -e "${YELLOW}Ruta del config.json:${RESET}"
    echo -e "${GREEN}$XRAY_CONFIG${RESET}"
  else
    echo -e "${RED}config.json no encontrado.${RESET}"
  fi
  pause
;;
5)
  if [[ ! -f $XRAY_CONFIG ]]; then
    echo -e "${RED}config.json no existe.${RESET}"
    pause; return
  fi

  echo -e "${GREEN}Links VLESS:${RESET}"
  jq -r '
  .inbounds[] | select(.protocol=="vless") |
  "vless://\(.settings.clients[0].id)@\(.streamSettings.wsSettings.headers.Host // "DOMAIN"):\(.port)?encryption=none&type=ws#VLESS-KodexDev"
  ' $XRAY_CONFIG

  echo
  echo -e "${GREEN}Links VMESS:${RESET}"
  jq -r '
  .inbounds[] | select(.protocol=="vmess") |
  {
    v: "2",
    ps: "VMESS-KodexDev",
    add: "DOMAIN",
    port: (.port|tostring),
    id: .settings.clients[0].id,
    aid: "0",
    net: "ws",
    type: "none",
    host: "",
    path: "/",
    tls: "tls"
  } | @base64 | "vmess://"+.
  ' $XRAY_CONFIG
  pause
;;
0) break ;;
esac
done
}

# ==================================================
# DUCKDNS + ACME.SH
# ==================================================
duckdns_menu() {
read -p "DuckDNS subdominio (ej: midominio): " SUB
read -p "DuckDNS token: " TOKEN

mkdir -p $DUCKDNS_DIR
cat <<EOF > $DUCKDNS_DIR/duck.sh
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=$SUB&token=$TOKEN&ip=" | curl -k -o /root/.duckdns/duck.log -K -
EOF
chmod +x $DUCKDNS_DIR/duck.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * $DUCKDNS_DIR/duck.sh >/dev/null 2>&1") | crontab -

curl https://get.acme.sh | sh
$ACME --issue --dns dns_duckdns -d $SUB.duckdns.org --keylength ec-256
$ACME --install-cert -d $SUB.duckdns.org \
--key-file /etc/xray/private.key \
--fullchain-file /etc/xray/cert.crt

echo -e "${GREEN}DuckDNS + TLS configurado.${RESET}"
pause
}

# ==================================================
# AUTO UPDATE
# ==================================================
update_script() {
echo -e "${YELLOW}Actualizando KodexDev ADM...${RESET}"
curl -fsSL $SCRIPT_URL -o $SCRIPT_PATH
chmod +x $SCRIPT_PATH
echo -e "${GREEN}Actualización completa. Reinicia el script.${RESET}"
exit
}

# ==================================================
# MENU PRINCIPAL
# ==================================================
install_deps
while true; do
banner
opt=$(whiptail --title "KodexDev – Joel_DLC | VPS ADM" --menu "" 20 70 10 \
"1" "Gestión Xray" \
"2" "DuckDNS + TLS (acme.sh)" \
"3" "Actualizar Script" \
"0" "Salir" 3>&1 1>&2 2>&3)

case $opt in
1) xray_menu ;;
2) duckdns_menu ;;
3) update_script ;;
0) clear; exit ;;
esac
done
