!/usr/bin/env bash

#########################################################

KodexDev – DuckDNS + Xray + TLS Installer (Whiptail)      #

Versión monolítica con menú gráfico                       #

Autor: KodexDev - JoelDLC                                 #

#########################################################

===========================

Configuración básica

===========================
set -o errexit
set -o pipefail
set -o nounset

===========================

Colores

===========================
NC="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BOLD="\e[1m"

===========================

Funciones básicas de mensajes

===========================
log_info() {
  echo -e "${CYAN}[INFO]${NC} $*"
}

log_ok() {
  echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

===========================

Verificar root

===========================
require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root."
    exit 1
  fi
}

require_root

===========================

Detección de gestor de paquetes

===========================
detectpackagemanager() {
  if command -v apt >/dev/null 2>&1; then
    echo "apt"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo "unknown"
  fi
}

PKGMANAGER="$(detectpackage_manager)"

===========================

Verificar/instalar whiptail (ANTES de usarlo)

===========================
ensure_whiptail() {
  if command -v whiptail >/dev/null 2>&1; then
    log_ok "whiptail ya está instalado."
    return 0
  fi

  log_warn "whiptail no está instalado en el sistema."

  echo
  echo -e "${BOLD}Se requiere 'whiptail' para mostrar el menú gráfico.${NC}"
  read -rp "¿Desea instalar whiptail ahora? (s/n): " INSTALL_WT

  if [[ ! "$INSTALL_WT" =~ ^[sS]$ ]]; then
    log_error "No se puede continuar sin whiptail. Saliendo."
    exit 1
  fi

  case "$PKG_MANAGER" in
    apt|apt-get)
      loginfo "Instalando whiptail con $PKGMANAGER..."
      $PKG_MANAGER update -y >/dev/null 2>&1 || true
      $PKG_MANAGER install -y whiptail >/dev/null 2>&1
      ;;
    yum|dnf)
      loginfo "Instalando newt (whiptail) con $PKGMANAGER..."
      $PKG_MANAGER install -y newt >/dev/null 2>&1
      ;;
    apk)
      log_info "Instalando newt (whiptail) con apk..."
      apk update >/dev/null 2>&1 || true
      apk add newt >/dev/null 2>&1
      ;;
    *)
      log_error "No se pudo detectar un gestor de paquetes compatible para instalar whiptail."
      exit 1
      ;;
  esac

  if command -v whiptail >/dev/null 2>&1; then
    log_ok "whiptail instalado correctamente."
  else
    log_error "Falló la instalación de whiptail."
    exit 1
  fi
}

ensure_whiptail

===========================

Variables globales

===========================
LANG_CHOICE="ES"
CARRIER="Xray-Network"
CONFIG_FILE=""
FULL_DOMAIN=""
DUCK_SUB=""
DUCK_TOKEN=""
XRAY_DETECTED="no"
UUID_GENERATED=""
CERT_CRT="/etc/xray/server.crt"
CERT_KEY="/etc/xray/server.key"

===========================

Función de banner con whiptail

===========================
show_banner() {
  whiptail --title "KodexDev - DuckDNS + Xray Installer" \
    --msgbox "Bienvenido al instalador gráfico de DuckDNS + Xray + TLS\n\nAutor: KodexDev - JoelDLC" 10 60
}

show_banner

===========================

Selección de idioma

===========================
select_language() {
  local CHOICE
  CHOICE=$(whiptail --title "Idioma / Language / Idioma" --menu "Seleccione el idioma:" 15 60 3 \
    "1" "Español" \
    "2" "English" \
    "3" "Português" 3>&1 1>&2 2>&3) || true

  case "$CHOICE" in
    1) LANG_CHOICE="ES" ;;
    2) LANG_CHOICE="EN" ;;
    3) LANG_CHOICE="PT" ;;
    *) LANG_CHOICE="ES" ;;
  esac
}

select_language

===========================

Función para obtener texto según idioma (básico)

