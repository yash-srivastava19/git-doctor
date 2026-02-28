#!/usr/bin/env bash
# git-doctor: terminal formatting library
# Sourced by git-doctor CLI. All output goes to stdout (CLI tool, not hooks).

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  MAGENTA='\033[0;35m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
  C_ERROR="$RED"
  C_WARN="$YELLOW"
  C_OK="$GREEN"
  C_INFO="$CYAN"
  C_DIM='\033[0;90m'
  C_BOLD="$BOLD"
  C_MAGENTA="$MAGENTA"
else
  RED='' YELLOW='' GREEN='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' RESET=''
  C_ERROR='' C_WARN='' C_OK='' C_INFO='' C_DIM='' C_BOLD='' C_MAGENTA=''
fi

SYM_ERROR="${C_ERROR}✗${RESET}"
SYM_WARN="${C_WARN}⚠${RESET}"
SYM_OK="${C_OK}✓${RESET}"
SYM_INFO="${C_INFO}→${RESET}"

gd_header() {
  printf "\n${C_BOLD}${C_MAGENTA}[git-doctor]${RESET} %s\n\n" "$*"
}

gd_box() {
  local title="$*"
  local width=42
  local pad=$(( (width - ${#title}) / 2 ))
  printf "${C_BOLD}"
  printf '╔'; printf '═%.0s' $(seq 1 $width); printf '╗\n'
  printf '║%*s%s%*s║\n' "$pad" "" "$title" $(( width - pad - ${#title} )) ""
  printf '╚'; printf '═%.0s' $(seq 1 $width); printf '╝\n'
  printf "${RESET}"
}

gd_error() {
  printf "  ${SYM_ERROR} ${C_ERROR}%s${RESET}\n" "$*"
}

gd_warn() {
  printf "  ${SYM_WARN} ${C_WARN}%s${RESET}\n" "$*"
}

gd_ok() {
  printf "  ${SYM_OK} ${C_OK}%s${RESET}\n" "$*"
}

gd_info() {
  printf "  ${SYM_INFO} %s\n" "$*"
}

gd_dim() {
  printf "  ${C_DIM}%s${RESET}\n" "$*"
}

gd_separator() {
  printf "  ${C_DIM}%s${RESET}\n" "─────────────────────────────────────────"
}

gd_label() {
  # gd_label "Branch" "feat/my-feature"
  printf "  ${C_DIM}%-12s${RESET} %s\n" "$1" "$2"
}
