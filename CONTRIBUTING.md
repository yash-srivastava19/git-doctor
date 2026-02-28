# Contributing to git-doctor

Thanks for your interest in contributing! git-doctor is a pure-bash tool, so
the bar for contribution is low — no build system, no dependencies to install.

---

## Development setup

```bash
git clone https://github.com/yash-srivastava19/git-doctor
cd git-doctor

# Install locally (uses symlink so edits take effect immediately)
bash install.sh

# Verify
git doctor --version
```

Changes to `lib/` and `bin/git-doctor` are picked up immediately via the
symlink — no reinstall needed.

---

## Running tests

Tests use [bats-core](https://github.com/bats-core/bats-core).

```bash
# Install bats-core (Linux)
git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
sudo /tmp/bats-core/install.sh /usr/local

# Install bats-core (macOS)
brew install bats-core

# Run all tests
make test

# Run just unit tests
bats tests/unit/

# Run just integration tests
bats tests/integration/

# Run a single test file
bats tests/unit/test_classify.bats
```

---

## Linting

```bash
# Install shellcheck (Linux)
sudo apt install shellcheck

# Install shellcheck (macOS)
brew install shellcheck

# Run linter
make lint
```

All shell files must pass `shellcheck -S warning` before merging.

---

## Project structure

```
bin/
  git-doctor          Main CLI entry point (v1.1.0)
lib/
  colors.sh           Terminal formatting (colors, symbols, print helpers)
  checks.sh           Core analysis: classification, git context, config
  organize.sh         Organize command: topic inference, grouping, strategies
config/
  lazygit.yml         Lazygit custom command bindings
tests/
  test_helper.bash    Shared setup/teardown for bats tests
  unit/               Unit tests (no git repo required)
  integration/        End-to-end tests (creates temp git repos)
.claude/
  commands/           Claude Code skill definitions
install.sh            Installer — copies to ~/.git-doctor, symlinks binary
Makefile              Developer shortcuts (test, lint, install)
```

---

## Coding conventions

- **Bash 3.2+ compatible** — no associative arrays (`declare -A`), no `mapfile`.
  Use parallel indexed arrays (`arr_keys[i]` / `arr_vals[i]`).
- **`set -euo pipefail`** — the main script runs with strict mode. Library
  functions must be safe under it (use `|| true` where needed).
- **No external deps** — only git + standard POSIX tools (awk, sed, grep, etc.).
  `tac` (GNU) is not available on macOS; use `awk '{a[NR]=$0} END{while(NR)print a[NR--]}'` instead.
- **Colors via lib** — always use `gd_error / gd_warn / gd_ok / gd_info / gd_dim`.
  Never write raw escape codes in command functions.
- **NO_COLOR respected** — `lib/colors.sh` sets all vars to empty when `NO_COLOR`
  is set or stdout is not a TTY. Don't break this.
- **Conventional commits** — use `feat / fix / docs / chore / refactor / test` prefixes.

---

## Adding a new command

1. Add a `cmd_mycommand()` function to `bin/git-doctor`.
2. Add it to the `case "$cmd" in` dispatch block at the bottom.
3. Add any reusable helpers to `lib/checks.sh` (or a new lib file if large).
4. Add integration tests in `tests/integration/`.
5. Update the `cmd_help()` output and `README.md`.

---

## Pull request checklist

- [ ] Tests pass: `make test`
- [ ] Linter passes: `make lint`
- [ ] Works on both Linux and macOS (test locally or trust CI)
- [ ] `README.md` updated if new commands or config added
- [ ] `CHANGELOG.md` entry added under `[Unreleased]`
- [ ] Commits follow conventional commit format

---

## Reporting bugs

Open an issue at https://github.com/yash-srivastava19/git-doctor/issues.

Include:
- Your OS and bash version (`bash --version`)
- Your git version (`git --version`)
- The command that failed and its output
- The output of `git doctor config`