===========================
t() {
  local key="$1"
  case "$LANG_CHOICE" in
    ES)
      case "$key" in
        main_title) echo "KodexDev - DuckDNS + Xray + TLS" ;;
        main_menu) echo "Seleccione una opción:" ;;
        opt_duckdns) echo "Configurar DuckDNS" ;;
        opt_cert) echo "Emitir certificado SSL" ;;
        opt_tls) echo "Actualizar TLS en config.json" ;;
        opt_vless) echo "Generar enlace VLESS" ;;
        opt_advanced) echo "Configuración avanzada" ;;
        opt_exit) echo "Salir" ;;
        carrier_title) echo "Seleccione su operadora" ;;
        carrier_1) echo "Claro Dominicana" ;;
        carrier_2) echo "Viva RD" ;;
        carrier_3) echo "Altice Dominicana" ;;
        carrier_4) echo "Otra / Genérica" ;;
        *) echo "$key" ;;
      esac
      ;;
    EN)
      case "$key" in
        main_title) echo "KodexDev - DuckDNS + Xray + TLS" ;;
        main_menu) echo "Select an option:" ;;
        opt_duckdns) echo "Configure DuckDNS" ;;
        opt_cert) echo "Issue SSL certificate" ;;
        opt_tls) echo "Update TLS in config.json" ;;
        opt_vless) echo "Generate VLESS link" ;;
        opt_advanced) echo "Advanced settings" ;;
        opt_exit) echo "Exit" ;;
        carrier_title) echo "Select your carrier" ;;
        carrier_1) echo "Claro Dominicana" ;;
        carrier_2) echo "Viva RD" ;;
        carrier_3) echo "Altice Dominicana" ;;
        carrier_4) echo "Other / Generic" ;;
        *) echo "$key" ;;
      esac
      ;;
    PT)
      case "$key" in
        main_title) echo "KodexDev - DuckDNS + Xray + TLS" ;;
        main_menu) echo "Selecione uma opção:" ;;
        opt_duckdns) echo "Configurar DuckDNS" ;;
        opt_cert) echo "Emitir certificado SSL" ;;
        opt_tls) echo "Atualizar TLS no config.json" ;;
        opt_vless) echo "Gerar link VLESS" ;;
        opt_advanced) echo "Configurações avançadas" ;;
        opt_exit) echo "Sair" ;;
        carrier_title) echo "Selecione sua operadora" ;;
        carrier_1) echo "Claro Dominicana" ;;
        carrier_2) echo "Viva RD" ;;
        carrier_3) echo "Altice Dominicana" ;;
        carrier_4) echo "Outra / Genérica" ;;
        *) echo "$key" ;;
      esac
      ;;
    *)
      echo "$key"
      ;;
  esac
}

===========================

Selección de operadora

===========================
select_carrier() {
  local CHOICE
  CHOICE=$(whiptail --title "$(t carriertitle)" --menu "$(t carriertitle)" 15 60 4 \
    "1" "$(t carrier_1)" \
    "2" "$(t carrier_2)" \
    "3" "$(t carrier_3)" \
    "4" "$(t carrier_4)" 3>&1 1>&2 2>&3) || true

  case "$CHOICE" in
    1) CARRIER="Claro-Dominicana" ;;
    2) CARRIER="Viva-RD" ;;
    3) CARRIER="Altice-Dominicana" ;;
    4|*) CARRIER="Xray-Network" ;;
  esac
}

select_carrier

===== FIN BLOQUE 1/12 =====

# ===========================
# Detección de Xray
# ===========================
detect_xray() {
  if command -v xray >/dev/null 2>&1; then
    XRAY_DETECTED="yes"
    return 0
  fi

  # Buscar en rutas comunes
  for path in /usr/bin/xray /usr/local/bin/xray /usr/sbin/xray; do
    if [ -f "$path" ]; then
      XRAY_DETECTED="yes"
      return 0
    fi
  done

  XRAY_DETECTED="no"
  return 1
}

# ===========================
# Verificar estado de Xray
# ===========================
check_xray_status() {
  if systemctl is-active --quiet xray; then
    echo "active"
  else
    echo "inactive"
  fi
}

# ===========================
# Instalación de Xray (si el usuario acepta)
# ===========================
install_xray() {
  whiptail --title "Instalando Xray" --infobox "Instalando Xray...\nEsto puede tardar unos segundos." 10 60
  bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) >/dev/null 2>&1

  sleep 2

  if command -v xray >/dev/null 2>&1; then
    whiptail --title "Xray instalado" --msgbox "Xray se instaló correctamente." 10 60
    XRAY_DETECTED="yes"
  else
    whiptail --title "Error" --msgbox "No se pudo instalar Xray." 10 60
    XRAY_DETECTED="no"
  fi
}

