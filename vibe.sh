#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║           VIBE-STUDYING :: CYBERPUNK LAUNCHER v2.0.77           ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# ── CORES ANSI ──────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Neons
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;201m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;118m'
RED='\033[38;5;196m'
BLUE='\033[38;5;27m'
ORANGE='\033[38;5;208m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;240m'

# Backgrounds
BG_DARK='\033[48;5;232m'
BG_CYAN='\033[48;5;51m'
BG_MAGENTA='\033[48;5;201m'

# ── ESTADO DO SISTEMA ────────────────────────────────────────────────
BACKEND_PID=""
FRONTEND_PID=""
FLUTTER_PID=""
SESSION_XP=0
SESSION_START=$(date +%s)

BACKEND_DIR="$HOME/Documentos/vibe-studying-backend/backend"
FRONTEND_DIR="$HOME/Documentos/vibe-studying-frontend"   # ajuste se necessário
LOG_DIR="/tmp/vibe-logs"
mkdir -p "$LOG_DIR"

# ── UTILITÁRIOS ──────────────────────────────────────────────────────
clear_screen() { printf '\033[2J\033[H'; }

move_to()  { printf "\033[${1};${2}H"; }

hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

trap_exit() {
  show_cursor
  tput cnorm
  echo ""
  glitch_text "[ SESSION TERMINATED ]" "$RED"
  kill_all_services
  exit 0
}
trap trap_exit INT TERM EXIT

runtime() {
  local now=$(date +%s)
  local diff=$(( now - SESSION_START ))
  printf "%02d:%02d:%02d" $(( diff/3600 )) $(( (diff%3600)/60 )) $(( diff%60 ))
}

gain_xp() {
  local amount=$1
  SESSION_XP=$(( SESSION_XP + amount ))
}

