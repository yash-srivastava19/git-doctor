#!/usr/bin/env bash
# install.sh — install git-doctor to ~/.git-doctor and symlink into PATH
set -euo pipefail

GD_HOME="${GD_HOME:-$HOME/.git-doctor}"
BIN_LINK="${GD_BIN_LINK:-$HOME/.local/bin/git-doctor}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()  { printf "  ${CYAN}→${RESET} %s\n" "$*"; }
ok()    { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
bold()  { printf "${BOLD}%s${RESET}\n" "$*"; }

bold ""
bold "  git-doctor installer"
printf "  ${DIM}Installing to: ${GD_HOME}${RESET}\n"
echo ""

# 1. Create directory structure
mkdir -p "$GD_HOME/lib" "$GD_HOME/bin" "$GD_HOME/config"
info "Created ${GD_HOME}/{lib,bin,config}"

# 2. Copy library files
for lib_file in colors.sh checks.sh organize.sh; do
  src="$SCRIPT_DIR/lib/$lib_file"
  if [[ -f "$src" ]]; then
    cp "$src" "$GD_HOME/lib/$lib_file"
    ok "Installed lib/$lib_file"
  else
    printf "  ⚠ lib/%s not found — skipping\n" "$lib_file"
  fi
done

# 3. Copy and chmod binary
cp "$SCRIPT_DIR/bin/git-doctor" "$GD_HOME/bin/git-doctor"
chmod +x "$GD_HOME/bin/git-doctor"
ok "Installed bin/git-doctor"

# 4. Write default config if missing
config_file="$GD_HOME/config"
if [[ ! -f "$config_file" ]]; then
  cat > "$config_file" <<'EOF'
# git-doctor global configuration
# Override any of these in a per-repo .git-doctor file

# Number of chars a commit message must have to not be BAD
GD_MIN_MSG_LENGTH=10

# A commit length below this is considered a WIP (legacy, kept for compat)
GD_WIP_THRESHOLD=5

# Space-separated branch names that are protected (organize/squash refused)
GD_PROTECTED_BRANCHES="main master"
EOF
  ok "Wrote default config to ${config_file}"
else
  info "Keeping existing config at ${config_file}"
fi

# 5. Copy lazygit config example (never overwrite)
lazygit_dest="$GD_HOME/config/lazygit.yml"
if [[ ! -f "$lazygit_dest" ]] && [[ -f "$SCRIPT_DIR/config/lazygit.yml" ]]; then
  cp "$SCRIPT_DIR/config/lazygit.yml" "$lazygit_dest"
  ok "Copied config/lazygit.yml to ${lazygit_dest}"
fi

# 6. Symlink binary into PATH
link_dir="$(dirname "$BIN_LINK")"
mkdir -p "$link_dir"
if [[ -L "$BIN_LINK" ]]; then
  rm "$BIN_LINK"
fi
ln -s "$GD_HOME/bin/git-doctor" "$BIN_LINK"
ok "Symlinked git-doctor → ${BIN_LINK}"

# 7. Check PATH
echo ""
if command -v git-doctor &>/dev/null; then
  ok "git-doctor is on your PATH"
else
  printf "  ${BOLD}NOTE:${RESET} Add %s to your PATH:\n" "$link_dir"
  printf "        export PATH=\"%s:\$PATH\"\n" "$link_dir"
fi

echo ""
bold "  Installation complete!"
printf "  ${DIM}Try: git doctor help${RESET}\n\n"
printf "  ${DIM}Lazygit bindings: copy %s/config/lazygit.yml content into your lazygit config.${RESET}\n\n" "$GD_HOME"
