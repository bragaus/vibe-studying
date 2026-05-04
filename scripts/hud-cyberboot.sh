#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(realpath "$SCRIPT_DIR/..")"

ROOT_DIR="$DEFAULT_ROOT"
COMMAND="hud"
LOG_TARGET=""

SESSION_START="$(date +%s)"
SESSION_XP=0
CURRENT_MODE="idle"
HUD_MESSAGE="Ready. Choose a mode to boot the stack."

BACKEND_DIR=""
FRONTEND_DIR=""
MOBILE_DIR=""
RUNTIME_DIR=""
PID_DIR=""
LOG_DIR=""
STATE_FILE=""

DATABASE_HOST="127.0.0.1"
DATABASE_PORT="5432"
REDIS_URL=""
CELERY_BROKER_URL="memory://"
CELERY_RESULT_BACKEND="cache+memory://"
OLLAMA_BASE_URL="http://127.0.0.1:11434"
OLLAMA_MODEL="deepseek-r1:8b"
API_BASE_URL="http://127.0.0.1:8000/api"

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;201m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;118m'
RED='\033[38;5;196m'
BLUE='\033[38;5;27m'
ORANGE='\033[38;5;208m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;240m'
BG_DARK='\033[48;5;232m'
BG_CYAN='\033[48;5;51m'
BG_MAGENTA='\033[48;5;201m'

is_tty() {
  [[ -t 1 ]]
}

clear_screen() {
  if is_tty; then
    printf '\033[2J\033[H'
  fi
}

hide_cursor() {
  if is_tty; then
    printf '\033[?25l'
  fi
}

show_cursor() {
  if is_tty; then
    printf '\033[?25h'
  fi
}

scanline() {
  local width="${1:-78}"
  local i
  printf '%b' "$CYAN$DIM"
  for ((i = 0; i < width; i += 1)); do
    printf '─'
  done
  printf '%b\n' "$RESET"
}

double_line() {
  local width="${1:-78}"
  local i
  printf '%b' "$MAGENTA$BOLD"
  for ((i = 0; i < width; i += 1)); do
    printf '═'
  done
  printf '%b\n' "$RESET"
}

type_text() {
  local text="$1"
  local color="${2:-$GREEN}"
  local delay="${3:-0.008}"
  local i

  if ! is_tty; then
    printf '%b%s%b\n' "$color" "$text" "$RESET"
    return
  fi

  printf '%b' "$color"
  for ((i = 0; i < ${#text}; i += 1)); do
    printf '%s' "${text:$i:1}"
    sleep "$delay"
  done
  printf '%b\n' "$RESET"
}

glitch_text() {
  local text="$1"
  local color="${2:-$CYAN}"
  local glitch_chars=('!' '#' '$' '%' '&' '*' '?' '@' '^' '~')
  local i j glitched

  if ! is_tty; then
    printf '%b%s%b\n' "$color" "$text" "$RESET"
    return
  fi

  for i in 1 2; do
    glitched=""
    for ((j = 0; j < ${#text}; j += 1)); do
      if ((RANDOM % 6 == 0)); then
        glitched+="${glitch_chars[$((RANDOM % ${#glitch_chars[@]}))]}"
      else
        glitched+="${text:$j:1}"
      fi
    done
    printf '\r%b%s%b' "$color$BOLD" "$glitched" "$RESET"
    sleep 0.035
  done
  printf '\r%b%s%b\n' "$color$BOLD" "$text" "$RESET"
}

progress_bar() {
  local label="$1"
  local steps="${2:-18}"
  local color="${3:-$CYAN}"
  local width=34
  local i filled empty f e

  if ! is_tty; then
    printf '  %s\n' "$label"
    return
  fi

  printf '\n  %b▸ %s%b\n' "$color$BOLD" "$label" "$RESET"
  for ((i = 0; i <= steps; i += 1)); do
    filled=$((i * width / steps))
    empty=$((width - filled))
    printf '\r  %b[%b' "$GRAY" "$RESET"
    printf '%b' "$color"
    for ((f = 0; f < filled; f += 1)); do printf '█'; done
    printf '%b' "$GRAY"
    for ((e = 0; e < empty; e += 1)); do printf '░'; done
    printf '%b] %b%3d%%%b' "$GRAY" "$color$BOLD" $((i * 100 / steps)) "$RESET"
    sleep 0.018
  done
  printf '\n'
}

service_badge() {
  local name="$1"
  local status="$2"
  local detail="$3"

  case "$status" in
    ONLINE)
      printf '  %b %b▲ %-11s%b %b%s%b\n' "$BG_DARK$GREEN$BOLD" "$BG_DARK" "$name" "$RESET" "$GREEN" "$detail" "$RESET"
      ;;
    OPTIONAL)
      printf '  %b %b◌ %-11s%b %b%s%b\n' "$BG_DARK$YELLOW$BOLD" "$BG_DARK" "$name" "$RESET" "$YELLOW" "$detail" "$RESET"
      ;;
    LOADING)
      printf '  %b %b◈ %-11s%b %b%s%b\n' "$BG_DARK$ORANGE$BOLD" "$BG_DARK" "$name" "$RESET" "$ORANGE" "$detail" "$RESET"
      ;;
    *)
      printf '  %b %b▼ %-11s%b %b%s%b\n' "$BG_DARK$RED$BOLD" "$BG_DARK" "$name" "$RESET" "$RED" "$detail" "$RESET"
      ;;
  esac
}

boot_ok() {
  local text="$1"
  printf '  %b[ OK ]%b %s\n' "$GREEN$BOLD" "$RESET" "$text"
}

boot_warn() {
  local text="$1"
  printf '  %b[WARN]%b %s\n' "$YELLOW$BOLD" "$RESET" "$text"
}

boot_fail() {
  local text="$1"
  printf '  %b[FAIL]%b %s\n' "$RED$BOLD" "$RESET" "$text"
}

mode_label() {
  case "$1" in
    quick) printf 'QUICK' ;;
    async) printf 'ASYNC' ;;
    full) printf 'FULL' ;;
    status) printf 'STATUS' ;;
    stop) printf 'SHUTDOWN' ;;
    idle|hud) printf 'HUD' ;;
    *) printf '%s' "${1^^}" ;;
  esac
}

