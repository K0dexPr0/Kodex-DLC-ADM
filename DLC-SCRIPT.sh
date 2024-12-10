#!/bin/bash

# Colores y estilos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Animación de carga
loading() {
    for i in {1..3}; do
        echo -ne "${CYAN}Procesando${RESET}."
        sleep 0.5
        echo -ne "."
        sleep 0.5
        echo -ne "."
        sleep 0.5
        echo -ne "\r                          \r" # Limpia la línea
    done
}

# Banner de bienvenida
echo -e "${BLUE}${BOLD}***********************************************"
echo -e "*           KODEX DLC-SCRIPT *** Configuración de VPS              *"
echo -e "***********************************************${RESET}"

# Comprobar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}Este script debe ejecutarse como root.${RESET}"
    exit 1
fi

# Actualización del sistema
echo -e "${GREEN}${BOLD}Actualizando el sistema...${RESET}"
loading
apt update && apt upgrade -y
echo -e "${GREEN}Sistema actualizado correctamente.${RESET}"

# Instalación de dependencias
echo -e "${GREEN}${BOLD}Instalando dependencias necesarias...${RESET}"
loading
apt install -y curl ufw unzip socat
echo -e "${GREEN}Dependencias instaladas correctamente.${RESET}"

# Configuración del firewall
echo -e "${YELLOW}${BOLD}Configurando el firewall...${RESET}"
loading
ufw allow 80
ufw allow 443
ufw enable
echo -e "${GREEN}Firewall configurado correctamente. Puertos 80 y 443 abiertos.${RESET}"

# Instalación de v2ray/xray
echo -e "${CYAN}${BOLD}Instalando Xray (v2ray)...${RESET}"
loading
curl -O https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh
bash install-release.sh
echo -e "${GREEN}Xray instalado correctamente.${RESET}"

# Configuración del certificado SSL
echo -e "${BLUE}${BOLD}¿Cómo deseas configurar el certificado SSL?${RESET}"
echo -e "1. Let's Encrypt (requiere un dominio apuntando a tu VPS)"
echo -e "2. Cloudflare (requiere certificado generado en Cloudflare)"
echo -e "3. Ruta manual (proporcionarás las rutas de los certificados)"
read -rp "Selecciona una opción [1-3]: " cert_option

case $cert_option in
1)
    echo -e "${YELLOW}${BOLD}Generando certificados SSL con Let's Encrypt...${RESET}"
    loading
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --issue -d tu-dominio.com --standalone
    ~/.acme.sh/acme.sh --install-cert -d tu-dominio.com \
        --key-file /etc/ssl/xray_key.pem \
        --fullchain-file /etc/ssl/xray_cert.pem
    echo -e "${GREEN}Certificados Let's Encrypt configurados correctamente.${RESET}"
    ;;
2)
    echo -e "${CYAN}${BOLD}Configurando con certificados de Cloudflare...${RESET}"
    read -rp "Introduce la ruta del archivo del certificado (fullchain): " cf_cert_path
    read -rp "Introduce la ruta del archivo de la clave privada: " cf_key_path
    cp "$cf_cert_path" /etc/ssl/xray_cert.pem
    cp "$cf_key_path" /etc/ssl/xray_key.pem
    echo -e "${GREEN}Certificados Cloudflare configurados correctamente.${RESET}"
    ;;
3)
    echo -e "${CYAN}${BOLD}Configurando con ruta manual...${RESET}"
    read -rp "Introduce la ruta del archivo del certificado (fullchain): " manual_cert_path
    read -rp "Introduce la ruta del archivo de la clave privada: " manual_key_path
    cp "$manual_cert_path" /etc/ssl/xray_cert.pem
    cp "$manual_key_path" /etc/ssl/xray_key.pem
    echo -e "${GREEN}Certificados configurados correctamente desde ruta manual.${RESET}"
    ;;
*)
    echo -e "${RED}Opción no válida. Saliendo del script.${RESET}"
    exit 1
    ;;
esac

# Configuración de Xray
echo -e "${BLUE}${BOLD}Configurando Xray...${RESET}"
cat <<EOF > /usr/local/etc/xray/config.json
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$(uuidgen)",
            "level": 0,
            "email": "usuario1@example.com"
          },
          {
            "id": "$(uuidgen)",
            "level": 0,
            "email": "usuario2@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/ssl/xray_cert.pem",
              "keyFile": "/etc/ssl/xray_key.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
echo -e "${GREEN}Xray configurado correctamente.${RESET}"

# Activar BBR
echo -e "${YELLOW}${BOLD}Activando el algoritmo BBR...${RESET}"
loading
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
echo -e "${GREEN}BBR activado.${RESET}"
lsmod | grep bbr

# Finalización
echo -e "${GREEN}${BOLD}Configuración completada exitosamente. Xray está en ejecución y los puertos 80 y 443 están abiertos.${RESET}"
echo -e "${BLUE}${BOLD}Gracias por usar este script.${RESET}"
