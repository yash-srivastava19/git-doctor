#!/usr/bin/env bats
# Integration tests for git-doctor commands
# These tests create a real temporary git repo and run the CLI end-to-end.

load '../test_helper'

setup() {
  setup_repo

  # Add a few commits: some good, some WIP
  add_commit "feat(api): add REST endpoint for user creation" "src/api.sh"
  add_commit "wip" "src/wip.sh"
  add_commit "fix(auth): handle expired tokens correctly" "src/auth.sh"
  add_commit "temp" "src/temp.sh"
  add_commit "docs(readme): add API usage examples" "README.md"
}

teardown() {
  teardown_repo
}

# ── git doctor status ─────────────────────────────────────────────────────────

@test "status: exits successfully" {
  run run_gd status
  [ "$status" -eq 0 ]
}

@test "status: shows branch name" {
  run run_gd status
  [[ "$output" == *"feat/test-branch"* ]]
}

@test "status: shows base branch" {
  run run_gd status
  [[ "$output" == *"main"* ]]
}

@test "status: shows commit count" {
  run run_gd status
  [[ "$output" == *"5"* ]]
}

@test "status: detects WIP commits" {
  run run_gd status
  [[ "$output" == *"WIP"* ]]
}

@test "status: default invocation (no subcommand) works" {
  run run_gd
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat/test-branch"* ]]
}

# ── git doctor history ────────────────────────────────────────────────────────

@test "history: exits successfully" {
  run run_gd history
  [ "$status" -eq 0 ]
}

@test "history: shows commit hashes" {
  run run_gd history
  # hashes are short hex strings — at least one should appear
  [[ "$output" =~ [0-9a-f]{6,7} ]]
}

@test "history: shows WIP marker for 'wip' commit" {
  run run_gd history
  [[ "$output" == *"wip"* ]]
}

@test "history: shows summary line" {
  run run_gd history
  [[ "$output" == *"Summary"* ]]
}

@test "history: 'h' alias works" {
  run run_gd h
  [ "$status" -eq 0 ]
}

@test "history: 'log' alias works" {
  run run_gd log
  [ "$status" -eq 0 ]
}

# ── git doctor pr ─────────────────────────────────────────────────────────────

@test "pr: exits successfully even with WIP commits" {
  run run_gd pr
  [ "$status" -eq 0 ]
}

@test "pr: reports WIP commits as issues" {
  run run_gd pr
  [[ "$output" == *"WIP"* ]]
}

@test "pr: shows changed files section" {
  run run_gd pr
  [[ "$output" == *"Changed"* ]]
}

@test "pr: 'review' alias works" {
  run run_gd review
  [ "$status" -eq 0 ]
}

# ── git doctor config ─────────────────────────────────────────────────────────

@test "config: exits successfully" {
  run run_gd config
  [ "$status" -eq 0 ]
}

@test "config: shows GD_MIN_MSG_LEN" {
  run run_gd config
  [[ "$output" == *"GD_MIN_MSG_LEN"* ]]
}

@test "config: shows configured per-repo base branch" {
  run run_gd config
  [[ "$output" == *"main"* ]]
}

@test "config: 'conf' alias works" {
  run run_gd conf
  [ "$status" -eq 0 ]
}

# ── git doctor help ───────────────────────────────────────────────────────────

@test "help: exits successfully" {
  run run_gd help
  [ "$status" -eq 0 ]
}

@test "help: shows available commands" {
  run run_gd help
  [[ "$output" == *"history"* ]]
  [[ "$output" == *"squash"* ]]
  [[ "$output" == *"organize"* ]]
  [[ "$output" == *"pr"* ]]
}

@test "help: --help flag works" {
  run run_gd --help
  [ "$status" -eq 0 ]
}

@test "help: -h flag works" {
  run run_gd -h
  [ "$status" -eq 0 ]
}

# ── git doctor version ────────────────────────────────────────────────────────

@test "version: prints version string" {
  run run_gd version
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-doctor v"* ]]
}

@test "version: --version flag works" {
  run run_gd --version
  [ "$status" -eq 0 ]
}

# ── Error cases ───────────────────────────────────────────────────────────────

@test "unknown subcommand: exits non-zero" {
  run run_gd nonexistent-command
  [ "$status" -ne 0 ]
}

# ── Clean branch (no WIP) ─────────────────────────────────────────────────────

@test "pr: ready message when no WIP and good messages" {
  # Create a fresh branch with only good commits
  git checkout main
  git checkout -b feat/clean-branch
  git config gitdoctor.basebranch main
  add_commit "feat(api): implement rate limiting" "ratelimit.sh"
  add_commit "test(api): add rate limit integration tests" "ratelimit_test.sh"

  run run_gd pr
  [ "$status" -eq 0 ]
  [[ "$output" == *"No WIP commits"* ]]
}

# ── Empty branch ──────────────────────────────────────────────────────────────

@test "status: handles branch with no commits" {
  git checkout main
  git checkout -b feat/empty-branch
  git config gitdoctor.basebranch main

  run run_gd status
  [ "$status" -eq 0 ]
}

@test "history: handles branch with no commits" {
  git checkout main
  git checkout -b feat/no-commits
  git config gitdoctor.basebranch main

  run run_gd history
  [ "$status" -eq 0 ]
}
