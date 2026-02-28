#!/usr/bin/env bash
# Shared setup helpers for git-doctor bats tests

# Project root — two levels up from tests/
GD_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source git-doctor libs for unit tests (no git context needed)
load_libs() {
  # Prevent config file from interfering with tests
  export GD_HOME="/nonexistent-gd-home-for-tests"
  export GD_MIN_MSG_LENGTH=10
  export GD_WIP_THRESHOLD=5
  export GD_PROTECTED_BRANCHES="main master"
  export NO_COLOR=1  # no ANSI codes in test output

  # shellcheck source=/dev/null
  source "$GD_REPO_ROOT/lib/colors.sh"
  # shellcheck source=/dev/null
  source "$GD_REPO_ROOT/lib/checks.sh"
}

# Create a temp git repo for integration tests
# Sets TEST_REPO and cd's into it
setup_repo() {
  TEST_REPO="$(mktemp -d)"
  export TEST_REPO

  cd "$TEST_REPO" || return 1

  git init -b main
  git config user.email "test@git-doctor.local"
  git config user.name "Git Doctor Test"
  git config commit.gpgsign false
  # Fix base branch detection to avoid slow 'git remote show origin'
  git config gitdoctor.basebranch main

  # Initial commit on main
  echo "# Project" > README.md
  git add README.md
  git commit -m "feat: initial project setup"

  # Branch for tests
  git checkout -b feat/test-branch
}

teardown_repo() {
  if [[ -n "${TEST_REPO:-}" && -d "$TEST_REPO" ]]; then
    rm -rf "$TEST_REPO"
  fi
  # Return to repo root so bats doesn't get confused
  cd "$GD_REPO_ROOT" || true
}

# Run git-doctor from the test repo
run_gd() {
  GD_HOME="/nonexistent-gd-home-for-tests" \
  NO_COLOR=1 \
  bash "$GD_REPO_ROOT/bin/git-doctor" "$@"
}

# Add a commit with the given message
add_commit() {
  local msg="$1"
  local file="${2:-file_${RANDOM}.txt}"
  mkdir -p "$(dirname "$file")"
  echo "$msg" >> "$file"
  git add "$file"
  git commit -m "$msg"
}