mode_subtitle() {
  case "$1" in
    quick) printf 'FAST DEV SURGE :: backend + frontend' ;;
    async) printf 'QUEUE SYNC :: quick + redis + worker + beat' ;;
    full) printf 'NEURAL FULL STACK :: ai + mobile + ops' ;;
    status) printf 'SYSTEM INTEL SNAPSHOT :: live neon telemetry' ;;
    stop) printf 'POWERDOWN SEQUENCE :: terminating managed processes' ;;
    idle|hud) printf 'CYBERPUNK CONTROL CONSOLE :: press 1 2 3 to boot' ;;
    *) printf 'VIBE STUDYING :: cyberpunk operations' ;;
  esac
}

draw_full_banner() {
  printf '\n'
  printf '%b' "$MAGENTA$BOLD"
  printf '  ██╗   ██╗██╗██████╗ ███████╗    ███████╗████████╗██╗   ██╗██████╗ ██╗   ██╗\n'
  printf '  ██║   ██║██║██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗╚██╗ ██╔╝\n'
  printf '  ██║   ██║██║██████╔╝█████╗      ███████╗   ██║   ██║   ██║██║  ██║ ╚████╔╝ \n'
  printf '  ╚██╗ ██╔╝██║██╔══██╗██╔══╝      ╚════██║   ██║   ██║   ██║██║  ██║  ╚██╔╝  \n'
  printf '   ╚████╔╝ ██║██████╔╝███████╗    ███████║   ██║   ╚██████╔╝██████╔╝   ██║   \n'
  printf '    ╚═══╝  ╚═╝╚═════╝ ╚══════╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝    ╚═╝   \n'
  printf '%b' "$RESET"
  printf '  %b────────────────────────────────────────────────────────────────────────────%b\n' "$CYAN$BOLD" "$RESET"
  printf '  %bNEURAL DEVOPS INTERFACE%b  %bv3.0%b  %b%s%b\n' "$GRAY" "$RESET" "$CYAN$BOLD" "$RESET" "$GRAY" "$(mode_subtitle full)" "$RESET"
  printf '  %broot:%b %s\n' "$MAGENTA" "$RESET" "$ROOT_DIR"
  printf '\n'
}

draw_title_banner() {
  local title="$1"
  local subtitle="$2"
  printf '\n'
  printf '  %b╔══════════════════════════════════════════════════════════════════════════╗%b\n' "$MAGENTA$BOLD" "$RESET"
  printf '  %b║%b %b%-72s%b %b║%b\n' "$MAGENTA$BOLD" "$RESET" "$CYAN$BOLD" "$title" "$RESET" "$MAGENTA$BOLD" "$RESET"
  printf '  %b║%b %b%-72s%b %b║%b\n' "$MAGENTA$BOLD" "$RESET" "$GRAY" "$subtitle" "$RESET" "$MAGENTA$BOLD" "$RESET"
  printf '  %b╚══════════════════════════════════════════════════════════════════════════╝%b\n' "$MAGENTA$BOLD" "$RESET"
  printf '  %broot:%b %s\n' "$MAGENTA" "$RESET" "$ROOT_DIR"
  printf '\n'
}