# ===========================
# Función que asegura que Xray esté instalado
# ===========================
ensure_xray() {
  detect_xray

  if [ "$XRAY_DETECTED" = "yes" ]; then
    return 0
  fi

  # Preguntar al usuario
  if whiptail --title "Xray no encontrado" --yesno "Xray no está instalado.\n¿Desea instalarlo ahora?" 10 60; then
    install_xray
  else
    whiptail --title "Xray requerido" --msgbox "No se puede continuar sin Xray." 10 60
    return 1
  fi
}

# Ejecutar verificación inicial
ensure_xray

# ===========================
# Buscar archivo config.json
# ===========================
find_config_file() {
  local paths=(
    "/etc/xray/config.json"
    "/usr/local/etc/xray/config.json"
    "/etc/xray/main.json"
    "/etc/xray/xray.json"
  )

  local found=()

  for p in "${paths[@]}"; do
    if [ -f "$p" ]; then
      found+=("$p")
    fi
  done

  if [ ${#found[@]} -eq 0 ]; then
    CONFIG_FILE=""
    return 1
  fi

  if [ ${#found[@]} -eq 1 ]; then
    CONFIG_FILE="${found[0]}"
    return 0
  fi

  # Si hay múltiples archivos, mostrar menú
  local menu_items=()
  local index=1

  for f in "${found[@]}"; do
    menu_items+=("$index" "$f")
    index=$((index+1))
  done

  local choice
  choice=$(whiptail --title "Seleccionar config.json" \
    --menu "Se encontraron múltiples archivos config.json.\nSeleccione uno:" \
    20 70 10 \
    "${menu_items[@]}" \
    3>&1 1>&2 2>&3) || true

  if [ -z "$choice" ]; then
    CONFIG_FILE=""
    return 1
  fi

  CONFIG_FILE="${found[$((choice-1))]}"
  return 0
}

# ===========================
# Validar JSON
# ===========================
validate_json() {
  if ! command -v jq >/dev/null 2>&1; then
    case "$PKG_MANAGER" in
      apt|apt-get) $PKG_MANAGER install -y jq >/dev/null 2>&1 ;;
      yum|dnf) $PKG_MANAGER install -y jq >/dev/null 2>&1 ;;
      apk) apk add jq >/dev/null 2>&1 ;;
    esac
  fi

  if jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# ===========================
# Crear backup seguro
# ===========================
backup_config() {
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup="${CONFIG_FILE}.backup-${timestamp}"

  cp "$CONFIG_FILE" "$backup"
}

# ===========================
# Asegurar que config.json exista
# ===========================
ensure_config_file() {
  find_config_file

  if [ -z "$CONFIG_FILE" ]; then
    whiptail --title "config.json no encontrado" \
      --msgbox "No se encontró ningún archivo config.json.\nDebe crear uno antes de continuar." 10 60
    return 1
  fi

  # Validar JSON
  if ! validate_json; then
    whiptail --title "Error en JSON" \
      --msgbox "El archivo config.json contiene errores de sintaxis.\nCorríjalo antes de continuar." 10 60
    return 1
  fi

  return 0
}

# Ejecutar detección inicial
ensure_config_file

# ===========================
# Menú principal
# ===========================
main_menu() {
  while true; do
    CHOICE=$(whiptail --title "$(t main_title)" --menu "$(t main_menu)" 20 70 10 \
      "1" "$(t opt_duckdns)" \
      "2" "$(t opt_cert)" \
      "3" "$(t opt_tls)" \
      "4" "$(t opt_vless)" \
      "5" "$(t opt_advanced)" \
      "6" "$(t opt_exit)" \
      3>&1 1>&2 2>&3) || exit 0

    case "$CHOICE" in
      1)
        configure_duckdns
        ;;
      2)
        issue_certificate
        ;;
      3)
        update_tls
        ;;
      4)
        generate_vless
        ;;
      5)
        advanced_menu
        ;;
      6)
        whiptail --title "Salir" --msgbox "Gracias por usar el instalador KodexDev – JoelDLC." 10 60
        exit 0
        ;;
    esac
  done
}

