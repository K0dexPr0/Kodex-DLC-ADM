#!/bin/bash

# ==================================================
# KodexDev VPS Manager - Joel_DLC | VPS Management Script
# Monolithic Edition
# Author: Joel_DLC
# ==================================================

### COLORES
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
BLUE="\e[34m"; MAGENTA="\e[35m"; CYAN="\e[36m"
WHITE="\e[97m"; NC="\e[0m"

### VARIABLES
XRAY_CONFIG="/usr/local/etc/xray/config.json"
BACKUP_DIR="/root/kodexdev_backups"
SYSCTL_FILE="/etc/sysctl.d/99-kodexdev.conf"

mkdir -p $BACKUP_DIR

### DEPENDENCIAS
install_deps() {
  apt update -y >/dev/null 2>&1
  apt install -y curl jq unzip socat cron lsb-release \
                 vnstat net-tools ufw fail2ban >/dev/null 2>&1
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
  echo "║         KodexDev - VPS Manager Ver 1       ║"
  echo "║            Developed by Joel DLC           ║"
  echo "╠════════════════════════════════════════════╣"
  echo -e "║ OS      : ${WHITE}$OS${RED}"
  echo -e "║ Kernel  : ${WHITE}$KERNEL${RED}"
  echo -e "║ RAM     : ${WHITE}${RAM}MB${RED}"
  echo -e "║ CPU     : ${WHITE}$CPU${RED}"
  echo -e "║ IP      : ${WHITE}$IP${RED}"
  echo -e "║ Uptime  : ${WHITE}$UPTIME${RED}"
  echo "╚════════════════════════════════════════════╝"
  echo -e "${NC}"
}

pause(){ read -p "Presiona ENTER para continuar..."; }

### OPTIMIZACIÓN VPS
optimize_menu() {
  while true; do
    clear
    echo -e "${CYAN}[ Optimización VPS ]${NC}"
    echo "1) Perfil Básico (seguro)"
    echo "2) Perfil Alto Rendimiento"
    echo "3) Ver configuración actual"
    echo "4) Restaurar valores por defecto"
    echo "0) Volver"
    read -p "Opción: " o
    case $o in
      1)
        cp $SYSCTL_FILE $BACKUP_DIR/sysctl.bak 2>/dev/null
        cat <<EOF >$SYSCTL_FILE
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.ip_forward=1
EOF
        sysctl --system >/dev/null
        echo -e "${GREEN}Perfil básico aplicado.${NC}"; pause;;
      2)
        cp $SYSCTL_FILE $BACKUP_DIR/sysctl.bak 2>/dev/null
        cat <<EOF >$SYSCTL_FILE
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
fs.file-max=1000000
net.ipv4.ip_forward=1
EOF
        sysctl --system >/dev/null
        echo -e "${GREEN}Perfil alto rendimiento aplicado.${NC}"; pause;;
      3)
        sysctl -a | grep tcp_; pause;;
      4)
        [ -f $BACKUP_DIR/sysctl.bak ] && cp $BACKUP_DIR/sysctl.bak $SYSCTL_FILE
        sysctl --system >/dev/null
        echo -e "${YELLOW}Restaurado.${NC}"; pause;;
      0) break;;
    esac
  done
}

### XRAY
xray_menu() {
  while true; do
    clear
    echo -e "${CYAN}[ Gestión Xray ]${NC}"
    echo "1) Instalar Xray"
    echo "2) Reiniciar Xray"
    echo "3) Ver estado"
    echo "4) Ver config.json"
    echo "5) Backup configuración"
    echo "6) Restaurar configuración"
    echo "0) Volver"
    read -p "Opción: " x
    case $x in
      1)
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        systemctl enable xray; systemctl start xray
        pause;;
      2) systemctl restart xray; pause;;
      3) systemctl status xray; pause;;
      4) jq '.' $XRAY_CONFIG; pause;;
      5) cp $XRAY_CONFIG $BACKUP_DIR/xray_$(date +%F).json; pause;;
      6)
        ls $BACKUP_DIR | grep xray_
        read -p "Archivo: " f
        cp "$BACKUP_DIR/$f" $XRAY_CONFIG
        systemctl restart xray
        pause;;
      0) break;;
    esac
  done
}

### PROTOCOLOS
protocol_menu() {
  while true; do
    clear
    echo -e "${CYAN}[ Protocolos & Puertos ]${NC}"
    echo "1) Ver puertos activos"
    echo "2) Dropbear (SSH alterno)"
    echo "3) BadVPN UDP"
    echo "0) Volver"
    read -p "Opción: " p
    case $p in
      1) ss -tulnp; pause;;
      2)
        apt install -y dropbear
        sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
        sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=143/' /etc/default/dropbear
        systemctl restart dropbear
        pause;;
      3)
        echo "Instala BadVPN manualmente según necesidad."
        pause;;
      0) break;;
    esac
  done
}

### TRÁFICO
traffic_menu() {
  while true; do
    clear
    echo -e "${CYAN}[ Estadísticas de Tráfico ]${NC}"
    echo "1) Uso por interfaz"
    echo "2) Conexiones activas"
    echo "0) Volver"
    read -p "Opción: " t
    case $t in
      1) vnstat; pause;;
      2) ss -s; pause;;
      0) break;;
    esac
  done
}

### SEGURIDAD
security_menu() {
  while true; do
    clear
    echo -e "${CYAN}[ Seguridad ]${NC}"
    echo "1) Activar UFW seguro"
    echo "2) Ver reglas"
    echo "0) Volver"
    read -p "Opción: " s
    case $s in
      1)
        ufw allow ssh
        ufw allow 443
        ufw enable
        pause;;
      2) ufw status; pause;;
      0) break;;
    esac
  done
}

### MENU PRINCIPAL
install_deps
while true; do
  banner
  echo "01) Optimización VPS"
  echo "02) Gestión Xray"
  echo "03) Protocolos & Puertos"
  echo "04) Estadísticas de tráfico"
  echo "05) Seguridad"
  echo "00) Salir"
  read -p "Selecciona: " m
  case $m in
    1) optimize_menu;;
    2) xray_menu;;
    3) protocol_menu;;
    4) traffic_menu;;
    5) security_menu;;
    0) exit;;
  esac
done
