#!/bin/bash
# ==========================================================
# KODEXDEV VPS MANAGER - MONOLITHIC EDITION
# Author: Joel_DLC
# ==========================================================

### COLORES
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; NC="\e[0m"; BOLD="\e[1m"

### VARIABLES
XRAY_ROOT="/root/etc/xray"
XRAY_CONFIG="$XRAY_ROOT/config.json"
BACKUP_DIR="/root/kodexdev_backups"
SCRIPT_PATH="/usr/local/bin/kodexdev"
RAW_URL="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"

mkdir -p "$BACKUP_DIR" "$XRAY_ROOT"

pause(){ read -p "Presiona ENTER para continuar..."; }

require_root(){
  [[ $EUID -ne 0 ]] && echo "Ejecuta como root" && exit 1
}

install_deps(){
  apt update -y
  apt install -y curl jq unzip socat cron lsb-release \
    vnstat net-tools ufw fail2ban \
    nano vim whiptail speedtest-cli \
    openvpn stunnel4 shadowsocks-libev
}

detect_xray_config(){
  if [[ ! -f "$XRAY_CONFIG" ]]; then
    if [[ -f "/usr/local/etc/xray/config.json" ]]; then
      ln -sf /usr/local/etc/xray/config.json "$XRAY_CONFIG"
    fi
  fi
}

system_info(){
  OS=$(lsb_release -ds 2>/dev/null | tr -d '"')
  CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2)
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  IP=$(curl -s ifconfig.me)
  UPTIME=$(uptime -p)
}

banner(){
  system_info
  clear
  echo -e "${RED}${BOLD}"
  echo "╔════════════════════════════════════════════════╗"
  echo "║              KODEXDEV VPS MANAGER              ║"
  echo "║                  Joel_DLC                      ║"
  echo "╠════════════════════════════════════════════════╣"
  echo -e "║ OS      : ${NC}$OS"
  echo -e "║ CPU     : $CPU"
  echo -e "║ RAM     : ${RAM} MB"
  echo -e "║ IP      : $IP"
  echo -e "║ Uptime  : $UPTIME"
  echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
}

# ==========================================================
# OPTIMIZACIÓN VPS
# ==========================================================
optimize_vps(){
  clear
  cat <<EOF >/etc/sysctl.d/99-kodexdev.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
fs.file-max=1000000
net.ipv4.ip_forward=1
EOF
  sysctl --system
  echo "Optimización aplicada"
  pause
}

# ==========================================================
# XRAY
# ==========================================================
xray_menu(){
  detect_xray_config
  while true; do
    clear
    echo "[ Xray ]"
    echo "1) Instalar Xray"
    echo "2) Estado"
    echo "3) Reiniciar"
    echo "4) Ver ruta config.json"
    echo "5) Ver / Editar config.json"
    echo "6) Exportar VLESS / VMESS"
    echo "0) Volver"
    read -p "Opción: " x
    case $x in
      1)
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        detect_xray_config
        pause;;
      2) systemctl status xray; pause;;
      3) systemctl restart xray; pause;;
      4) echo "$XRAY_CONFIG"; pause;;
      5)
        echo "1) less  2) nano  3) vim"
        read -p "> " e
        [[ $e == 1 ]] && less "$XRAY_CONFIG"
        [[ $e == 2 ]] && nano "$XRAY_CONFIG"
        [[ $e == 3 ]] && vim "$XRAY_CONFIG";;
      6)
        if [[ ! -f "$XRAY_CONFIG" ]]; then
          echo "config.json no encontrado"; pause; continue
        fi
        jq -r '
        .inbounds[]
        | select(.protocol=="vless" or .protocol=="vmess")
        | .settings.clients[]
        | "PROTO: \(.email)\nUUID: \(.id)\n"
        ' "$XRAY_CONFIG"
        pause;;
      0) break;;
    esac
  done
}

# ==========================================================
# CERTIFICADOS
# ==========================================================
cert_menu(){
  clear
  echo "1) DuckDNS + acme.sh"
  echo "2) Let’s Encrypt (manual)"
  read -p "Opción: " c
  case $c in
    1)
      read -p "¿Tienes DuckDNS? (s/n): " r
      [[ $r != "s" ]] && return
      read -p "Subdominio: " d
      read -p "Token: " t
      curl "https://www.duckdns.org/update?domains=$d&token=$t&ip="
      curl https://get.acme.sh | sh
      ~/.acme.sh/acme.sh --issue --dns dns_duckdns -d "$d.duckdns.org"
      pause;;
    2)
      echo "Usa certbot manualmente según dominio"
      pause;;
  esac
}

# ==========================================================
# PROTOCOLOS
# ==========================================================
protocols_menu(){
  clear
  echo "1) OpenVPN"
  echo "2) Shadowsocks"
  echo "3) SSL (stunnel)"
  echo "0) Volver"
  read -p "> " p
  case $p in
    1) systemctl status openvpn; pause;;
    2) systemctl status shadowsocks-libev; pause;;
    3) systemctl status stunnel4; pause;;
  esac
}

# ==========================================================
# PUERTOS
# ==========================================================
ports_menu(){
  clear
  echo "1) Ver puertos activos"
  echo "2) Abrir puerto"
  echo "3) Cerrar puerto"
  read -p "> " p
  case $p in
    1) ss -tulnp; pause;;
    2) read -p "Puerto: " pt; ufw allow "$pt"; pause;;
    3) read -p "Puerto: " pt; ufw delete allow "$pt"; pause;;
  esac
}

# ==========================================================
# HERRAMIENTAS VPS
# ==========================================================
tools_menu(){
  clear
  echo "1) Test velocidad"
  echo "2) Detalles VPS"
  echo "3) Reiniciar VPS"
  echo "4) Cambiar password root"
  read -p "> " t
  case $t in
    1) speedtest-cli; pause;;
    2) system_info; pause;;
    3) reboot;;
    4) passwd root;;
  esac
}

# ==========================================================
# AUTOUPDATE
# ==========================================================
update_script(){
  curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "Actualizado"
  pause
}

# ==========================================================
# MAIN
# ==========================================================
require_root
install_deps

while true; do
  banner
  echo "01) Optimización VPS"
  echo "02) Xray"
  echo "03) Protocolos"
  echo "04) Puertos"
  echo "05) Certificados"
  echo "06) Herramientas VPS"
  echo "07) Actualizar script"
  echo "00) Salir"
  read -p "Selecciona: " m
  case $m in
    1) optimize_vps;;
    2) xray_menu;;
    3) protocols_menu;;
    4) ports_menu;;
    5) cert_menu;;
    6) tools_menu;;
    7) update_script;;
    0) exit;;
  esac
done
