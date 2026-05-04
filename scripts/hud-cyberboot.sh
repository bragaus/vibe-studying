#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <repo-root>\n' "$0" >&2
  exit 1
fi

ROOT_DIR="$(realpath "$1")"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
MOBILE_DIR="$ROOT_DIR/mobile"
RUNTIME_DIR="$ROOT_DIR/.hud-runtime"
PID_DIR="$RUNTIME_DIR/pids"
LOG_DIR="$RUNTIME_DIR/logs"

CYAN='\033[1;36m'
PINK='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

mkdir -p "$PID_DIR" "$LOG_DIR"

require_dir() {
  local target_dir="$1"
  local label="$2"
  if [[ ! -d "$target_dir" ]]; then
    printf '%b[FAIL]%b %s not found at %s\n' "$RED" "$RESET" "$label" "$target_dir" >&2
    exit 1
  fi
}

require_cmd() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%b[FAIL]%b missing command: %s\n' "$RED" "$RESET" "$command_name" >&2
    exit 1
  fi
}

banner() {
  printf '%b' "$RESET"
  printf '%b+------------------------------------------------------------------------------+%b\n' "$PINK" "$RESET"
  printf '%b|%b %-76s %b|%b\n' "$PINK" "$CYAN" 'VIBE STUDYING :: CYBERPUNK HUD BOOT SEQUENCE' "$PINK" "$RESET"
  printf '%b|%b %-76s %b|%b\n' "$PINK" "$DIM" "root=$ROOT_DIR" "$PINK" "$RESET"
  printf '%b+------------------------------------------------------------------------------+%b\n' "$PINK" "$RESET"
}

log_step() {
  printf '%b[STEP]%b %s\n' "$BLUE" "$RESET" "$1"
}

log_info() {
  printf '%b[INFO]%b %s\n' "$CYAN" "$RESET" "$1"
}

log_ok() {
  printf '%b[ OK ]%b %s\n' "$GREEN" "$RESET" "$1"
}