draw_mode_banner() {
  local mode="${1:-$CURRENT_MODE}"
  clear_screen
  case "$mode" in
    full) draw_full_banner ;;
    *) draw_title_banner "$(mode_label "$mode")" "$(mode_subtitle "$mode")" ;;
  esac
}

splash_screen() {
  clear_screen
  hide_cursor
  draw_full_banner
  type_text '  > Initializing neural relays...' "$CYAN" 0.01
  type_text '  > Loading combat-grade observability modules...' "$MAGENTA" 0.01
  type_text '  > Syncing local stack with the matrix...' "$GREEN" 0.01
  progress_bar 'Charging full-stack boot sequence' 22 "$MAGENTA"
  glitch_text '  ◈ SYSTEM READY. JACK IN, NETRUNNER. ◈' "$CYAN"
  printf '\n'
  show_cursor
}

boot_stage() {
  local label="$1"
  local steps="$2"
  local color="$3"
  shift 3

  progress_bar "$label" "$steps" "$color"
  if "$@"; then
    boot_ok "$label"
    return 0
  fi

  boot_fail "$label"
  return 1
}

boot_stage_optional() {
  local label="$1"
  local steps="$2"
  local color="$3"
  shift 3

  progress_bar "$label" "$steps" "$color"
  if "$@"; then
    boot_ok "$label"
  else
    boot_warn "$label degraded; inspect logs if you need this module"
  fi
  return 0
}

trap 'show_cursor' EXIT

usage() {
  cat <<'EOF'
Usage:
  ./scripts/hud-cyberboot.sh                # interactive HUD
  ./scripts/hud-cyberboot.sh quick          # boot backend + frontend
  ./scripts/hud-cyberboot.sh async          # quick + redis + worker + beat
  ./scripts/hud-cyberboot.sh full           # async + ollama + flutter linux
  ./scripts/hud-cyberboot.sh stop           # stop managed processes
  ./scripts/hud-cyberboot.sh status         # print current status summary
  ./scripts/hud-cyberboot.sh logs backend   # tail a service log

Options:
  --root PATH                               # override repo root
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      hud|quick|async|full|stop|status)
        COMMAND="$1"
        shift
        ;;
      logs)
        COMMAND="logs"
        LOG_TARGET="${2:-}"
        if [[ -z "$LOG_TARGET" ]]; then
          printf 'missing service name for logs command\n' >&2
          exit 1
        fi
        shift 2
        ;;
      --root)
        if [[ $# -lt 2 ]]; then
          printf 'missing path after --root\n' >&2
          exit 1
        fi
        ROOT_DIR="$(realpath "${2:-}")"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        ROOT_DIR="$(realpath "$1")"
        shift
        ;;
    esac
  done
}

setup_paths() {
  BACKEND_DIR="$ROOT_DIR/backend"
  FRONTEND_DIR="$ROOT_DIR/frontend"
  MOBILE_DIR="$ROOT_DIR/mobile"
  RUNTIME_DIR="$ROOT_DIR/.hud-runtime"
  PID_DIR="$RUNTIME_DIR/pids"
  LOG_DIR="$RUNTIME_DIR/logs"
  STATE_FILE="$RUNTIME_DIR/state.env"
}

runtime() {
  local now diff
  now="$(date +%s)"
  diff=$((now - SESSION_START))
  printf '%02d:%02d:%02d' $((diff / 3600)) $(((diff % 3600) / 60)) $((diff % 60))
}

gain_xp() {
  SESSION_XP=$((SESSION_XP + $1))
}

require_dir() {
  local target_dir="$1"
  local label="$2"
  if [[ ! -d "$target_dir" ]]; then
    printf '%s[FAIL]%s %s not found at %s\n' "$RED" "$RESET" "$label" "$target_dir" >&2
    exit 1
  fi
}

require_cmd() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s[FAIL]%s missing command: %s\n' "$RED" "$RESET" "$command_name" >&2
    exit 1
  fi
}

ensure_runtime_dirs() {
  mkdir -p "$PID_DIR" "$LOG_DIR"
}

