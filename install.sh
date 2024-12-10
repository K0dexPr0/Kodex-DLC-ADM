#!/bin/bash

# Colores y estilos
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

# Animación de carga
loading() {
    for i in {1..3}; do
        echo -ne "${CYAN}Descargando JDLC script${RESET}."
        sleep 0.5
        echo -ne "."
        sleep 0.5
        echo -ne "."
        sleep 0.5
        echo -ne "\r                          \r" # Limpia la línea
    done
}

# Banner
echo -e "${CYAN}${BOLD}***********************************************"
echo -e "*        Instalador Kodex DLC Automático para VPS       *"
echo -e "***********************************************${RESET}"

# Descargar el script desde GitHub
loading
wget -O /tmp/script.sh https://raw.githubusercontent.com/usuario/tu-repositorio/master/script.sh

# Verificar si la descarga fue exitosa
if [[ $? -ne 0 ]]; then
    echo -e "${RED}${BOLD}Error: No se pudo descargar el script Kodex DLC.${RESET}"
    exit 1
fi

# Dar permisos de ejecución al script
chmod +x /tmp/script.sh

# Ejecutar el script
echo -e "${GREEN}${BOLD}Ejecutando el script descargado...${RESET}"
/tmp/script.sh
