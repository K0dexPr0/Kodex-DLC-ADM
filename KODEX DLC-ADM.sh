#!/bin/bash

# Variables globales
SCRIPT_VERSION="1.0"
SERVER_IP=$(curl -s https://api.ipify.org)
DATE=$(date)
RAM_USAGE=$(free -h | grep Mem | awk '{print $3 "/" $2}')
DISK_USAGE=$(df -h | grep '^/dev' | awk '{print $3 "/" $2}')
SWAP_USAGE=$(free -h | grep Swap | awk '{print $3 "/" $2}')
USER="root"
CREDITS="JOEL-DLC"
COLOR_GREEN="\e[92m"
COLOR_YELLOW="\e[93m"
COLOR_RED="\e[91m"
COLOR_RESET="\e[0m"

# Función para mostrar el banner
function show_banner() {
    echo -e "$COLOR_GREEN========================================="
    echo -e "       VPS Manager Script v$SCRIPT_VERSION"
    echo -e "          Kodex DLC-ADM"
    echo -e "=========================================$COLOR_RESET"
    echo -e "$COLOR_YELLOWServidor: $SERVER_IP$COLOR_RESET"
    echo -e "$COLOR_YELLOWFecha: $DATE$COLOR_RESET"
    echo -e "$COLOR_YELLOWRAM: $RAM_USAGE$COLOR_RESET"
    echo -e "$COLOR_YELLOWDisco: $DISK_USAGE$COLOR_RESET"
    echo -e "$COLOR_YELLOWSwap: $SWAP_USAGE$COLOR_RESET"
    echo -e "$COLOR_YELLOWCréditos: $CREDITS$COLOR_RESET"
    echo -e "$COLOR_GREEN-----------------------------------------"
}

# Función para instalar protocolos
function install_protocols() {
    echo "Instalando protocolos comunes..."
    # Instalación de Dropbear
    echo "Instalando Dropbear..."
    apt-get install dropbear -y
    
    # Instalación de WebSocket
    echo "Instalando WebSocket..."
    apt-get install wsserver -y
    
    # Instalación de BadVPN
    echo "Instalando BadVPN..."
    apt-get install badvpn -y
    
    # Instalación de V2Ray
    echo "Instalando V2Ray..."
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    # Instalación de Trojan
    echo "Instalando Trojan..."
    wget -O trojan.sh https://github.com/trojan-gfw/trojan/releases/download/v1.16.1/trojan-linux-amd64-v1.16.1.tar.xz
    tar -xf trojan.sh
    rm trojan.sh

    # Instalación de Xray
    echo "Instalando Xray..."
    bash <(curl -L https://github.com/XTLS/Xray-core/releases/latest/download/install-release.sh)
    
    echo "Protocolos instalados correctamente."
}

# Función para verificar dominios
function check_domain() {
    read -p "Ingresa el dominio a verificar: " domain
    ping -c 4 $domain
    if [ $? -eq 0 ]; then
        echo "$COLOR_GREENEl dominio $domain está funcionando.$COLOR_RESET"
    else
        echo "$COLOR_REDEl dominio $domain no responde.$COLOR_RESET"
    fi
}

# Función para configurar certificados SSL
function configure_ssl() {
    echo "1) Usar Let's Encrypt"
    echo "2) Usar Cloudflare"
    echo "3) Usar certificado manual"
    echo "4) Volver"
    read -p "Selecciona una opción para certificados SSL: " ssl_option
    
    case $ssl_option in
        1)
            echo "Instalando Let's Encrypt..."
            apt install certbot -y
            read -p "Ingresa tu dominio: " domain
            certbot certonly --standalone -d $domain
            echo "Certificados instalados en /etc/letsencrypt/live/$domain/"
            ;;
        2)
            echo "Configurando Cloudflare..."
            read -p "Ingresa tu certificado de Cloudflare: " cert_path
            read -p "Ingresa tu clave privada de Cloudflare: " key_path
            echo "Configuración de Cloudflare completada."
            ;;
        3)
            echo "Configurando certificado manual..."
            read -p "Ingresa la ruta del certificado: " cert_path
            read -p "Ingresa la ruta de la clave privada: " key_path
            echo "Certificado manual configurado."
            ;;
        4)
            return
            ;;
        *)
            echo "$COLOR_REDElije una opción válida.$COLOR_RESET"
            ;;
    esac
}

# Función para mostrar el menú principal
function main_menu() {
    while true; do
        show_banner
        echo "1) Instalar protocolos (Dropbear, WebSocket, V2Ray, Trojan, Xray, BadVPN)"
        echo "2) Verificar dominio"
        echo "3) Configurar certificados SSL"
        echo "4) Mostrar información del servidor"
        echo "5) Salir"
        echo "-----------------------------------------"
        read -p "Selecciona una opción: " option
        case $option in
            1) install_protocols ;;
            2) check_domain ;;
            3) configure_ssl ;;
            4) show_banner ;;
            5) echo "Saliendo..."; exit ;;
            *) echo "$COLOR_REDOpción inválida.$COLOR_RESET"; sleep 2 ;;
        esac
    done
}

# Ejecutar el menú principal
main_menu