save_state() {
  cat >"$STATE_FILE" <<EOF
CURRENT_MODE=$CURRENT_MODE
EOF
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

ensure_env_file() {
  local target_file="$1"
  local example_file="$2"
  if [[ -f "$target_file" || ! -f "$example_file" ]]; then
    return
  fi
  cp "$example_file" "$target_file"
}

load_backend_env() {
  if [[ -f "$BACKEND_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$BACKEND_DIR/.env"
    set +a
  fi

  DATABASE_HOST="${DATABASE_HOST:-127.0.0.1}"
  DATABASE_PORT="${DATABASE_PORT:-5432}"
  REDIS_URL="${REDIS_URL:-}"
  CELERY_BROKER_URL="${CELERY_BROKER_URL:-${REDIS_URL:-memory://}}"
  CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-${REDIS_URL:-cache+memory://}}"
  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
  OLLAMA_MODEL="${OLLAMA_MODEL:-deepseek-r1:8b}"
  API_BASE_URL='http://127.0.0.1:8000/api'
}

pid_file() {
  printf '%s/%s.pid' "$PID_DIR" "$1"
}

log_file() {
  printf '%s/%s.log' "$LOG_DIR" "$1"
}

cleanup_stale_pid() {
  local service_name="$1"
  local file_path pid_value
  file_path="$(pid_file "$service_name")"
  if [[ ! -f "$file_path" ]]; then
    return
  fi

  pid_value="$(<"$file_path")"
  if [[ -z "$pid_value" || ! "$pid_value" =~ ^[0-9]+$ || ! -d "/proc/$pid_value" ]]; then
    rm -f "$file_path"
  fi
}

managed_pid() {
  local service_name="$1"
  local file_path
  cleanup_stale_pid "$service_name"
  file_path="$(pid_file "$service_name")"
  if [[ -f "$file_path" ]]; then
    printf '%s' "$(<"$file_path")"
  fi
}

managed_running() {
  local pid_value
  pid_value="$(managed_pid "$1")"
  [[ -n "$pid_value" && -d "/proc/$pid_value" ]]
}

port_is_open() {
  local host="$1"
  local port="$2"
  python3 - <<PY
import socket
s = socket.socket()
s.settimeout(0.5)
try:
    s.connect(("$host", int("$port")))
except OSError:
    raise SystemExit(1)
else:
    raise SystemExit(0)
finally:
    s.close()
PY
}

http_ready() {
  curl -fsS "$1" >/dev/null 2>&1
}

wait_for_http() {
  local url="$1"
  local seconds="${2:-30}"
  local elapsed=0
  while ((elapsed < seconds)); do
    if http_ready "$url"; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

redis_host() {
  if [[ "$REDIS_URL" =~ ^redis://([^:/]+):([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return
  fi
  printf '127.0.0.1'
}

redis_port() {
  if [[ "$REDIS_URL" =~ ^redis://([^:/]+):([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return
  fi
  printf '6379'
}

service_port_in_use() {
  case "$1" in
    backend-server) port_is_open '127.0.0.1' '8000' ;;
    frontend-dev) port_is_open '127.0.0.1' '3000' ;;
    ollama-serve) http_ready "${OLLAMA_BASE_URL%/}/api/tags" ;;
    *) return 1 ;;
  esac
}

launch_service() {
  local service_name="$1"
  local workdir="$2"
  local command_text="$3"
  local pid_path log_path

  pid_path="$(pid_file "$service_name")"
  log_path="$(log_file "$service_name")"

  if managed_running "$service_name"; then
    HUD_MESSAGE="$service_name already running."
    return 0
  fi

  if service_port_in_use "$service_name"; then
    HUD_MESSAGE="$service_name port already in use; leaving external process untouched."
    return 0
  fi

  (
    cd "$workdir"
    nohup bash -lc "$command_text" >"$log_path" 2>&1 &
    printf '%s' "$!" >"$pid_path"
  )
}

stop_service() {
  local service_name="$1"
  local pid_value pid_path

  pid_path="$(pid_file "$service_name")"
  pid_value="$(managed_pid "$service_name")"

  if [[ -z "$pid_value" ]]; then
    rm -f "$pid_path"
    return 0
  fi

  kill "$pid_value" >/dev/null 2>&1 || true
  sleep 1
  if [[ -d "/proc/$pid_value" ]]; then
    kill -9 "$pid_value" >/dev/null 2>&1 || true
  fi
  rm -f "$pid_path"
}

stop_all_services() {
  stop_service 'mobile-linux'
  stop_service 'ollama-serve'
  stop_service 'celery-beat'
  stop_service 'celery-worker'
  stop_service 'frontend-dev'
  stop_service 'backend-server'
  HUD_MESSAGE='Managed services stopped.'
  CURRENT_MODE='idle'
  save_state
}

ensure_postgres() {
  if command -v pg_isready >/dev/null 2>&1; then
    if pg_isready -h "$DATABASE_HOST" -p "$DATABASE_PORT" >/dev/null 2>&1; then
      return 0
    fi
  elif port_is_open "$DATABASE_HOST" "$DATABASE_PORT"; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo systemctl start postgresql >/dev/null 2>&1 || true
    sleep 2
  fi

  if command -v pg_isready >/dev/null 2>&1; then
    pg_isready -h "$DATABASE_HOST" -p "$DATABASE_PORT" >/dev/null 2>&1
    return
  fi

  port_is_open "$DATABASE_HOST" "$DATABASE_PORT"
}

ensure_redis() {
  local host port
  host="$(redis_host)"
  port="$(redis_port)"

  if port_is_open "$host" "$port"; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo systemctl start redis-server >/dev/null 2>&1 || true
    sleep 2
  fi

  port_is_open "$host" "$port"
}

ensure_backend_dependencies() {
  local marker="$BACKEND_DIR/.venv/.hud-deps-stamp"
  require_cmd python3

  if [[ ! -x "$BACKEND_DIR/.venv/bin/python" ]]; then
    python3 -m venv "$BACKEND_DIR/.venv"
  fi

  if [[ ! -f "$marker" || "$BACKEND_DIR/requirements.txt" -nt "$marker" ]]; then
    "$BACKEND_DIR/.venv/bin/python" -m pip install --upgrade pip
    "$BACKEND_DIR/.venv/bin/pip" install -r "$BACKEND_DIR/requirements.txt"
    touch "$marker"
  fi
}

ensure_frontend_dependencies() {
  local marker="$FRONTEND_DIR/node_modules/.hud-deps-stamp"
  require_cmd npm

  if [[ ! -d "$FRONTEND_DIR/node_modules" || ! -f "$marker" || "$FRONTEND_DIR/package.json" -nt "$marker" || "$FRONTEND_DIR/package-lock.json" -nt "$marker" ]]; then
    (
      cd "$FRONTEND_DIR"
      npm install
    )
    mkdir -p "$FRONTEND_DIR/node_modules"
    touch "$marker"
  fi
}

ensure_mobile_dependencies() {
  local marker="$MOBILE_DIR/.dart_tool/package_config.json"
  if ! command -v flutter >/dev/null 2>&1; then
    return 1
  fi

  if [[ ! -f "$marker" || "$MOBILE_DIR/pubspec.lock" -nt "$marker" ]]; then
    (
      cd "$MOBILE_DIR"
      flutter pub get
    )
  fi
}

run_backend_migrations() {
  (
    cd "$BACKEND_DIR"
    "$BACKEND_DIR/.venv/bin/python" manage.py migrate
  )
}

start_backend() {
  launch_service 'backend-server' "$BACKEND_DIR" "./.venv/bin/python manage.py runserver 0.0.0.0:8000"
  if wait_for_http "$API_BASE_URL/health" 45; then
    gain_xp 80
    HUD_MESSAGE='Backend online at http://127.0.0.1:8000/api.'
    return 0
  fi
  HUD_MESSAGE='Backend launch timed out. Check backend-server.log.'
  return 1
}

start_frontend() {
  launch_service 'frontend-dev' "$FRONTEND_DIR" "NEXT_PUBLIC_API_URL=$API_BASE_URL npm run dev -- --hostname 0.0.0.0 --port 3000"
  if wait_for_http 'http://127.0.0.1:3000' 60; then
    gain_xp 60
    HUD_MESSAGE='Frontend online at http://127.0.0.1:3000.'
    return 0
  fi
  HUD_MESSAGE='Frontend launch timed out. Check frontend-dev.log.'
  return 1
}

start_worker() {
  launch_service 'celery-worker' "$BACKEND_DIR" "./.venv/bin/celery -A config worker -l info"
  sleep 2
  if managed_running 'celery-worker'; then
    gain_xp 40
    HUD_MESSAGE='Celery worker online.'
    return 0
  fi
  HUD_MESSAGE='Celery worker failed to stay online. Check celery-worker.log.'
  return 1
}

start_beat() {
  launch_service 'celery-beat' "$BACKEND_DIR" "./.venv/bin/celery -A config beat -l info"
  sleep 2
  if managed_running 'celery-beat'; then
    gain_xp 30
    HUD_MESSAGE='Celery beat online.'
    return 0
  fi
  HUD_MESSAGE='Celery beat failed to stay online. Check celery-beat.log.'
  return 1
}

start_ollama() {
  if http_ready "${OLLAMA_BASE_URL%/}/api/tags"; then
    HUD_MESSAGE='Ollama already online.'
    return 0
  fi

  if ! command -v ollama >/dev/null 2>&1; then
    HUD_MESSAGE='Ollama not found; full mode will stay degraded.'
    return 0
  fi

  launch_service 'ollama-serve' "$ROOT_DIR" 'ollama serve'
  if wait_for_http "${OLLAMA_BASE_URL%/}/api/tags" 30; then
    gain_xp 50
    HUD_MESSAGE="Ollama online at ${OLLAMA_BASE_URL}."
    return 0
  fi
  HUD_MESSAGE='Ollama launch timed out. Check ollama-serve.log.'
  return 1
}

start_mobile() {
  if [[ ! -d "$MOBILE_DIR" ]]; then
    HUD_MESSAGE='Mobile directory not found; skipping mobile launcher.'
    return 0
  fi

  if ! command -v flutter >/dev/null 2>&1; then
    HUD_MESSAGE='Flutter not found; full mode will stay without mobile app.'
    return 0
  fi

  launch_service 'mobile-linux' "$MOBILE_DIR" "flutter run -d linux --dart-define=API_BASE_URL=$API_BASE_URL"
  sleep 4
  if managed_running 'mobile-linux'; then
    gain_xp 60
    HUD_MESSAGE='Flutter Linux app launched in background.'
    return 0
  fi
  HUD_MESSAGE='Flutter app did not stay online. Check mobile-linux.log.'
  return 1
}

boot_quick_core() {
  CURRENT_MODE='quick'
  HUD_MESSAGE='Booting quick mode...'
  ensure_env_file "$BACKEND_DIR/.env" "$BACKEND_DIR/.env.example"
  ensure_env_file "$FRONTEND_DIR/.env" "$FRONTEND_DIR/.env.example"
  load_backend_env
  boot_stage 'Handshake with PostgreSQL core' 16 "$CYAN" ensure_postgres
  boot_stage 'Rebuilding Python neural links' 18 "$MAGENTA" ensure_backend_dependencies
  boot_stage 'Syncing Django database migrations' 14 "$GREEN" run_backend_migrations
  boot_stage 'Launching backend API node' 18 "$CYAN" start_backend
  boot_stage 'Refreshing Next.js interface modules' 16 "$MAGENTA" ensure_frontend_dependencies
  boot_stage 'Launching frontend neon portal' 18 "$GREEN" start_frontend
  gain_xp 40
  HUD_MESSAGE='Quick mode ready: backend + frontend.'
  save_state
}

boot_quick() {
  draw_mode_banner quick
  type_text '  > Quick mode selected. Minimal stack, maximum iteration speed.' "$CYAN" 0.009
  scanline 78
  printf '\n'
  boot_quick_core
}

boot_async_core() {
  boot_quick_core
  CURRENT_MODE='async'
  HUD_MESSAGE='Booting async mode...'
  load_backend_env
  boot_stage 'Waking Redis message bus' 14 "$ORANGE" ensure_redis
  boot_stage 'Deploying Celery worker drones' 16 "$CYAN" start_worker
  boot_stage 'Activating beat scheduler clock' 14 "$MAGENTA" start_beat
  gain_xp 50
  HUD_MESSAGE='Async mode ready: quick + redis + worker + beat.'
  save_state
}

boot_async() {
  draw_mode_banner async
  type_text '  > Async mode selected. Queue orchestration and background ops online.' "$MAGENTA" 0.009
  scanline 78
  printf '\n'
  boot_async_core
}

boot_full_core() {
  boot_async_core
  CURRENT_MODE='full'
  HUD_MESSAGE='Booting full mode...'
  load_backend_env
  boot_stage_optional 'Summoning Ollama inference daemon' 18 "$ORANGE" start_ollama
  if [[ -d "$MOBILE_DIR" ]]; then
    boot_stage_optional 'Syncing Flutter mobile arsenal' 16 "$CYAN" ensure_mobile_dependencies
    boot_stage_optional 'Deploying Linux mobile simulator' 18 "$GREEN" start_mobile
  fi
  gain_xp 70
  HUD_MESSAGE='Full mode ready: async stack plus AI/mobile extras when available.'
  save_state
}

boot_full() {
  splash_screen
  draw_mode_banner full
  type_text '  > Full mode selected. Cybernetic launch sequence engaged.' "$CYAN" 0.009
  type_text '  > Expect AI, queue, web, API and mobile telemetry on the same deck.' "$GREEN" 0.009
  double_line 78
  printf '\n'
  boot_full_core
}

service_label() {
  case "$1" in
    postgres) printf 'Postgres' ;;
    redis) printf 'Redis' ;;
    backend-server) printf 'Backend' ;;
    frontend-dev) printf 'Frontend' ;;
    celery-worker) printf 'Worker' ;;
    celery-beat) printf 'Beat' ;;
    ollama-serve) printf 'Ollama' ;;
    mobile-linux) printf 'Mobile' ;;
    *) printf '%s' "$1" ;;
  esac
}

