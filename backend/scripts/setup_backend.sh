#!/bin/bash

# ==========================================
# PALETA DE CORES NEON (ANSI Escape Codes)
# ==========================================
NEON_CYAN='\033[1;36m'
NEON_MAGENTA='\033[1;35m'
NEON_GREEN='\033[1;32m'
NEON_YELLOW='\033[1;33m'
NEON_RED='\033[1;31m'
RESET='\033[0m'

# ==========================================
# FUNÇÕES DO HUD
# ==========================================
draw_header() {
    clear
    echo -e "${NEON_CYAN}╔═════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${NEON_CYAN}║ ${NEON_MAGENTA}   ___  _   _ ___  ____  ___  ___  __  _ _____                      ${NEON_CYAN}║${RESET}"
    echo -e "${NEON_CYAN}║ ${NEON_MAGENTA}  / __>| | | | . >| __> | . \| . \|  \| | . \                     ${NEON_CYAN}║${RESET}"
    echo -e "${NEON_CYAN}║ ${NEON_MAGENTA}  \__ \ \ \/ /| . \| _>  |   /|   /| | ' || |/                      ${NEON_CYAN}║${RESET}"
    echo -e "${NEON_CYAN}║ ${NEON_MAGENTA}  <___/  | | |___/|___> |_\_\|_\_\|_|\_||___/                      ${NEON_CYAN}║${RESET}"
    echo -e "${NEON_CYAN}║ ${NEON_MAGENTA}         _/                                                         ${NEON_CYAN}║${RESET}"
    echo -e "${NEON_CYAN}╠═════════════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${NEON_CYAN}║ ${NEON_YELLOW}SYSTEM INITIALIZATION SEQUENCE :: BUILD 47.9.2${NEON_CYAN}                      ║${RESET}"
    echo -e "${NEON_CYAN}╚═════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    echo -e "${NEON_CYAN}[${NEON_MAGENTA} SYS_OPS ${NEON_CYAN}] ${NEON_YELLOW}>> ${RESET}$1"
    sleep 0.5
}

print_success() {
    echo -e "          ${NEON_CYAN}[${NEON_GREEN} OK ${NEON_CYAN}] ${NEON_GREEN}$1${RESET}"
    echo -e "${NEON_CYAN}-----------------------------------------------------------------------${RESET}"
    sleep 0.5
}

print_error() {
    echo -e "          ${NEON_CYAN}[${NEON_RED} FAIL ${NEON_CYAN}] ${NEON_RED}$1${RESET}"
    exit 1
}

# ==========================================
# EXECUÇÃO DO PIPELINE
# ==========================================
draw_header

# 1. Checagem de Parâmetro
print_step "SCANNING DIRECTORY TARGET..."
if [ -z "$1" ]; then
    print_error "MISSING PARAMETER. USAGE: $0 <directory_path>"
fi
TARGET_DIR="$1"
print_success "TARGET ACQUIRED: $TARGET_DIR"

# 2. Acesso ao Diretório
print_step "MOUNTING TARGET DIRECTORY..."
cd "$TARGET_DIR" || print_error "ACCESS DENIED OR DIRECTORY NOT FOUND."
print_success "DIRECTORY MOUNTED COMPLETED."

# 3. Criação do VENV
print_step "GENERATING KERNEL (.VENV)..."
echo -e "          ${NEON_CYAN}[${NEON_MAGENTA}██████████░░░░░░░░${NEON_CYAN}]${RESET} PROCESSING..."
python3 -m venv .venv
print_success "VENV KERNEL ESTABLISHED."

# 4. Ativação do VENV
print_step "ACTIVATING ISOLATED INSTANCE..."
source .venv/bin/activate
print_success "INSTANCE ACTIVE: .venv/bin/activate"

# 5. Instalação de Dependências
print_step "FETCHING EXTERNAL LIBRARIES (requirements.txt)..."
echo -e "          ${NEON_CYAN}[${NEON_MAGENTA}██████████████████${NEON_CYAN}]${RESET} DOWNLOADING PACKAGES..."
pip install -r requirements.txt > /dev/null 2>&1
print_success "DEPENDENCIES INSTALLED SUCCESSFULLY."

# 6. Configuração de Variáveis de Ambiente
print_step "CLONING ENVIRONMENT PROTOCOLS..."
if [ ! -f .env ]; then
    cp .env.example .env
    print_success ".ENV FILE CLONED FROM .ENV.EXAMPLE."
else
    print_success ".ENV FILE ALREADY EXISTS. OVERRIDE BYPASSED."
fi

# 7. Migrações de Banco de Dados
print_step "EXECUTING DATABASE MIGRATION PROTOCOL..."
python manage.py migrate > /dev/null 2>&1
print_success "TABLES PROCESSED AND SYNCED."

# 8. Inicialização do Servidor
echo ""
echo -e "${NEON_MAGENTA}╔═════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${NEON_MAGENTA}║ ${NEON_GREEN} >> SYSTEM ONLINE <<                                                ${NEON_MAGENTA}║${RESET}"
echo -e "${NEON_MAGENTA}║ ${NEON_CYAN} LAUNCHING SERVER: HOST 127.0.0.1:8000                              ${NEON_MAGENTA}║${RESET}"
echo -e "${NEON_MAGENTA}╚═════════════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${NEON_YELLOW}PRESS CTRL+C TO TERMINATE NEURAL LINK...${RESET}"
echo ""

# Roda o servidor
python manage.py runserver
