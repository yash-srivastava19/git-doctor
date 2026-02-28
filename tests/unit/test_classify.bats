#!/usr/bin/env bats
# Unit tests for gd_classify_message

load '../test_helper'

setup() {
  load_libs
}

# ── GOOD: conventional commit format ─────────────────────────────────────────

@test "GOOD: feat with scope" {
  run gd_classify_message "feat(auth): add OAuth login flow"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: fix with scope" {
  run gd_classify_message "fix(api): resolve null pointer in response handler"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: docs with scope" {
  run gd_classify_message "docs(readme): update installation instructions"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: feat without scope" {
  run gd_classify_message "feat: add user authentication support"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: chore with scope" {
  run gd_classify_message "chore(deps): upgrade jest to v29"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: refactor with scope" {
  run gd_classify_message "refactor(core): extract validation into service"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: test with scope" {
  run gd_classify_message "test(auth): add coverage for token expiry"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: ci commit" {
  run gd_classify_message "ci: add GitHub Actions workflow"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

@test "GOOD: perf with scope" {
  run gd_classify_message "perf(db): add index on user_id column"
  [ "$status" -eq 0 ]
  [ "$output" = "GOOD" ]
}

# ── BAD: WIP noise patterns ───────────────────────────────────────────────────

@test "BAD: 'wip' pattern" {
  run gd_classify_message "wip"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'WIP' case insensitive" {
  run gd_classify_message "WIP"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'temp'" {
  run gd_classify_message "temp"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'fixup'" {
  run gd_classify_message "fixup"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'update' (noise word)" {
  run gd_classify_message "update"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'changes'" {
  run gd_classify_message "changes"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'xxx'" {
  run gd_classify_message "xxx"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'done'" {
  run gd_classify_message "done"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: 'ok'" {
  run gd_classify_message "ok"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

# ── BAD: too short ─────────────────────────────────────────────────────────────

@test "BAD: empty string" {
  run gd_classify_message ""
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: single word (< 10 chars)" {
  run gd_classify_message "bug"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

@test "BAD: two words still short" {
  run gd_classify_message "fix bug"
  [ "$status" -eq 0 ]
  [ "$output" = "BAD" ]
}

# ── OK: descriptive but not conventional ──────────────────────────────────────

@test "OK: imperative sentence" {
  run gd_classify_message "Add user authentication support module"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "OK: mixed case sentence" {
  run gd_classify_message "Remove deprecated API endpoints from the service"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "OK: exactly 10 chars (boundary)" {
  run gd_classify_message "1234567890"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

# ── WARN: subject too long ────────────────────────────────────────────────────

@test "WARN: subject over 72 chars" {
  run gd_classify_message "This is a very long commit subject line that clearly exceeds the 72 character limit and should warn"
  [ "$status" -eq 0 ]
  [ "$output" = "WARN" ]
}

# ── WARN: all lowercase short phrase ─────────────────────────────────────────

@test "WARN: all lowercase short phrase" {
  run gd_classify_message "lowercase message here"
  [ "$status" -eq 0 ]
  [ "$output" = "WARN" ]
}

@test "WARN: all lowercase under 30 chars" {
  run gd_classify_message "add some features ok"
  [ "$status" -eq 0 ]
  [ "$output" = "WARN" ]
}