service_status() {
  case "$1" in
    postgres)
      if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -h "$DATABASE_HOST" -p "$DATABASE_PORT" >/dev/null 2>&1 && printf 'ONLINE' || printf 'OFFLINE'
      elif port_is_open "$DATABASE_HOST" "$DATABASE_PORT"; then
        printf 'ONLINE'
      else
        printf 'OFFLINE'
      fi
      ;;
    redis)
      if [[ "$CURRENT_MODE" == 'quick' || "$CURRENT_MODE" == 'idle' ]]; then
        printf 'OPTIONAL'
      elif port_is_open "$(redis_host)" "$(redis_port)"; then
        printf 'ONLINE'
      else
        printf 'OFFLINE'
      fi
      ;;
    backend-server)
      http_ready "$API_BASE_URL/health" && printf 'ONLINE' || printf 'OFFLINE'
      ;;
    frontend-dev)
      http_ready 'http://127.0.0.1:3000' && printf 'ONLINE' || printf 'OFFLINE'
      ;;
    celery-worker|celery-beat|mobile-linux)
      managed_running "$1" && printf 'ONLINE' || printf 'OFFLINE'
      ;;
    ollama-serve)
      if [[ "$CURRENT_MODE" != 'full' ]]; then
        printf 'OPTIONAL'
      elif http_ready "${OLLAMA_BASE_URL%/}/api/tags"; then
        printf 'ONLINE'
      else
        printf 'OFFLINE'
      fi
      ;;
    *)
      printf 'UNKNOWN'
      ;;
  esac
}

