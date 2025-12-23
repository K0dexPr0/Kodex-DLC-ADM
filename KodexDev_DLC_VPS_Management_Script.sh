#!/bin/bash

# ==================================================
# KodexDev VPS Manager - Joel_DLC
# Monolithic VPS Management Script
# ==================================================

### COLORES (legibles)
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
WHITE="\e[97m"
NC="\e[0m"

### VARIABLES
XRAY_CONFIG="/usr/local/etc/xray/config.json"
CERT_DIR="/etc/xray/certs"
BACKUP_DIR="/root/kodexdev_backups"
SYSCTL_FILE="/etc/sysctl.d/99-kodexdev.conf"
SCRIPT_URL="https://raw.githubusercontent.com/K0dexPr0/Kodex-DLC-ADM/main/KodexDev_DLC_VPS_Management_Script.sh"
SCRIPT_PATH="$(realpath "$0")"

mkdir -p "$BACKUP_DIR" "$CERT_DIR"

# ==================================================
# DEPENDENCIAS
# ==================================================
install_deps() {
  apt update -y >/dev/null 2>&1
  apt install -y curl jq unzip socat cron lsb-release \
                 vnstat net-tools ufw fail2ban \
                 qrencode openssl >/dev/null 2>&1
}

# ==================================================
# INFO DEL SISTEMA
# ==================================================
system_info() {
  OS=$(lsb_release -ds 2>/dev/null | tr -d '"')
  KERNEL=$(uname -r)
  RAM=$(free -m | awk '/Mem:/ {print $2}')
  CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
  IP=$(curl -s ifconfig.me)
  UPTIME=$(uptime -p)
}

# ==================================================
# BANNER
# ==================================================
banner() {
  system_info
  clear
  echo -e "${RED}"
  echo "╔════════════════════════════════════════════╗"
  echo "║        KodexDev VPS Manager v1.0            ║"
  echo "║              by Joel_DLC                   ║"
  echo "╠════════════════════════════════════════════╣"
  echo -e "║ OS      : ${WHITE}$OS${RED}"
  echo -e "║ Kernel  : ${WHITE}$KERNEL${RED}"
  echo -e "║ RAM     : ${WHITE}${RAM} MB${RED}"
  echo -e "║ CPU     : ${WHITE}$CPU${RED}"
  echo -e "║ IP      : ${WHITE}$IP${RED}"
  echo -e "║ Uptime  : ${WHITE}$UPTIME${RED}"
  echo "╚════════════════════════════════════════════╝"
  echo -e "${NC}"
}

pause() { read -p "Presiona ENTER para continuar..."; }

# ==================================================
# OPTIMIZACIÓN VPS
# ==================================================
optimize_menu() {
  while true; do
    clear
    echo -e "${GREEN}[ Optimización VPS ]${NC}"
    echo "1) Perfil Básico (seguro)"
    echo "2) Perfil Alto Rendimiento"
    echo "3) Ver configuración actual"
    echo "4) Restaurar configuración previa"
    echo "0) Volver"
    read -p "Opción: " o
    case $o in
      1)
        cp "$SYSCTL_FILE" "$BACKUP_DIR/sysctl.bak" 2>/dev/null
        cat <<EOF >"$SYSCTL_FILE"
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.ip_forward=1
EOF
        sysctl --system >/dev/null
        echo -e "${GREEN}Perfil básico aplicado.${NC}"
        pause;;
      2)
        cp "$SYSCTL_FILE" "$BACKUP_DIR/sysctl.bak" 2>/dev/null
        cat <<EOF >"$SYSCTL_FILE"
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
fs.file-max=1000000
net.ipv4.ip_forward=1
EOF
        sysctl --system >/dev/null
        echo -e "${GREEN}Perfil alto rendimiento aplicado.${NC}"
        pause;;
      3)
        sysctl -a | grep tcp_
        pause;;
      4)
        if [[ -f "$BACKUP_DIR/sysctl.bak" ]]; then
          cp "$BACKUP_DIR/sysctl.bak" "$SYSCTL_FILE"
          sysctl --system >/dev/null
          echo -e "${YELLOW}Configuración restaurada.${NC}"
        else
          echo -e "${RED}No hay backup previo.${NC}"
        fi
        pause;;
      0) break;;
    esac
  done
}