log_warn() {
  printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

log_fail() {
  printf '%b[FAIL]%b %s\n' "$RED" "$RESET" "$1" >&2
}

stop_managed_processes() {
  local pid_file pid_value service_name
  shopt -s nullglob
  for pid_file in "$PID_DIR"/*.pid; do
    service_name="$(basename "$pid_file" .pid)"
    pid_value="$(<"$pid_file")"
    if [[ -n "$pid_value" ]] && kill -0 "$pid_value" >/dev/null 2>&1; then
      log_info "stopping managed process: $service_name (pid=$pid_value)"
      kill "$pid_value" >/dev/null 2>&1 || true
      sleep 1
      if kill -0 "$pid_value" >/dev/null 2>&1; then
        kill -9 "$pid_value" >/dev/null 2>&1 || true
      fi
    fi
    rm -f "$pid_file"
  done
  shopt -u nullglob
}

ensure_env_file() {
  local target_file="$1"
  local example_file="$2"
  if [[ -f "$target_file" ]]; then
    return
  fi
  cp "$example_file" "$target_file"
  log_warn "created missing env file: $target_file"
}

is_http_ready() {
  local url="$1"
  curl -fsS "$url" >/dev/null 2>&1
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local max_attempts="${3:-60}"
  local attempt
  for ((attempt = 1; attempt <= max_attempts; attempt += 1)); do
    if is_http_ready "$url"; then
      log_ok "$label is online at $url"
      return 0
    fi
    sleep 1
  done
  log_fail "$label did not become ready at $url"
  return 1
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

start_with_logs() {
  local service_name="$1"
  local workdir="$2"
  local command_text="$3"
  local log_file="$LOG_DIR/$service_name.log"
  local pid_file="$PID_DIR/$service_name.pid"

  log_step "starting $service_name"
  nohup bash -lc "$command_text" >"$log_file" 2>&1 &
  local started_pid=$!
  printf '%s' "$started_pid" >"$pid_file"
  log_ok "$service_name launched (pid=$started_pid, log=$log_file)"
}

load_backend_env() {
  set -a
  # shellcheck disable=SC1090
  source "$BACKEND_DIR/.env"
  set +a

  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:11434}"
  OLLAMA_MODEL="${OLLAMA_MODEL:-deepseek-r1:8b}"
  CELERY_BROKER_URL="${CELERY_BROKER_URL:-memory://}"
  REDIS_URL="${REDIS_URL:-}"
  DATABASE_HOST="${DATABASE_HOST:-127.0.0.1}"
  DATABASE_PORT="${DATABASE_PORT:-5432}"

  RUNTIME_REDIS_URL='redis://127.0.0.1:6379/0'
  RUNTIME_CACHE_URL='redis://127.0.0.1:6379/1'
  RUNTIME_CELERY_BROKER_URL='redis://127.0.0.1:6379/0'
  RUNTIME_CELERY_RESULT_BACKEND='redis://127.0.0.1:6379/2'
  RUNTIME_FRONTEND_API_URL='http://127.0.0.1:8000/api'
}

ensure_postgres() {
  if command -v pg_isready >/dev/null 2>&1 && pg_isready -h "$DATABASE_HOST" -p "$DATABASE_PORT" >/dev/null 2>&1; then
    log_ok "postgres is ready at $DATABASE_HOST:$DATABASE_PORT"
    return
  fi

  log_warn "postgres is not responding on $DATABASE_HOST:$DATABASE_PORT"
  if command -v sudo >/dev/null 2>&1; then
    log_info 'trying to start postgresql via sudo systemctl'
    sudo systemctl start postgresql || true
    sleep 2
  fi

  if command -v pg_isready >/dev/null 2>&1 && pg_isready -h "$DATABASE_HOST" -p "$DATABASE_PORT" >/dev/null 2>&1; then
    log_ok "postgres started successfully"
    return
  fi

  log_fail 'postgres is still offline. Start PostgreSQL and run the script again.'
  exit 1
}

ensure_redis() {
  local redis_host='127.0.0.1'
  local redis_port='6379'

  if [[ -n "$REDIS_URL" ]] && [[ "$REDIS_URL" =~ redis://([^:/]+):([0-9]+) ]]; then
    redis_host="${BASH_REMATCH[1]}"
    redis_port="${BASH_REMATCH[2]}"
  elif [[ "$RUNTIME_REDIS_URL" =~ redis://([^:/]+):([0-9]+) ]]; then
    redis_host="${BASH_REMATCH[1]}"
    redis_port="${BASH_REMATCH[2]}"
  fi

  if port_is_open "$redis_host" "$redis_port"; then
    log_ok "redis is ready at $redis_host:$redis_port"
    return
  fi

  log_warn "redis is not responding on $redis_host:$redis_port"
  if command -v sudo >/dev/null 2>&1; then
    log_info 'trying to start redis-server via sudo systemctl'
    sudo systemctl start redis-server || true
    sleep 2
  fi

  if port_is_open "$redis_host" "$redis_port"; then
    log_ok "redis started successfully"
    return
  fi

  log_fail 'redis is still offline. Start Redis and run the script again.'
  exit 1
}

ensure_ollama() {
  local ollama_health_url="${OLLAMA_BASE_URL%/}/api/tags"

  if is_http_ready "$ollama_health_url"; then
    log_ok "ollama is already online"
  else
    require_cmd ollama
    start_with_logs \
      'ollama-serve' \
      "$ROOT_DIR" \
      "ollama serve"
    wait_for_http "$ollama_health_url" 'ollama' 30
  fi

  log_step "ensuring ollama model is present: $OLLAMA_MODEL"
  ollama pull "$OLLAMA_MODEL"
  log_ok "ollama model ready: $OLLAMA_MODEL"
}

prepare_backend() {
  require_cmd python3

  log_step 'recreating backend virtualenv'
  rm -rf "$BACKEND_DIR/.venv"
  python3 -m venv "$BACKEND_DIR/.venv"

  log_step 'installing backend dependencies'
  "$BACKEND_DIR/.venv/bin/python" -m pip install --upgrade pip
  "$BACKEND_DIR/.venv/bin/pip" install -r "$BACKEND_DIR/requirements.txt"
  log_ok 'backend dependencies installed'

  log_step 'running backend migrations'
  (
    cd "$BACKEND_DIR" && \
      REDIS_URL="$RUNTIME_REDIS_URL" \
      CACHE_URL="$RUNTIME_CACHE_URL" \
      CELERY_BROKER_URL="$RUNTIME_CELERY_BROKER_URL" \
      CELERY_RESULT_BACKEND="$RUNTIME_CELERY_RESULT_BACKEND" \
      OLLAMA_BASE_URL="$OLLAMA_BASE_URL" \
      OLLAMA_MODEL="$OLLAMA_MODEL" \
      "$BACKEND_DIR/.venv/bin/python" manage.py migrate
  )
  log_ok 'backend migrations applied'
}

prepare_frontend() {
  require_cmd npm

  log_step 'refreshing frontend dependencies'
  rm -rf "$FRONTEND_DIR/dist" "$FRONTEND_DIR/.next"
  (cd "$FRONTEND_DIR" && npm install)
  log_ok 'frontend dependencies installed'

  log_step 'building frontend'
  (
    cd "$FRONTEND_DIR" && \
      NEXT_PUBLIC_API_URL="$RUNTIME_FRONTEND_API_URL" \
      npm run build
  )
  log_ok 'frontend build completed'
}

prepare_mobile() {
  require_cmd flutter

  log_step 'cleaning flutter workspace'
  (cd "$MOBILE_DIR" && flutter clean)

  log_step 'downloading flutter dependencies'
  (cd "$MOBILE_DIR" && flutter pub get)
  log_ok 'flutter dependencies ready'
}

start_backend_stack() {
  if pgrep -fa 'manage.py runserver 0.0.0.0:8000' >/dev/null 2>&1; then
    log_warn 'backend runserver already active; keeping existing process'
  else
    start_with_logs \
      'backend-server' \
      "$BACKEND_DIR" \
      "cd \"$BACKEND_DIR\" && REDIS_URL=\"$RUNTIME_REDIS_URL\" CACHE_URL=\"$RUNTIME_CACHE_URL\" CELERY_BROKER_URL=\"$RUNTIME_CELERY_BROKER_URL\" CELERY_RESULT_BACKEND=\"$RUNTIME_CELERY_RESULT_BACKEND\" OLLAMA_BASE_URL=\"$OLLAMA_BASE_URL\" OLLAMA_MODEL=\"$OLLAMA_MODEL\" ./.venv/bin/python manage.py runserver 0.0.0.0:8000"
    wait_for_http 'http://127.0.0.1:8000/api/health' 'backend api' 60
  fi

  if pgrep -fa 'celery -A config worker -l info' >/dev/null 2>&1; then
    log_warn 'celery worker already active; keeping existing process'
  else
    start_with_logs \
      'celery-worker' \
      "$BACKEND_DIR" \
      "cd \"$BACKEND_DIR\" && REDIS_URL=\"$RUNTIME_REDIS_URL\" CACHE_URL=\"$RUNTIME_CACHE_URL\" CELERY_BROKER_URL=\"$RUNTIME_CELERY_BROKER_URL\" CELERY_RESULT_BACKEND=\"$RUNTIME_CELERY_RESULT_BACKEND\" OLLAMA_BASE_URL=\"$OLLAMA_BASE_URL\" OLLAMA_MODEL=\"$OLLAMA_MODEL\" ./.venv/bin/celery -A config worker -l info"
  fi

  if pgrep -fa 'celery -A config beat -l info' >/dev/null 2>&1; then
    log_warn 'celery beat already active; keeping existing process'
  else
    start_with_logs \
      'celery-beat' \
      "$BACKEND_DIR" \
      "cd \"$BACKEND_DIR\" && REDIS_URL=\"$RUNTIME_REDIS_URL\" CACHE_URL=\"$RUNTIME_CACHE_URL\" CELERY_BROKER_URL=\"$RUNTIME_CELERY_BROKER_URL\" CELERY_RESULT_BACKEND=\"$RUNTIME_CELERY_RESULT_BACKEND\" OLLAMA_BASE_URL=\"$OLLAMA_BASE_URL\" OLLAMA_MODEL=\"$OLLAMA_MODEL\" ./.venv/bin/celery -A config beat -l info"
  fi
}

start_frontend() {
  if port_is_open '127.0.0.1' '3000'; then
    log_warn 'frontend port 3000 already in use; keeping existing process'
    return
  fi

  start_with_logs \
    'frontend-start' \
    "$FRONTEND_DIR" \
    "cd \"$FRONTEND_DIR\" && NEXT_PUBLIC_API_URL=\"$RUNTIME_FRONTEND_API_URL\" npm run start"
  wait_for_http 'http://127.0.0.1:3000' 'frontend' 90
}

show_summary() {
  printf '%b+------------------------------------------------------------------------------+%b\n' "$CYAN" "$RESET"
  printf '%b|%b %-76s %b|%b\n' "$CYAN" "$GREEN" 'BOOT SEQUENCE COMPLETE' "$CYAN" "$RESET"
  printf '%b|%b %-76s %b|%b\n' "$CYAN" "$DIM" 'backend : http://127.0.0.1:8000/api' "$CYAN" "$RESET"
  printf '%b|%b %-76s %b|%b\n' "$CYAN" "$DIM" 'frontend: http://127.0.0.1:3000' "$CYAN" "$RESET"
  printf '%b|%b %-76s %b|%b\n' "$CYAN" "$DIM" "logs    : $LOG_DIR" "$CYAN" "$RESET"
  printf '%b+------------------------------------------------------------------------------+%b\n' "$CYAN" "$RESET"
}

run_flutter_linux() {
  log_step 'launching flutter linux app in foreground'
  printf '%b' "$RESET"
  cd "$MOBILE_DIR"
  flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
}

main() {
  banner

  require_dir "$BACKEND_DIR" 'backend directory'
  require_dir "$FRONTEND_DIR" 'frontend directory'
  require_dir "$MOBILE_DIR" 'mobile directory'

  ensure_env_file "$BACKEND_DIR/.env" "$BACKEND_DIR/.env.example"
  ensure_env_file "$FRONTEND_DIR/.env" "$FRONTEND_DIR/.env.example"

  stop_managed_processes
  load_backend_env
  ensure_postgres
  ensure_redis
  ensure_ollama
  prepare_backend
  prepare_frontend
  prepare_mobile
  start_backend_stack
  start_frontend
  show_summary
  run_flutter_linux
}

main "$@"