status_color() {
  case "$1" in
    ONLINE) printf '%b' "$GREEN" ;;
    OPTIONAL) printf '%b' "$YELLOW" ;;
    OFFLINE) printf '%b' "$RED" ;;
    *) printf '%b' "$GRAY" ;;
  esac
}

service_detail() {
  local service_name="$1"
  local pid_value
  pid_value="$(managed_pid "$service_name")"
  case "$service_name" in
    postgres) printf '%s:%s' "$DATABASE_HOST" "$DATABASE_PORT" ;;
    redis) printf '%s:%s' "$(redis_host)" "$(redis_port)" ;;
    backend-server) printf 'api=%s' "$API_BASE_URL" ;;
    frontend-dev) printf 'web=http://127.0.0.1:3000' ;;
    celery-worker|celery-beat|ollama-serve|mobile-linux)
      if [[ -n "$pid_value" ]]; then
        printf 'pid=%s' "$pid_value"
      else
        printf 'not managed'
      fi
      ;;
    *) printf '-' ;;
  esac
}

print_service_line() {
  local service_name="$1"
  local status_value
  status_value="$(service_status "$service_name")"
  service_badge "$(service_label "$service_name")" "$status_value" "$(service_detail "$service_name")"
}

mission_status() {
  local backend_state frontend_state worker_state beat_state
  backend_state="$(service_status 'backend-server')"
  frontend_state="$(service_status 'frontend-dev')"
  worker_state="$(service_status 'celery-worker')"
  beat_state="$(service_status 'celery-beat')"

  printf '  Missions: '
  if [[ "$backend_state" == 'ONLINE' ]]; then
    printf '%bAPI%b ' "$GREEN" "$RESET"
  else
    printf '%bAPI%b ' "$RED" "$RESET"
  fi

  if [[ "$frontend_state" == 'ONLINE' ]]; then
    printf '%bWEB%b ' "$GREEN" "$RESET"
  else
    printf '%bWEB%b ' "$RED" "$RESET"
  fi

  if [[ "$worker_state" == 'ONLINE' && "$beat_state" == 'ONLINE' ]]; then
    printf '%bQUEUE%b' "$GREEN" "$RESET"
  else
    printf '%bQUEUE%b' "$YELLOW" "$RESET"
  fi

  if [[ "$CURRENT_MODE" == 'full' ]]; then
    if [[ "$(service_status 'ollama-serve')" == 'ONLINE' ]]; then
      printf ' %bAI%b' "$GREEN" "$RESET"
    else
      printf ' %bAI%b' "$YELLOW" "$RESET"
    fi
  fi

  printf '\n'
}

