#!/bin/bash
# Script de Gestión VPS - Kodex DLC-ADM

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Función para mostrar el banner
function show_banner() {
    echo -e "${BLUE}========================================="
    echo -e "       VPS Manager Script v1.0"
    echo -e "          Kodex DLC-ADM"
    echo -e "========================================="
    echo -e "Servidor: $(curl -s ifconfig.me)"
    echo -e "Fecha: $(date)"
    echo -e "RAM: $(free -h | awk '/^Mem/ {print $3 "/" $2}')"
    echo -e "Disco: $(df -h / | awk '/\// {print $3 "/" $2}')"
    echo -e "Swap: $(free -h | awk '/^Swap/ {print $3 "/" $2}')"
    echo -e "Créditos: Joel DLC"
    echo -e "${BLUE}-----------------------------------------${NC}"
}

# Función para mostrar protocolos y puertos activos
function show_active_protocols() {
    echo -e "${GREEN}Protocolos y Puertos Activos:${NC}"
    if pgrep dropbear > /dev/null; then
        echo -e "- Dropbear: Activo en el puerto 22"
    else
        echo -e "- Dropbear: No instalado"
    fi
    if netstat -tuln | grep -q ':80'; then
        echo -e "- WebSocket: Activo en el puerto 80"
    else
        echo -e "- WebSocket: No instalado"
    fi
    if netstat -tuln | grep -q ':443'; then
        echo -e "- SSL: Activo en el puerto 443"
    else
        echo -e "- SSL: No instalado"
    fi
    if pgrep v2ray > /dev/null; then
        echo -e "- V2Ray: Activo"
    else
        echo -e "- V2Ray: No instalado"
    fi
    if pgrep trojan > /dev/null; then
        echo -e "- Trojan: Activo"
    else
        echo -e "- Trojan: No instalado"
    fi
    if pgrep xray > /dev/null; then
        echo -e "- Xray: Activo"
    else
        echo -e "- Xray: No instalado"
    fi
    echo -e "-----------------------------------------"
}

# Función para instalar un protocolo
function install_protocol() {
    echo -e "${GREEN}Selecciona el protocolo para instalar:${NC}"
    echo -e "1) Dropbear"
    echo -e "2) WebSocket"
    echo -e "3) SSL"
    echo -e "4) V2Ray"
    echo -e "5) Trojan"
    echo -e "6) Xray"
    echo -e "7) BadVPN"
    read -p "Opción: " option
    case $option in
        1)
            echo -e "${BLUE}Instalando Dropbear...${NC}"
            apt-get install dropbear -y
            systemctl enable dropbear
            systemctl start dropbear
            ;;
        2)
            echo -e "${BLUE}Instalando WebSocket...${NC}"
            # Comandos para instalar WebSocket
            ;;
        3)
            echo -e "${BLUE}Instalando SSL...${NC}"
            # Comandos para instalar SSL
            ;;
        4)
            echo -e "${BLUE}Instalando V2Ray...${NC}"
            source <(curl -sL https://multi.netlify.app/v2ray.sh)
            ;;
        5)
            echo -e "${BLUE}Instalando Trojan...${NC}"
            # Comandos para instalar Trojan
            ;;
        6)
            echo -e "${BLUE}Instalando Xray...${NC}"
            source <(curl -sL https://multi.netlify.app/v2ray.sh)
            ;;
        7)
            echo -e "${BLUE}Instalando BadVPN...${NC}"
            # Comandos para instalar BadVPN
            ;;
        *)
            echo -e "${RED}Opción inválida.${NC}"
            ;;
    esac
}

# Función para configurar certificados SSL
function configure_ssl() {
    echo -e "${GREEN}Selecciona una opción para configurar certificados:${NC}"
    echo -e "1) Let's Encrypt"
    echo -e "2) Cloudflare"
    echo -e "3) Certificado manual (especificar ruta)"
    read -p "Opción: " option
    case $option in
        1)
            echo -e "${BLUE}Configurando Let's Encrypt...${NC}"
            apt-get install certbot -y
            certbot certonly --standalone
            ;;
        2)
            echo -e "${BLUE}Configurando Cloudflare...${NC}"
            # Comandos para configurar Cloudflare
            ;;
        3)
            read -p "Especifica la ruta del certificado: " cert_path
            echo -e "Ruta configurada: $cert_path"
            ;;
        *)
            echo -e "${RED}Opción inválida.${NC}"
            ;;
    esac
}

# Función principal del menú
function main_menu() {
    while true; do
        clear
        show_banner
        show_active_protocols
        echo -e "${GREEN}Opciones:${NC}"
        echo -e "1) Instalar protocolos"
        echo -e "2) Configurar certificados SSL"
        echo -e "3) Verificar dominio"
        echo -e "4) Mostrar información del servidor"
        echo -e "5) Salir"
        read -p "Selecciona una opción: " option
        case $option in
            1)
                install_protocol
                ;;
            2)
                configure_ssl
                ;;
            3)
                echo -e "${BLUE}Verificando dominios...${NC}"
                # Comandos para verificar dominios
                ;;
            4)
                show_banner
                read -p "Presiona Enter para volver al menú principal..."
                ;;
            5)
                echo -e "${GREEN}Saliendo...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida.${NC}"
                ;;
        esac
    done
}

# Ejecutar el menú principal
main_menu