# ==================================================
# XRAY
# ==================================================
xray_menu() {
  while true; do
    clear
    echo -e "${GREEN}[ Gestión Xray ]${NC}"
    echo "1) Instalar Xray"
    echo "2) Reiniciar Xray"
    echo "3) Ver estado"
    echo "4) Ver config.json"
    echo "5) Mostrar ruta del config.json"
    echo "6) Backup configuración"
    echo "7) Restaurar configuración"
    echo "8) DuckDNS + Certificado TLS"
    echo "9) Exportar links + QR"
    echo "0) Volver"
    read -p "Opción: " x
    case $x in
      1)
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        systemctl enable xray && systemctl start xray
        pause;;
      2) systemctl restart xray; pause;;
      3) systemctl status xray; pause;;
      4) jq '.' "$XRAY_CONFIG"; pause;;
      5)
        echo -e "${YELLOW}Ruta del config.json:${NC}"
        echo -e "${GREEN}$XRAY_CONFIG${NC}"
        ls -l "$XRAY_CONFIG"
        pause;;
      6)
        cp "$XRAY_CONFIG" "$BACKUP_DIR/xray_$(date +%F).json"
        echo -e "${GREEN}Backup creado.${NC}"
        pause;;
      7)
        ls "$BACKUP_DIR" | grep xray_
        read -p "Archivo a restaurar: " f
        cp "$BACKUP_DIR/$f" "$XRAY_CONFIG"
        systemctl restart xray
        pause;;
      8) duckdns_tls;;
      9) export_xray_links;;
      0) break;;
    esac
  done
}

# ==================================================
# DUCKDNS + TLS
# ==================================================
duckdns_tls() {
  clear
  echo -e "${GREEN}[ DuckDNS + TLS ]${NC}"
  read -p "Dominio DuckDNS (sin .duckdns.org): " DUCK_DOMAIN
  read -p "Token DuckDNS: " DUCK_TOKEN
  read -p "Email ACME: " ACME_EMAIL

  curl https://get.acme.sh | sh -s email="$ACME_EMAIL"

  export DuckDNS_Token="$DUCK_TOKEN"
  export DuckDNS_Domain="$DUCK_DOMAIN"

  ~/.acme.sh/acme.sh --issue --dns dns_duckdns \
    -d "$DUCK_DOMAIN.duckdns.org" --keylength ec-256

  ~/.acme.sh/acme.sh --install-cert \
    -d "$DUCK_DOMAIN.duckdns.org" --ecc \
    --key-file "$CERT_DIR/private.key" \
    --fullchain-file "$CERT_DIR/fullchain.crt" \
    --reloadcmd "systemctl restart xray"

  echo -e "${GREEN}Certificados instalados en:${NC} $CERT_DIR"
  pause
}

# ==================================================
# EXPORTAR LINKS + QR
# ==================================================
export_xray_links() {
  clear
  echo -e "${GREEN}[ Exportar Links Xray ]${NC}"

  UUIDS=$(jq -r '.. | .id? // empty' "$XRAY_CONFIG")
  [[ -z "$UUIDS" ]] && echo -e "${RED}No se encontraron UUIDs.${NC}" && pause && return

  read -p "Dominio/IP: " SERVER
  read -p "Puerto: " PORT

  for UUID in $UUIDS; do
    LINK="vless://$UUID@$SERVER:$PORT?encryption=none#KodexDev"
    echo -e "${GREEN}$LINK${NC}"
    qrencode -t ANSIUTF8 "$LINK"
    echo
  done
  pause
}

# ==================================================
# AUTOUPDATE
# ==================================================
autoupdate_script() {
  clear
  echo -e "${YELLOW}Actualizando script...${NC}"
  curl -fsSL "$SCRIPT_URL" -o /tmp/kodexdev_update.sh || {
    echo -e "${RED}Error descargando actualización.${NC}"
    pause; return;
  }
  chmod +x /tmp/kodexdev_update.sh
  mv /tmp/kodexdev_update.sh "$SCRIPT_PATH"
  echo -e "${GREEN}Actualización completada.${NC}"
  pause
  exec "$SCRIPT_PATH"
}

# ==================================================
# MENÚ PRINCIPAL
# ==================================================
install_deps

while true; do
  banner
  echo "01) Optimización VPS"
  echo "02) Gestión Xray"
  echo "03) Actualizar script"
  echo "00) Salir"
  read -p "Selecciona: " m
  case $m in
    1) optimize_menu;;
    2) xray_menu;;
    3) autoupdate_script;;
    0) exit;;
  esac
done