render_status_panel() {
  printf '  %b◈ NEON TELEMETRY%b   %bMODE:%b %s   %bRUNTIME:%b %s   %bXP:%b %s\n' "$CYAN$BOLD" "$RESET" "$GRAY" "$RESET" "$CURRENT_MODE" "$GRAY" "$RESET" "$(runtime)" "$GRAY" "$RESET" "$SESSION_XP"
  mission_status
  printf '\n'
  print_service_line 'postgres'
  print_service_line 'redis'
  print_service_line 'backend-server'
  print_service_line 'frontend-dev'
  print_service_line 'celery-worker'
  print_service_line 'celery-beat'
  print_service_line 'ollama-serve'
  if [[ -d "$MOBILE_DIR" ]]; then
    print_service_line 'mobile-linux'
  fi
  printf '\n'
  scanline 78
}

render_hud() {
  draw_mode_banner "$CURRENT_MODE"
  render_status_panel
  printf '  %bCommands%b\n' "$CYAN$BOLD" "$RESET"
  printf '  %b[1]%b quick   %b[2]%b async   %b[3]%b full   %b[s]%b stop   %b[l]%b logs   %b[r]%b refresh   %b[q]%b quit\n' "$CYAN" "$RESET" "$MAGENTA" "$RESET" "$ORANGE" "$RESET" "$RED" "$RESET" "$BLUE" "$RESET" "$GREEN" "$RESET" "$YELLOW" "$RESET"
  printf '  %bSignal%b %s\n' "$BLUE$BOLD" "$RESET" "$HUD_MESSAGE"
}

