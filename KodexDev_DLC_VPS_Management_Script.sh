#!/bin/bash
# ==========================================================
# KodexDev VPS Manager | Monolithic Edition
# Author: Joel_DLC
# Branding: KodexDev
# ==========================================================

### COLORES (LEGIBLES)
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"
BOLD="\e[1m"

### VARIABLES GLOBALES
XRAY_DIR="/root/etc/xray"
XRAY_CONFIG="$XRAY_DIR/config.json"
BACKUP_DIR="/root/kodexdev_backups"
SCRIPT_PATH="/usr/local/bin/kodexdev"
REPO_RAW="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"

mkdir -p "$BACKUP_DIR"

### PAUSA
pause(){ read -p "Presiona ENTER para continuar..."; }

### DEPENDENCIAS
install_deps(){
  apt update -y
  apt install -y curl jq unzip socat cron lsb-release \
                 vnstat net-tools ufw fail2ban \
                 nano vim whiptail speedtest-cli
}

### INFO DEL SISTEMA
system_info(){
  OS=$(lsb_release -ds 2>/dev/null | tr -d '"')
  KERNEL=$(uname -r)
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2)
  IP=$(curl -s ifconfig.me)
  UPTIME=$(uptime -p)
}

### BANNER
banner(){
  system_info
  clear
  echo -e "${RED}${BOLD}"
  echo "╔════════════════════════════════════════════╗"
  echo "║        KODEXDEV VPS MANAGER                ║"
  echo "║        Author: Joel_DLC                    ║"
  echo "╠════════════════════════════════════════════╣"
  echo -e "║ OS      : ${NC}$OS"
  echo -e "║ Kernel  : $KERNEL"
  echo -e "║ RAM     : ${RAM} MB"
  echo -e "║ CPU     : $CPU"
  echo -e "║ IP      : $IP"
  echo -e "║ Uptime  : $UPTIME"
  echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
}

# ==========================================================
# OPTIMIZACIÓN VPS
# ==========================================================
optimize_vps(){
  while true; do
    clear
    echo -e "${GREEN}[ Optimización VPS ]${NC}"
    echo "1) Perfil seguro"
    echo "2) Alto rendimiento (BBR)"
    echo "3) Ver parámetros activos"
    echo "4) Restaurar respaldo"
    echo "0) Volver"
    read -p "Opción: " o
    case $o in
      1)
        cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.bak" 2>/dev/null
        cat >> /etc/sysctl.conf <<EOF
net.ipv4.tcp_fastopen=3
net.ipv4.ip_forward=1
EOF
        sysctl -p
        pause;;
      2)
        cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.bak" 2>/dev/null
        cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
fs.file-max=1000000
net.ipv4.ip_forward=1
EOF
        sysctl -p
        pause;;
      3)
        sysctl -a | grep tcp_
        pause;;
      4)
        [ -f "$BACKUP_DIR/sysctl.bak" ] && cp "$BACKUP_DIR/sysctl.bak" /etc/sysctl.conf
        sysctl -p
        pause;;
      0) break;;
    esac
  done
}

# ==========================================================
# XRAY
# ==========================================================
xray_menu(){
  while true; do
    clear
    echo -e "${GREEN}[ Gestión Xray ]${NC}"
    echo "1) Instalar Xray"
    echo "2) Estado de Xray"
    echo "3) Reiniciar Xray"
    echo "4) Ruta config.json"
    echo "5) Ver / Editar config.json"
    echo "6) Exportar links VLESS / VMESS"
    echo "0) Volver"
    read -p "Opción: " x
    case $x in
      1)
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        mkdir -p "$XRAY_DIR"
        pause;;
      2)
        systemctl status xray
        pause;;
      3)
        systemctl restart xray
        pause;;
      4)
        echo -e "${YELLOW}Ruta:${NC} $XRAY_CONFIG"
        pause;;
      5)
        echo "1) Ver (less)"
        echo "2) Editar con nano"
        echo "3) Editar con vim"
        read -p "Opción: " e
        case $e in
          1) less "$XRAY_CONFIG";;
          2) nano "$XRAY_CONFIG";;
          3) vim "$XRAY_CONFIG";;
        esac;;
      6)
        if [ ! -f "$XRAY_CONFIG" ]; then
          echo "config.json no encontrado"
          pause; continue
        fi
        jq -r '
        .inbounds[]
        | select(.protocol=="vless" or .protocol=="vmess")
        | .settings.clients[]
        | "PROTOCOLO: \(.email)\nUUID: \(.id)\n"
        ' "$XRAY_CONFIG"
        pause;;
      0) break;;
    esac
  done
}

# ==========================================================
# CERTIFICADOS & DOMINIOS
# ==========================================================
cert_menu(){
  while true; do
    clear
    echo -e "${GREEN}[ Certificados & Dominios ]${NC}"
    echo "1) DuckDNS + acme.sh"
    echo "2) Let's Encrypt manual"
    echo "0) Volver"
    read -p "Opción: " c
    case $c in
      1)
        read -p "¿Tienes dominio DuckDNS? (s/n): " r
        [ "$r" != "s" ] && break
        read -p "Subdominio: " d
        read -p "Token DuckDNS: " t
        curl "https://www.duckdns.org/update?domains=$d&token=$t&ip="
        curl https://get.acme.sh | sh
        ~/.acme.sh/acme.sh --issue --dns dns_duckdns -d "$d.duckdns.org"
        pause;;
      2)
        echo "Implementación manual pendiente"
        pause;;
      0) break;;
    esac
  done
}

# ==========================================================
# HERRAMIENTAS VPS
# ==========================================================
tools_menu(){
  while true; do
    clear
    echo -e "${GREEN}[ Herramientas VPS ]${NC}"
    echo "1) Test de velocidad"
    echo "2) Reiniciar VPS"
    echo "3) Cambiar contraseña root"
    echo "0) Volver"
    read -p "Opción: " t
    case $t in
      1) speedtest-cli; pause;;
      2)
        read -p "¿Seguro? (s): " r
        [ "$r" = "s" ] && reboot;;
      3) passwd root;;
      0) break;;
    esac
  done
}

# ==========================================================
# AUTO-UPDATE
# ==========================================================
update_script(){
  curl -fsSL "$REPO_RAW" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "Script actualizado"
  pause
}

# ==========================================================
# MENU PRINCIPAL
# ==========================================================
install_deps

while true; do
  banner
  echo "01) Optimización VPS"
  echo "02) Gestión Xray"
  echo "03) Certificados & Dominios"
  echo "04) Herramientas VPS"
  echo "05) Actualizar script"
  echo "00) Salir"
  read -p "Selecciona: " m
  case $m in
    1) optimize_vps;;
    2) xray_menu;;
    3) cert_menu;;
    4) tools_menu;;
    5) update_script;;
    0) exit;;
  esac
done
