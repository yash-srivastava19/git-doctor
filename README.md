# git-doctor

**Clean up messy commit history before it becomes a reviewer's problem.**

[![CI](https://github.com/yash-srivastava19/git-doctor/actions/workflows/ci.yml/badge.svg)](https://github.com/yash-srivastava19/git-doctor/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-1.1.0-blue)
![Shell](https://img.shields.io/badge/shell-bash%203.2%2B-green)

---

`git-doctor` is a git subcommand that diagnoses your branch's commit history, flags WIP noise, and gives you structured ways to clean up — squash, reorder, or re-commit — before you open a PR.

No external dependencies. No Python, no Node. Pure bash + git.

```
$ git doctor

╔══════════════════════════════════════════╗
║        git-doctor diagnosis              ║
╚══════════════════════════════════════════╝

  Branch       feat/auth → main
  Commits      7
  WIP          3 ⚠  (WIP commits — squash before PR)
  Quality      2 good  1 ok  2 vague  2 bad
  Changes      14 files changed, 532 insertions(+), 18 deletions(-)

  ─────────────────────────────────────────
  → Run git doctor history to see all commits
  → Run git doctor squash  to clean up before PR
```

---

## Why?

Most developers accumulate "wip", "temp", "fix", and "update" commits while working. These are fine locally, but messy PRs slow down code review. `git-doctor` makes it easy to find and fix them before they ever reach a reviewer.

---

## Features

- **Diagnose** — branch health overview: WIP count, message quality breakdown, diff stats
- **History** — annotated commit log with per-commit quality ratings (GOOD / OK / WARN / BAD)
- **Squash** — four strategies: squash all, auto-squash WIP only, full interactive rebase, last N
- **Organize** — group commits by inferred topic, then apply via auto-rebase, editor, or guided re-commit
- **PR check** — pre-flight checklist: WIP commits, vague messages, conflict markers, sync with origin
- **Lazygit integration** — all commands bound to keyboard shortcuts in the commits panel
- **Claude Code skills** — AI-powered `/git-tidy`, `/git-pr-desc`, `/git-precheck` companions

---

## Install

**One-liner:**

```bash
git clone https://github.com/yash-srivastava19/git-doctor ~/.git-doctor-src \
  && bash ~/.git-doctor-src/install.sh
```

This installs to `~/.git-doctor/` and symlinks the binary to `~/.local/bin/git-doctor`.

**Requirements:** bash 3.2+, git 2.x, standard Unix tools (awk, sed)

**Verify:**

```bash
git doctor --version
# git-doctor v1.1.0
```

---

## Commands

### `git doctor` — Branch health overview

```
$ git doctor

╔══════════════════════════════════════════╗
║        git-doctor diagnosis              ║
╚══════════════════════════════════════════╝

  Branch       feat/auth → main
  Commits      7
  WIP          3 ⚠  (WIP commits — squash before PR)
  Quality      2 good  1 ok  2 vague  2 bad
  Changes      14 files changed, 532 insertions(+), 18 deletions(-)

  ─────────────────────────────────────────
  → Run git doctor history to see all commits
  → Run git doctor squash  to clean up before PR
```

Aliases: `status`, `diagnose`, `check`

---

### `git doctor history` — Annotated commit log

```
$ git doctor history

[git-doctor] 7 commits on feat/auth since main

  ✓ a1b2c3d  feat(auth): add JWT token validation
  → d4e5f6a  Add login endpoint handler
  ⚠ b7c8d9e  update stuff                          ← WIP — squash this
  ✗ f0a1b2c  wip                                   ← WIP — squash this
  ✗ c3d4e5f  temp                                  ← WIP — squash this
  → a6b7c8d  Add request middleware
  ✗ d9e0f1a  fix                                   ← too short

  ─────────────────────────────────────────
  Summary:  1 ✓  2 ok  1 ⚠  3 ✗

  → Run git doctor squash to consolidate these commits.
```

Legend:  `✓` good  `→` ok  `⚠` vague  `✗` bad/WIP

Aliases: `log`, `h`

---

### `git doctor squash [N]` — Squash helper

```
$ git doctor squash

[git-doctor] 7 commits on feat/auth since main (3 WIP)

  ...commit list...

  How would you like to squash?

  [1] Squash ALL 7 into one clean commit   ← clean slate
  [2] Auto-squash 3 WIP commits            ← keep meaningful ones
  [3] Full interactive rebase              ← you decide everything
  [4] Squash last N commits  (enter N)
  [q] Cancel
```

Pass `N` directly to skip the menu: `git doctor squash 3`

Aliases: `s`

---

### `git doctor organize` — Group commits by topic

Detects the logical topics your commits belong to (inferred from conventional commit scopes, directory names, or file types) and offers to reorder and fixup-squash them.

```
$ git doctor organize

[git-doctor] Organize commits on feat/mixed-work

  Current order (oldest → newest):
  ✗ a1b2c3d  wip                     topic: auth
  ✓ b4c5d6e  feat(auth): add login   topic: auth
  ✗ c7d8e9f  temp                    topic: payments
  ✓ d0e1f2a  feat(pay): stripe setup topic: payments
  ✗ e3f4a5b  fixup                   topic: auth
  ✓ f6a7b8c  fix(auth): token expiry topic: auth

  Proposed grouping (oldest → newest):
  ── auth ──────────────────────────────────
    fixup  a1b2c3d  wip
    fixup  e3f4a5b  fixup
    pick   b4c5d6e  feat(auth): add login
    fixup  ↑        f6a7b8c  fix(auth): token expiry

  ── payments ──────────────────────────────
    fixup  c7d8e9f  temp
    pick   d0e1f2a  feat(pay): stripe setup

  What would you like to do?

  [1] Apply this plan               ← auto-rebase, no editor
  [2] Review & edit the rebase todo ← opens in $EDITOR
  [3] Guided re-commit              ← soft reset, commit group by group
  [q] Cancel
```

Aliases: `org`, `o`

---

### `git doctor pr` — Pre-PR checklist

```
$ git doctor pr

[git-doctor] Pre-PR check: feat/auth → main

  ✓ No WIP commits
  ✓ Commit messages look descriptive
  ✓ No merge conflict markers
  ✓ Up to date with origin/main

  ─────────────────────────────────────────
  Changed    14 files changed, 532 insertions(+), 18 deletions(-)
  PR title   feat(auth): add JWT authentication with refresh tokens

  ✓ Ready for PR!
```

Aliases: `review`

---

### `git doctor config` — Show configuration

```
$ git doctor config

[git-doctor] Configuration

  Global       ~/.git-doctor/config
  Repo         .git-doctor

  GD_WIP_THRESHOLD    5
  GD_MIN_MSG_LEN      10
  GD_PROTECTED        main master
  Base branch         auto-detect
```

Aliases: `conf`

---

## Configuration

### Global config: `~/.git-doctor/config`

```bash
GD_MIN_MSG_LENGTH=10        # minimum commit message length (chars)
GD_WIP_THRESHOLD=5          # legacy, kept for compatibility
GD_PROTECTED_BRANCHES="main master develop"
```

### Per-repo override: `.git-doctor` (in repo root)

```bash
GD_MIN_MSG_LENGTH=15        # stricter standard for this repo
```

### Per-repo base branch

```bash
git config gitdoctor.basebranch develop
```

By default, `git-doctor` auto-detects the base branch by checking: per-repo config → remote HEAD → local `main`/`master`/`develop`/`trunk` → fallback `master`.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `GD_HOME` | `~/.git-doctor` | Installation directory |
| `GD_MIN_MSG_LENGTH` | `10` | Minimum commit message length |
| `GD_PROTECTED_BRANCHES` | `"main master"` | Branches blocked from organize/squash |
| `NO_COLOR` | unset | Set to any value to disable ANSI colors |

---

## Lazygit Integration

Copy the provided config to your lazygit custom commands:

```bash
# Append to your lazygit config (usually ~/.config/lazygit/config.yml)
cat ~/.git-doctor/config/lazygit.yml >> ~/.config/lazygit/config.yml
```

This adds four bindings in the **commits panel**:

| Key | Command |
|-----|---------|
| `Ctrl+H` | `git doctor history` |
| `Ctrl+S` | `git doctor squash` |
| `Ctrl+P` | `git doctor pr` |
| `Ctrl+O` | `git doctor organize` |

---

## Claude Code Skills

If you use [Claude Code](https://claude.ai/claude-code), the `.claude/commands/` directory provides three AI-powered companions:

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/git-tidy` | messy branch | AI analyzes commits, groups them logically, applies via soft reset |
| `/git-pr-desc` | before PR | Generates a structured PR description from your diff |
| `/git-precheck` | before review | Scans for secrets, debug statements, conflict markers, TODOs |

These complement `git doctor` — use `git-doctor` for deterministic local checks and the skills for AI-assisted judgment calls.

---

## How commit quality is rated

| Rating | Criteria |
|--------|----------|
| **GOOD** | Follows [Conventional Commits](https://www.conventionalcommits.org): `feat(scope): description` |
| **OK** | Descriptive, ≥ 10 chars, not a WIP noise word |
| **WARN** | Subject > 72 chars, or all-lowercase short phrase |
| **BAD** | < 10 chars, or matches a WIP noise word (`wip`, `temp`, `fix`, `update`, `changes`, …) |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

In short: fork → feature branch → tests pass → PR.

```bash
# Run tests (requires bats-core)
make test

# Run linter (requires shellcheck)
make lint
```

---

## License

MIT — see [LICENSE](LICENSE).