resolve_log_service() {
  case "$1" in
    backend|api) printf 'backend-server' ;;
    frontend|web) printf 'frontend-dev' ;;
    worker) printf 'celery-worker' ;;
    beat) printf 'celery-beat' ;;
    ollama|ai) printf 'ollama-serve' ;;
    mobile|flutter) printf 'mobile-linux' ;;
    *) printf '%s' "$1" ;;
  esac
}

tail_log() {
  local service_name log_path
  service_name="$(resolve_log_service "$1")"
  log_path="$(log_file "$service_name")"
  if [[ ! -f "$log_path" ]]; then
    printf 'log not found for %s (%s)\n' "$1" "$log_path" >&2
    exit 1
  fi
  draw_title_banner "LOGS :: ${service_name^^}" 'STREAMING RUNTIME OUTPUT :: Ctrl+C to stop following'
  tail -f "$log_path"
}

interactive_logs() {
  local target raw_target
  draw_title_banner 'LOG TUNNEL' 'FOLLOW A SERVICE STREAM :: backend frontend worker beat ollama mobile'
  printf '\n  Log target [backend/frontend/worker/beat/ollama/mobile]: '
  read -r raw_target
  target="$(resolve_log_service "$raw_target")"
  if [[ -z "$raw_target" ]]; then
    HUD_MESSAGE='Log view cancelled.'
    return
  fi
  if [[ ! -f "$(log_file "$target")" ]]; then
    HUD_MESSAGE="No log file for $raw_target yet."
    return
  fi
  printf '\nPress Ctrl+C to return to the HUD.\n\n'
  tail -f "$(log_file "$target")" || true
  HUD_MESSAGE="Stopped following $raw_target log."
}

print_status_summary() {
  draw_mode_banner status
  type_text '  > Pulling live telemetry from the local deck...' "$CYAN" 0.006
  printf '\n'
  render_status_panel
  printf '  %bSignal%b %s\n' "$BLUE$BOLD" "$RESET" "$HUD_MESSAGE"
}

render_mode_snapshot() {
  local mode="$1"
  draw_mode_banner "$mode"
  render_status_panel
  printf '  %bSignal%b %s\n' "$BLUE$BOLD" "$RESET" "$HUD_MESSAGE"
}

run_mode_action() {
  local mode="$1"
  shift

  if ! "$@"; then
    HUD_MESSAGE="${mode^^} mode hit an anomaly. Review the logs in $LOG_DIR."
    render_mode_snapshot "$mode"
    return 1
  fi

  render_mode_snapshot "$mode"
}

run_stop_action() {
  draw_mode_banner stop
  type_text '  > Executing managed shutdown sequence...' "$RED" 0.006
  printf '\n'
  stop_all_services
  render_mode_snapshot stop
}

interactive_loop() {
  local key
  while true; do
    hide_cursor
    render_hud
    show_cursor
    if read -rsn1 -t 1 key; then
      case "$key" in
        1) run_mode_action quick boot_quick || true ;;
        2) run_mode_action async boot_async || true ;;
        3) run_mode_action full boot_full || true ;;
        s|S) run_stop_action ;;
        l|L) interactive_logs ;;
        r|R) HUD_MESSAGE='HUD refreshed.' ;;
        q|Q)
          printf '\n'
          return 0
          ;;
      esac
    fi
  done
}

main() {
  parse_args "$@"
  setup_paths

  require_dir "$ROOT_DIR" 'repo root'
  require_dir "$BACKEND_DIR" 'backend directory'
  require_dir "$FRONTEND_DIR" 'frontend directory'
  ensure_runtime_dirs
  load_state
  ensure_env_file "$BACKEND_DIR/.env" "$BACKEND_DIR/.env.example"
  ensure_env_file "$FRONTEND_DIR/.env" "$FRONTEND_DIR/.env.example"
  load_backend_env

  case "$COMMAND" in
    quick) run_mode_action quick boot_quick ;;
    async) run_mode_action async boot_async ;;
    full) run_mode_action full boot_full ;;
    stop) run_stop_action ;;
    status) print_status_summary ;;
    logs) tail_log "$LOG_TARGET" ;;
    hud) interactive_loop ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