# ===========================
# Menú avanzado
# ===========================
advanced_menu() {
  while true; do
    local CHOICE
    CHOICE=$(whiptail --title "Configuración avanzada" --menu "Opciones avanzadas:" 20 70 12 \
      "1" "Ver estado de Xray" \
      "2" "Ver logs de Xray" \
      "3" "Ver certificado actual" \
      "4" "Regenerar certificado" \
      "5" "Ver/editar config.json" \
      "6" "Detectar inbounds (TCP/WS/VLESS/VMESS)" \
      "7" "Reiniciar Xray" \
      "8" "Información del sistema" \
      "9" "Modo experto" \
      "10" "Volver al menú principal" \
      3>&1 1>&2 2>&3) || return 0

    case "$CHOICE" in
      1)
        show_xray_status
        ;;
      2)
        show_xray_logs
        ;;
      3)
        show_certificate_info
        ;;
      4)
        regenerate_certificate
        ;;
      5)
        edit_config_json
        ;;
      6)
        detect_inbounds
        ;;
      7)
        restart_xray
        ;;
      8)
        system_info
        ;;
      9)
        expert_mode
        ;;
      10)
        return 0
        ;;
    esac
  done
}

# ===========================
# Modo experto
# ===========================
expert_mode() {
  while true; do
    local CHOICE
    CHOICE=$(whiptail --title "Modo experto" --menu "Opciones avanzadas de administración:" 20 70 10 \
      "1" "Editar config.json con nano" \
      "2" "Editar config.json con vi" \
      "3" "Validar JSON" \
      "4" "Ver puertos abiertos" \
      "5" "Ver procesos Xray" \
      "6" "Volver" \
      3>&1 1>&2 2>&3) || return 0

    case "$CHOICE" in
      1)
        nano "$CONFIG_FILE"
        ;;
      2)
        vi "$CONFIG_FILE"
        ;;
      3)
        if validate_json; then
          whiptail --title "Validación JSON" --msgbox "El archivo JSON es válido." 10 60
        else
          whiptail --title "Validación JSON" --msgbox "El archivo JSON contiene errores." 10 60
        fi
        ;;
      4)
        ss -tulpn | whiptail --title "Puertos abiertos" --textbox - 25 90
        ;;
      5)
        ps aux | grep xray | whiptail --title "Procesos Xray" --textbox - 25 90
        ;;
      6)
        return 0
        ;;
    esac
  done
}

# ===========================
# Configurar DuckDNS
# ===========================
configure_duckdns() {
  # Pedir subdominio
  DUCK_SUB=$(whiptail --title "DuckDNS" --inputbox "Ingrese el subdominio DuckDNS (sin .duckdns.org):" 10 60 3>&1 1>&2 2>&3) || return 0

  if [ -z "$DUCK_SUB" ]; then
    whiptail --title "Error" --msgbox "Debe ingresar un subdominio válido." 10 60
    return 1
  fi

  # Pedir token
  DUCK_TOKEN=$(whiptail --title "DuckDNS" --passwordbox "Ingrese el token de DuckDNS:" 10 60 3>&1 1>&2 2>&3) || return 0

  if [ -z "$DUCK_TOKEN" ]; then
    whiptail --title "Error" --msgbox "Debe ingresar un token válido." 10 60
    return 1
  fi

  FULL_DOMAIN="${DUCK_SUB}.duckdns.org"

  # Validar token
  whiptail --title "Validando" --infobox "Validando token DuckDNS..." 10 60
  sleep 1

  local RESPONSE
  RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCK_SUB}&token=${DUCK_TOKEN}&txt=kodexdev&verbose=true")

  if [[ "$RESPONSE" != *"OK"* ]]; then
    whiptail --title "Token inválido" --msgbox "DuckDNS rechazó el token.\nRespuesta:\n$RESPONSE" 12 60
    return 1
  fi

  whiptail --title "DuckDNS configurado" --msgbox "DuckDNS configurado correctamente.\nDominio: ${FULL_DOMAIN}" 10 60
}


# ===========================
# Instalar ACME si no existe
# ===========================
install_acme() {
  if command -v acme.sh >/dev/null 2>&1; then
    return 0
  fi

  whiptail --title "Instalando ACME" --infobox "Instalando acme.sh...\nEsto puede tardar unos segundos." 10 60
  curl -s https://get.acme.sh | sh >/dev/null 2>&1
  sleep 2

  if ! command -v acme.sh >/dev/null 2>&1; then
    whiptail --title "Error" --msgbox "No se pudo instalar acme.sh." 10 60
    return 1
  fi

  return 0
}

