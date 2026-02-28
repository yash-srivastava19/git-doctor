# Changelog

All notable changes to git-doctor are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

---

## [Unreleased]

---

## [1.1.0] — 2026-02-28

### Added
- `git doctor organize` (`org`, `o`) — groups messy commits by inferred topic,
  then offers three execution strategies:
  - **Auto-rebase** — applies the plan non-interactively
  - **Edit then rebase** — opens the todo in `$EDITOR` for manual tweaks
  - **Guided re-commit** — soft-resets and re-commits group by group
- Topic inference: conventional commit scope → top-level directory → file-type
  heuristics → filename stem → "misc" fallback
- Lazygit binding `Ctrl+O` → `git doctor organize`
- Claude Code skills: `/git-tidy`, `/git-pr-desc`, `/git-precheck`
- `git doctor version` / `--version` / `-v` subcommand

### Fixed
- `gd_suggest_message`: case statement missing `)` prevented CI files
  (`.github/`, `*.yml`, `Dockerfile*`) from incrementing `ci_score`,
  causing them to always score as `src` and suggest `feat:` prefix
- `tac` replaced with portable `awk` one-liner for macOS compatibility

---

## [1.0.0] — 2026-02-21

### Added
- `git doctor` / `status` / `diagnose` — branch health overview with WIP count,
  message quality breakdown, and diff stats
- `git doctor history` / `log` / `h` — annotated commit log with per-commit
  quality ratings (GOOD / OK / WARN / BAD)
- `git doctor squash` / `s [N]` — four squash strategies:
  1. Squash all into one commit
  2. Auto-squash WIP-only (rebase todo injection)
  3. Full interactive rebase
  4. Squash last N commits
- `git doctor pr` / `review` — pre-PR checklist: WIP detection, message quality,
  conflict markers, origin sync status, suggested PR title
- `git doctor config` / `conf` — show active configuration
- `git doctor help` — usage reference
- Three-tier config: global `~/.git-doctor/config` → per-repo `.git-doctor` →
  hardcoded defaults
- Per-repo base branch override: `git config gitdoctor.basebranch <branch>`
- Auto-detect base branch: remote HEAD → local main/master/develop/trunk
- Protected branch guard (blocks organize/squash on main, master, etc.)
- `lib/colors.sh` — terminal formatting with `NO_COLOR` and non-TTY support
- `lib/checks.sh` — core analysis: classification, git context, quality counts
- `install.sh` — installer to `~/.git-doctor/`, symlink to `~/.local/bin/`
- `config/lazygit.yml` — Ctrl+H/S/P bindings for lazygit commits panel
- Bash 3.2+ compatibility (parallel indexed arrays, no `declare -A`)

---

[Unreleased]: https://github.com/yash-srivastava19/git-doctor/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/yash-srivastava19/git-doctor/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/yash-srivastava19/git-doctor/releases/tag/v1.0.0