# ── EFEITOS ──────────────────────────────────────────────────────────
glitch_text() {
  local text="$1"
  local color="${2:-$CYAN}"
  local glitch_chars=('!' '#' '$' '%' '&' '*' '?' '@' '^' '~')

  for i in 1 2 3; do
    local glitched=""
    for ((j=0; j<${#text}; j++)); do
      if (( RANDOM % 5 == 0 )); then
        glitched+="${glitch_chars[$((RANDOM % ${#glitch_chars[@]}))]}"
      else
        glitched+="${text:$j:1}"
      fi
    done
    printf "\r${color}${BOLD}${glitched}${RESET}"
    sleep 0.04
  done
  printf "\r${color}${BOLD}${text}${RESET}\n"
}

scanline() {
  local width=${1:-70}
  printf "${CYAN}${DIM}"
  for ((i=0; i<width; i++)); do printf "─"; done
  printf "${RESET}\n"
}

double_line() {
  local width=${1:-70}
  printf "${MAGENTA}${BOLD}"
  for ((i=0; i<width; i++)); do printf "═"; done
  printf "${RESET}\n"
}

blink_dot() {
  local color="${1:-$GREEN}"
  # Alterna entre ● e ○ usando o tempo
  if (( $(date +%s) % 2 == 0 )); then
    printf "${color}●${RESET}"
  else
    printf "${color}○${RESET}"
  fi
}

progress_bar() {
  local label="$1"
  local steps=${2:-20}
  local color="${3:-$CYAN}"
  local bar_width=40

  printf "\n  ${color}${BOLD}▸ ${label}${RESET}\n  ["
  for ((i=0; i<=steps; i++)); do
    local filled=$(( i * bar_width / steps ))
    local empty=$(( bar_width - filled ))

    printf "\r  ${GRAY}[${RESET}"
    printf "${color}"
    for ((f=0; f<filled; f++)); do printf "█"; done
    printf "${GRAY}"
    for ((e=0; e<empty; e++)); do printf "░"; done
    printf "${GRAY}]${RESET} ${color}${BOLD}%3d%%${RESET}" $(( i * 100 / steps ))
    sleep 0.06
  done
  printf "\n"
}

type_text() {
  local text="$1"
  local color="${2:-$GREEN}"
  local delay="${3:-0.02}"
  printf "${color}"
  for ((i=0; i<${#text}; i++)); do
    printf "${text:$i:1}"
    sleep "$delay"
  done
  printf "${RESET}\n"
}

spinner() {
  local pid=$1
  local label="$2"
  local color="${3:-$CYAN}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${color}${frames[$((i % ${#frames[@]}))]}${RESET} ${WHITE}${label}${RESET}  "
    sleep 0.08
    ((i++))
  done
  printf "\r  ${GREEN}✔${RESET} ${WHITE}${label}${RESET}          \n"
}

xp_flash() {
  local amount=$1
  printf "  ${YELLOW}${BOLD}⚡ +${amount} XP  ★ TOTAL: ${SESSION_XP}${RESET}\n"
}

notify_success() {
  printf "\n  ${GREEN}${BOLD}[ ✔ OPERAÇÃO CONCLUÍDA ]${RESET}\n"
}

notify_error() {
  printf "\n  ${RED}${BOLD}[ ✘ FALHA NA OPERAÇÃO: $1 ]${RESET}\n"
}

service_badge() {
  local name="$1"
  local status="$2"   # ONLINE | OFFLINE | LOADING
  local pid="$3"

  case "$status" in
    ONLINE)  printf "  ${BG_DARK}${GREEN}${BOLD} ▲ ${name} ${RESET}${GREEN} PID:${pid} ${RESET}" ;;
    OFFLINE) printf "  ${BG_DARK}${RED}${BOLD} ▼ ${name} ${RESET}${RED} OFFLINE ${RESET}" ;;
    LOADING) printf "  ${BG_DARK}${YELLOW}${BOLD} ◈ ${name} ${RESET}${YELLOW} INICIANDO... ${RESET}" ;;
  esac
  printf "\n"
}

# ── SPLASH SCREEN ─────────────────────────────────────────────────────
splash_screen() {
  clear_screen
  hide_cursor
  sleep 0.1

  echo ""
  printf "${MAGENTA}${BOLD}"
  echo "  ██╗   ██╗██╗██████╗ ███████╗    ███████╗████████╗██╗   ██╗██████╗ ██╗   ██╗"
  sleep 0.03
  echo "  ██║   ██║██║██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗╚██╗ ██╔╝"
  sleep 0.03
  echo "  ██║   ██║██║██████╔╝█████╗      ███████╗   ██║   ██║   ██║██║  ██║ ╚████╔╝ "
  sleep 0.03
  echo "  ╚██╗ ██╔╝██║██╔══██╗██╔══╝      ╚════██║   ██║   ██║   ██║██║  ██║  ╚██╔╝  "
  sleep 0.03
  echo "   ╚████╔╝ ██║██████╔╝███████╗    ███████║   ██║   ╚██████╔╝██████╔╝   ██║   "
  sleep 0.03
  echo "    ╚═══╝  ╚═╝╚═════╝ ╚══════╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝    ╚═╝   "
  printf "${RESET}"
  sleep 0.1

  printf "  ${CYAN}${BOLD}"
  echo "  ─────────────────────────────────────────────────────────────────────────────"
  printf "${RESET}"

  printf "  ${GRAY}                 NEURAL DEVOPS INTERFACE  ::  "
  printf "${CYAN}v2.0.77${RESET}${GRAY}  ::  JACK IN TO BEGIN${RESET}\n"

  echo ""
  type_text "  > Inicializando sistemas neurais..." "$CYAN" 0.018
  type_text "  > Carregando módulos de combate..." "$MAGENTA" 0.018
  type_text "  > Sincronizando com a matrix..." "$GREEN" 0.018
  sleep 0.3

  double_line 79
  echo ""
  glitch_text "  ◈ SISTEMA PRONTO. BEM-VINDO, NETRUNNER. ◈" "$CYAN"
  echo ""
  sleep 0.5
}

# ── STATUS HUD ────────────────────────────────────────────────────────
draw_hud() {
  local term_width=$(tput cols)

  double_line 79
  printf "\n"

  # Header row
  printf "  ${CYAN}${BOLD}◈ VIBE-STUDYING DEVOPS HUD${RESET}"
  printf "  ${GRAY}SESSION:${RESET} ${YELLOW}$(runtime)${RESET}"
  printf "  ${GRAY}XP:${RESET} ${YELLOW}${BOLD}${SESSION_XP}${RESET}\n"
  echo ""

  # Services status
  printf "  ${GRAY}── SERVIÇOS ─────────────────────────────────────────${RESET}\n\n"

  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    service_badge "BACKEND  Django:8000" "ONLINE" "$BACKEND_PID"
  else
    service_badge "BACKEND  Django:8000" "OFFLINE" ""
  fi

  if [[ -n "$FRONTEND_PID" ]] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
    service_badge "FRONTEND Next.js" "ONLINE" "$FRONTEND_PID"
  else
    service_badge "FRONTEND Next.js" "OFFLINE" ""
  fi

  if [[ -n "$FLUTTER_PID" ]] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    service_badge "APP      Flutter/Linux" "ONLINE" "$FLUTTER_PID"
  else
    service_badge "APP      Flutter/Linux" "OFFLINE" ""
  fi

  echo ""
  scanline 79
}

# ── MENU PRINCIPAL ───────────────────────────────────────────────────
draw_menu() {
  printf "\n  ${MAGENTA}${BOLD}◈ MATRIZ DE COMANDOS${RESET}\n\n"

  printf "  ${CYAN}${BOLD}[1]${RESET} ${WHITE}⚙  Setup & Run Backend    ${GRAY}(venv + pip + migrate + runserver)${RESET}\n"
  printf "  ${CYAN}${BOLD}[2]${RESET} ${WHITE}⚡  Build & Start Frontend ${GRAY}(npm build + start)${RESET}\n"
  printf "  ${CYAN}${BOLD}[3]${RESET} ${WHITE}📱  Lançar App Flutter     ${GRAY}(flutter run -d linux)${RESET}\n"
  printf "  ${CYAN}${BOLD}[4]${RESET} ${WHITE}🚀  FULL STACK LAUNCH      ${GRAY}(tudo de uma vez)${RESET}\n"
  printf "  ${YELLOW}${BOLD}[5]${RESET} ${WHITE}💀  Matar todos os serviços${RESET}\n"
  printf "  ${MAGENTA}${BOLD}[6]${RESET} ${WHITE}📋  Ver logs em tempo real ${RESET}\n"
  printf "  ${GREEN}${BOLD}[7]${RESET} ${WHITE}🔄  Só migrar DB           ${GRAY}(sem subir servidor)${RESET}\n"
  printf "  ${RED}${BOLD}[0]${RESET} ${WHITE}⏻  Desconectar (sair)${RESET}\n"

  echo ""
  scanline 79
  printf "\n  ${MAGENTA}${BOLD}►${RESET} ${WHITE}Insira código de acesso: ${RESET}"
}

# ── FUNÇÕES DOS SERVIÇOS ──────────────────────────────────────────────
setup_backend() {
  echo ""
  glitch_text "  ◈ INICIANDO MÓDULO BACKEND ◈" "$MAGENTA"
  scanline 79
  echo ""

  # Verifica diretório
  if [[ ! -d "$BACKEND_DIR" ]]; then
    notify_error "Diretório não encontrado: $BACKEND_DIR"
    type_text "  > Edite a variável BACKEND_DIR no topo do script." "$YELLOW" 0.02
    return 1
  fi

  cd "$BACKEND_DIR" || return 1

  # Remove venv antigo
  type_text "  > Removendo ambiente virtual antigo..." "$CYAN" 0.02
  rm -rf .venv
  printf "  ${GREEN}✔${RESET} .venv removido\n"

  # Cria novo venv
  progress_bar "Criando ambiente virtual Python" 15 "$CYAN"
  python3 -m venv .venv 2>>"$LOG_DIR/backend.log"
  if [[ $? -ne 0 ]]; then notify_error "Falha ao criar venv"; return 1; fi

  # Ativa venv
  source .venv/bin/activate
  printf "  ${GREEN}✔${RESET} ${WHITE}Ambiente ativado${RESET}\n"

  # Pip install
  progress_bar "Instalando dependências (pip)" 25 "$MAGENTA"
  pip install -r requirements.txt >>"$LOG_DIR/backend.log" 2>&1 &
  local pip_pid=$!
  spinner $pip_pid "Aguardando pip..." "$MAGENTA"
  wait $pip_pid
  if [[ $? -ne 0 ]]; then notify_error "pip install falhou. Veja $LOG_DIR/backend.log"; return 1; fi

  # .env
  if [[ -f ".env.example" ]] && [[ ! -f ".env" ]]; then
    cp .env.example .env
    printf "  ${GREEN}✔${RESET} ${WHITE}.env criado a partir do .env.example${RESET}\n"
  else
    printf "  ${YELLOW}⚠${RESET} ${WHITE}.env já existe — mantendo atual${RESET}\n"
  fi

  # Migrate
  type_text "  > Rodando migrations..." "$CYAN" 0.02
  python manage.py migrate >>"$LOG_DIR/backend.log" 2>&1
  if [[ $? -ne 0 ]]; then notify_error "migrate falhou. Veja $LOG_DIR/backend.log"; return 1; fi
  printf "  ${GREEN}✔${RESET} ${WHITE}Migrations aplicadas${RESET}\n"

  # Runserver
  type_text "  > Subindo servidor Django em :8000..." "$GREEN" 0.02
  python manage.py runserver >>"$LOG_DIR/backend.log" 2>&1 &
  BACKEND_PID=$!
  sleep 1

  if kill -0 "$BACKEND_PID" 2>/dev/null; then
    gain_xp 150
    xp_flash 150
    notify_success
    printf "  ${GREEN}${BOLD}  ◈ Backend online → http://127.0.0.1:8000${RESET}\n"
  else
    notify_error "runserver encerrou inesperadamente. Veja $LOG_DIR/backend.log"
    BACKEND_PID=""
    return 1
  fi
}

setup_frontend() {
  echo ""
  glitch_text "  ◈ INICIANDO MÓDULO FRONTEND ◈" "$CYAN"
  scanline 79
  echo ""

  if [[ ! -d "$FRONTEND_DIR" ]]; then
    notify_error "Diretório não encontrado: $FRONTEND_DIR"
    type_text "  > Edite a variável FRONTEND_DIR no topo do script." "$YELLOW" 0.02
    return 1
  fi

  cd "$FRONTEND_DIR" || return 1

  # Build
  progress_bar "Compilando frontend (npm build)" 30 "$CYAN"
  npm run build >>"$LOG_DIR/frontend.log" 2>&1 &
  local build_pid=$!
  spinner $build_pid "Processando módulos webpack/next..." "$CYAN"
  wait $build_pid
  if [[ $? -ne 0 ]]; then notify_error "npm build falhou. Veja $LOG_DIR/frontend.log"; return 1; fi

  # Start
  type_text "  > Iniciando servidor frontend..." "$GREEN" 0.02
  npm run start >>"$LOG_DIR/frontend.log" 2>&1 &
  FRONTEND_PID=$!
  sleep 2

  if kill -0 "$FRONTEND_PID" 2>/dev/null; then
    gain_xp 100
    xp_flash 100
    notify_success
    printf "  ${GREEN}${BOLD}  ◈ Frontend online → http://localhost:3000${RESET}\n"
  else
    notify_error "npm start encerrou inesperadamente. Veja $LOG_DIR/frontend.log"
    FRONTEND_PID=""
    return 1
  fi
}

setup_flutter() {
  echo ""
  glitch_text "  ◈ INICIANDO MÓDULO FLUTTER ◈" "$ORANGE"
  scanline 79
  echo ""

  type_text "  > Verificando Flutter SDK..." "$CYAN" 0.02
  if ! command -v flutter &>/dev/null; then
    notify_error "Flutter não encontrado no PATH"
    return 1
  fi
  printf "  ${GREEN}✔${RESET} ${WHITE}Flutter encontrado: $(flutter --version 2>&1 | head -1)${RESET}\n"

  type_text "  > Lançando app em modo Linux Desktop..." "$ORANGE" 0.02
  flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api >>"$LOG_DIR/flutter.log" 2>&1 &
  FLUTTER_PID=$!
  sleep 2

  if kill -0 "$FLUTTER_PID" 2>/dev/null; then
    gain_xp 120
    xp_flash 120
    notify_success
    printf "  ${ORANGE}${BOLD}  ◈ Flutter App rodando (PID: $FLUTTER_PID)${RESET}\n"
  else
    notify_error "flutter run encerrou. Veja $LOG_DIR/flutter.log"
    FLUTTER_PID=""
    return 1
  fi
}

only_migrate() {
  echo ""
  glitch_text "  ◈ SINCRONIZANDO DATABASE ◈" "$YELLOW"
  scanline 79
  echo ""

  cd "$BACKEND_DIR" || { notify_error "Diretório backend não encontrado"; return 1; }

  if [[ ! -d ".venv" ]]; then
    notify_error "Venv não existe. Execute o Setup Backend primeiro (opção 1)."
    return 1
  fi

  source .venv/bin/activate
  type_text "  > Aplicando migrations..." "$CYAN" 0.02
  python manage.py migrate 2>&1 | while IFS= read -r line; do
    printf "  ${GRAY}▸${RESET} ${WHITE}${line}${RESET}\n"
  done

  gain_xp 50
  xp_flash 50
  notify_success
}

full_stack_launch() {
  echo ""
  glitch_text "  ◈◈◈ FULL STACK LAUNCH SEQUENCE ◈◈◈" "$MAGENTA"
  double_line 79
  echo ""
  type_text "  > Iniciando protocolo de lançamento total..." "$WHITE" 0.025
  sleep 0.5

  setup_backend
  echo ""
  sleep 1
  setup_frontend
  echo ""
  sleep 1
  setup_flutter
}

kill_all_services() {
  echo ""
  glitch_text "  ◈ ENCERRANDO SERVIÇOS ◈" "$RED"
  scanline 79
  echo ""

  local killed=0
  for pid_var in BACKEND_PID FRONTEND_PID FLUTTER_PID; do
    local pid="${!pid_var}"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      printf "  ${RED}✖${RESET} ${WHITE}PID ${pid} encerrado (${pid_var/_PID/})${RESET}\n"
      eval "$pid_var=''"
      ((killed++))
    fi
  done

  if [[ $killed -eq 0 ]]; then
    printf "  ${GRAY}  Nenhum serviço ativo para encerrar.${RESET}\n"
  else
    gain_xp 30
    printf "\n  ${YELLOW}${BOLD}  ◈ ${killed} serviço(s) desligado(s)${RESET}\n"
  fi
}

view_logs() {
  echo ""
  printf "  ${CYAN}${BOLD}Escolha o log para monitorar:${RESET}\n\n"
  printf "  ${CYAN}[1]${RESET} Backend   → $LOG_DIR/backend.log\n"
  printf "  ${CYAN}[2]${RESET} Frontend  → $LOG_DIR/frontend.log\n"
  printf "  ${CYAN}[3]${RESET} Flutter   → $LOG_DIR/flutter.log\n"
  printf "  ${GRAY}[0]${RESET} Voltar\n\n"
  printf "  ${MAGENTA}►${RESET} Opção: "
  read -r log_choice
  case "$log_choice" in
    1) show_cursor; tail -f "$LOG_DIR/backend.log" ;;
    2) show_cursor; tail -f "$LOG_DIR/frontend.log" ;;
    3) show_cursor; tail -f "$LOG_DIR/flutter.log" ;;
    0) return ;;
    *) printf "  ${RED}Opção inválida${RESET}\n" ;;
  esac
}

# ── LOOP PRINCIPAL ────────────────────────────────────────────────────
main_loop() {
  while true; do
    clear_screen
    hide_cursor
    draw_hud
    draw_menu
    show_cursor

    read -r choice

    hide_cursor
    case "$choice" in
      1) setup_backend ;;
      2) setup_frontend ;;
      3) setup_flutter ;;
      4) full_stack_launch ;;
      5) kill_all_services ;;
      6) view_logs ;;
      7) only_migrate ;;
      0)
        echo ""
        glitch_text "  [ DESCONECTANDO DA MATRIX... ]" "$RED"
        sleep 0.5
        show_cursor
        exit 0
        ;;
      *)
        printf "\n  ${RED}${BOLD}CÓDIGO INVÁLIDO. ACESSO NEGADO.${RESET}\n"
        ;;
    esac

    echo ""
    printf "  ${GRAY}Pressione ${RESET}${CYAN}[ENTER]${RESET}${GRAY} para retornar ao HUD...${RESET}"
    show_cursor
    read -r
  done
}

# ── ENTRY POINT ───────────────────────────────────────────────────────
splash_screen
main_loop