# ===========================
# Emitir certificado SSL
# ===========================
issue_certificate() {
  if [ -z "$FULL_DOMAIN" ] || [ -z "$DUCK_TOKEN" ]; then
    whiptail --title "DuckDNS requerido" --msgbox "Debe configurar DuckDNS antes de emitir el certificado." 10 60
    return 1
  fi

  install_acme

  whiptail --title "Certificado SSL" --infobox "Generando certificado SSL para:\n${FULL_DOMAIN}\n\nEsto puede tardar 20–40 segundos..." 12 60
  sleep 2

  export DuckDNS_Token="${DUCK_TOKEN}"

  acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1

  acme.sh --issue --dns dns_duckdns -d "${FULL_DOMAIN}" >/dev/null 2>&1

  if [ $? -ne 0 ]; then
    whiptail --title "Error" --msgbox "No se pudo emitir el certificado SSL.\nVerifique su token y dominio." 12 60
    return 1
  fi

  mkdir -p /etc/xray

  acme.sh --install-cert -d "${FULL_DOMAIN}" \
    --key-file "$CERT_KEY" \
    --fullchain-file "$CERT_CRT" \
    --reloadcmd "systemctl restart xray" >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    whiptail --title "Certificado instalado" --msgbox "Certificado SSL emitido e instalado correctamente.\n\nRuta:\n$CERT_CRT" 12 60
  else
    whiptail --title "Error" --msgbox "El certificado se emitió, pero no se pudo instalar." 12 60
  fi
}

# ===========================
# Ver certificado actual
# ===========================
show_certificate_info() {
  if [ ! -f "$CERT_CRT" ]; then
    whiptail --title "Sin certificado" --msgbox "No existe un certificado instalado." 10 60
    return 1
  fi

  openssl x509 -in "$CERT_CRT" -noout -text | whiptail --title "Certificado SSL" --textbox - 25 90
}

# ===========================
# Regenerar certificado
# ===========================
regenerate_certificate() {
  if whiptail --title "Regenerar certificado" --yesno "¿Desea regenerar el certificado SSL?" 10 60; then
    issue_certificate
  fi
}

# ===========================
# Detectar inbounds (TCP/WS/VLESS/VMESS)
# ===========================
detect_inbounds() {
  ensure_config_file || return 1

  local inbound_list
  inbound_list=$(jq -r '.inbounds[].protocol' "$CONFIG_FILE" 2>/dev/null)

  if [ -z "$inbound_list" ]; then
    whiptail --title "Inbounds" --msgbox "No se encontraron inbounds en config.json." 10 60
    return 1
  fi

  echo "$inbound_list" | whiptail --title "Inbounds detectados" --textbox - 20 70
}

