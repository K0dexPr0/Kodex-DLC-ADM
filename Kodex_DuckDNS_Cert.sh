#!/usr/bin/env bash

###############################################################
#   Xray + DuckDNS + Let's Encrypt Automator                  #
#   Script creado por KodexDev - JoelDLC                      #
#   Elegante, automatizado y listo para producción            #
###############################################################

# Colores
NC="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "┌──────────────────────────────────────────────────────────┐"
  echo "│      Xray + DuckDNS + Let's Encrypt Automator           │"
  echo "│           Script creado por KodexDev - JoelDLC          │"
  echo "└──────────────────────────────────────────────────────────┘"
  echo -e "${NC}"
}

section() {
  echo -e "\n${YELLOW}${BOLD}▶ $1${NC}"
}

success() {
  echo -e "${GREEN}${BOLD}✔ $1${NC}"
}

error() {
  echo -e "${RED}${BOLD}✘ $1${NC}"
}

info() {
  echo -e "${CYAN}• $1${NC}"
}

pause() {
  read -rp $'\nPresiona ENTER para continuar... '
}

clear
banner

###############################################################
# 1. Verificar permisos
###############################################################
section "Comprobando permisos"

if [ "$EUID" -ne 0 ]; then
  error "Este script debe ejecutarse como root (sudo)."
  exit 1
else
  success "Permisos de root detectados."
fi

###############################################################
# 2. Preguntar datos DuckDNS
###############################################################
section "Datos de DuckDNS"

read -rp "Ingresa tu subdominio DuckDNS (sin .duckdns.org): " DUCK_SUB
if [ -z "$DUCK_SUB" ]; then
  error "No ingresaste subdominio."
  exit 1
fi

read -rsp "Ingresa tu token de DuckDNS: " DUCK_TOKEN
echo
if [ -z "$DUCK_TOKEN" ]; then
  error "No ingresaste token."
  exit 1
fi

FULL_DOMAIN="${DUCK_SUB}.duckdns.org"
info "Dominio completo: ${BOLD}${FULL_DOMAIN}${NC}"

###############################################################
# 3. Verificar/instalar Xray
###############################################################
section "Verificando instalación de Xray"

if command -v xray >/dev/null 2>&1; then
  success "Xray ya está instalado."
else
  info "Xray no está instalado."
  read -rp "¿Deseas instalar Xray ahora? (s/n): " INSTALL_XRAY

  if [[ "$INSTALL_XRAY" =~ ^[sS]$ ]]; then
    info "Instalando Xray..."
    bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    if [ $? -ne 0 ]; then
      error "Falló la instalación de Xray."
      exit 1
    fi
    success "Xray instalado correctamente."
  else
    error "No se puede continuar sin Xray."
    exit 1
  fi
fi

###############################################################
# 4. Verificar/instalar acme.sh
###############################################################
section "Verificando acme.sh"

if command -v acme.sh >/dev/null 2>&1; then
  ACME_BIN="$(command -v acme.sh)"
  success "acme.sh ya está instalado."
else
  info "Instalando acme.sh..."
  curl https://get.acme.sh | sh
  source ~/.bashrc
  ACME_BIN="$HOME/.acme.sh/acme.sh"
  success "acme.sh instalado."
fi

###############################################################
# 5. Forzar Let's Encrypt como CA
###############################################################
section "Configurando Let's Encrypt"

$ACME_BIN --set-default-ca --server letsencrypt >/dev/null 2>&1
success "Let's Encrypt configurado como CA por defecto."

###############################################################
# 6. Probar token DuckDNS
###############################################################
section "Probando token DuckDNS"

TEST_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCK_SUB}&token=${DUCK_TOKEN}&txt=acme-test&verbose=true")

echo -e "Respuesta: ${BOLD}${TEST_RESPONSE}${NC}"

if [[ "$TEST_RESPONSE" != *"OK"* ]]; then
  error "DuckDNS rechazó el token o el subdominio."
  exit 1
fi

success "Token DuckDNS válido."

###############################################################
# 7. Emitir certificado
###############################################################
section "Generando certificado SSL"

export DuckDNS_Token="${DUCK_TOKEN}"

$ACME_BIN --issue --dns dns_duckdns -d "${FULL_DOMAIN}"
if [ $? -ne 0 ]; then
  error "Falló la emisión del certificado."
  exit 1
fi

success "Certificado emitido correctamente."

###############################################################
# 8. Instalar certificado en Xray
###############################################################
section "Instalando certificado en Xray"

CRT_PATH="/etc/xray/server.crt"
KEY_PATH="/etc/xray/server.key"

mkdir -p /etc/xray

$ACME_BIN --install-cert -d "${FULL_DOMAIN}" \
  --key-file "${KEY_PATH}" \
  --fullchain-file "${CRT_PATH}" \
  --reloadcmd "systemctl restart xray"

success "Certificado instalado."

###############################################################
# 9. Obtener UUID desde Xray
###############################################################
section "Obteniendo UUID"

UUID=$(xray uuid 2>/dev/null)

if [ -z "$UUID" ]; then
  error "No se pudo obtener UUID."
  exit 1
fi

success "UUID detectado: ${UUID}"

###############################################################
# 10. Generar VLESS link
###############################################################
section "Generando enlace VLESS"

VLESS_LINK="vless://${UUID}@${FULL_DOMAIN}:443?encryption=none&security=tls&type=tcp&flow=xtls-rprx-vision&sni=${FULL_DOMAIN}#${DUCK_SUB}-Xray"

success "VLESS link generado:"
echo -e "${GREEN}${BOLD}${VLESS_LINK}${NC}"

###############################################################
# 11. Resumen final
###############################################################
section "Resumen final"

echo -e "${CYAN}Dominio: ${BOLD}${FULL_DOMAIN}${NC}"
echo -e "${CYAN}Certificado: ${BOLD}${CRT_PATH}${NC}"
echo -e "${CYAN}Clave privada: ${BOLD}${KEY_PATH}${NC}"
echo -e "${CYAN}UUID: ${BOLD}${UUID}${NC}"
echo -e "${CYAN}VLESS Link: ${BOLD}${VLESS_LINK}${NC}"

echo -e "\n${GREEN}${BOLD}Todo listo. Tu VPS está configurado con Xray + DuckDNS + TLS.${NC}"
pause
clear
banner
success "Proceso completado. Disfruta tu red privada."
echo