# ===========================
# Actualizar TLS en config.json
# ===========================
update_tls() {
  ensure_config_file || return 1

  if [ ! -f "$CERT_CRT" ] || [ ! -f "$CERT_KEY" ]; then
    whiptail --title "Certificado requerido" --msgbox "Debe emitir un certificado SSL antes de actualizar TLS." 10 60
    return 1
  fi

  backup_config

  whiptail --title "Actualizando TLS" --infobox "Actualizando configuración TLS en config.json..." 10 60
  sleep 1

  # Insertar TLS en todos los inbounds que lo soporten
  local NEW_JSON
  NEW_JSON=$(jq \
    --arg crt "$CERT_CRT" \
    --arg key "$CERT_KEY" \
    '
    .inbounds |= map(
      if .streamSettings? != null then
        .streamSettings.security = "tls" |
        .streamSettings.tlsSettings = {
          "certificates": [
            {
              "certificateFile": $crt,
              "keyFile": $key
            }
          ]
        }
      else
        .
      end
    )
    ' "$CONFIG_FILE" 2>/dev/null)

  if [ -z "$NEW_JSON" ]; then
    whiptail --title "Error" --msgbox "No se pudo modificar el JSON." 10 60
    return 1
  fi

  echo "$NEW_JSON" > "$CONFIG_FILE"

  # Validar JSON final
  if ! validate_json; then
    whiptail --title "Error JSON" --msgbox "El archivo JSON quedó inválido.\nSe restaurará el backup." 12 60
    cp "${CONFIG_FILE}.backup-"* "$CONFIG_FILE"
    return 1
  fi

  systemctl restart xray >/dev/null 2>&1

  whiptail --title "TLS actualizado" --msgbox "TLS actualizado correctamente en config.json." 10 60
}

# ===========================
# Obtener UUID del inbound VLESS
# ===========================
get_vless_uuid() {
  ensure_config_file || return 1

  local uuid
  uuid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[0].id' "$CONFIG_FILE" 2>/dev/null)

  if [ -z "$uuid" ] || [ "$uuid" = "null" ]; then
    return 1
  fi

  UUID_GENERATED="$uuid"
  return 0
}

# ===========================
# Obtener puerto del inbound VLESS
# ===========================
get_vless_port() {
  ensure_config_file || return 1

  local port
  port=$(jq -r '.inbounds[] | select(.protocol=="vless") | .port' "$CONFIG_FILE" 2>/dev/null)

  if [ -z "$port" ] || [ "$port" = "null" ]; then
    return 1
  fi

  echo "$port"
  return 0
}

# ===========================
# Obtener path si es WebSocket
# ===========================
get_vless_path() {
  ensure_config_file || return 1

  local path
  path=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.wsSettings.path' "$CONFIG_FILE" 2>/dev/null)

  if [ -z "$path" ] || [ "$path" = "null" ]; then
    echo "/"
  else
    echo "$path"
  fi
}

# ===========================
# Generar enlace VLESS
# ===========================
generate_vless() {
  ensure_config_file || return 1

  if [ -z "$FULL_DOMAIN" ]; then
    whiptail --title "DuckDNS requerido" --msgbox "Debe configurar DuckDNS antes de generar el enlace VLESS." 10 60
    return 1
  fi

  if ! get_vless_uuid; then
    whiptail --title "Error" --msgbox "No se encontró UUID VLESS en config.json." 10 60
    return 1
  fi

  local PORT
  PORT=$(get_vless_port)

  if [ -z "$PORT" ]; then
    whiptail --title "Error" --msgbox "No se encontró puerto VLESS en config.json." 10 60
    return 1
  fi

  local PATH
  PATH=$(get_vless_path)

  local VLESS_LINK="vless://${UUID_GENERATED}@${FULL_DOMAIN}:${PORT}?security=tls&encryption=none&alpn=h2,http/1.1&type=ws&host=${FULL_DOMAIN}&path=${PATH}#${CARRIER}"

  echo "$VLESS_LINK" | whiptail --title "Enlace VLESS" --textbox - 15 90
}

# ===========================
# Mostrar estado de Xray
# ===========================
show_xray_status() {
  local STATUS
  STATUS=$(systemctl status xray 2>&1)

  echo "$STATUS" | whiptail --title "Estado de Xray" --textbox - 25 90
}

# ===========================
# Mostrar logs de Xray
# ===========================
show_xray_logs() {
  journalctl -u xray --no-pager -n 200 2>&1 | whiptail --title "Logs de Xray" --textbox - 25 90
}

# ===========================
# Reiniciar Xray
# ===========================
restart_xray() {
  systemctl restart xray >/dev/null 2>&1

  if systemctl is-active --quiet xray; then
    whiptail --title "Xray reiniciado" --msgbox "Xray se reinició correctamente." 10 60
  else
    whiptail --title "Error" --msgbox "Xray no pudo reiniciarse.\nRevise los logs." 10 60
  fi
}

# ===========================
# Información del sistema
# ===========================
system_info() {
  local INFO=""

  INFO+="Hostname: $(hostname)\n"
  INFO+="Sistema: $(uname -a)\n"
  INFO+="CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2)\n"
  INFO+="RAM total: $(grep MemTotal /proc/meminfo | awk '{print $2/1024 \" MB\"}')\n"
  INFO+="RAM libre: $(grep MemAvailable /proc/meminfo | awk '{print $2/1024 \" MB\"}')\n"
  INFO+="Uptime: $(uptime -p)\n"
  INFO+="IP pública: $(curl -s ifconfig.me)\n"
  INFO+="IP local: $(hostname -I)\n"

  echo -e "$INFO" | whiptail --title "Información del sistema" --textbox - 25 90
}

# ===========================
# Editar config.json
# ===========================
edit_config_json() {
  ensure_config_file || return 1

  nano "$CONFIG_FILE"
}
# ===========================
# Inicio del script
# ===========================
start_script() {
  whiptail --title "KodexDev – Instalador" \
    --msgbox "El entorno gráfico está listo.\n\nPresione OK para continuar al menú principal." 10 60

  main_menu
}

# Ejecutar script
start_script

# ===========================
# Fin del script
# ===========================
exit 0