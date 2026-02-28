#!/usr/bin/env bats
# Unit tests for gd_is_wip

load '../test_helper'

setup() {
  load_libs
}

# ── Should be detected as WIP ─────────────────────────────────────────────────

@test "detects 'wip'" {
  run gd_is_wip "wip"
  [ "$status" -eq 0 ]
}

@test "detects 'WIP' (case insensitive)" {
  run gd_is_wip "WIP"
  [ "$status" -eq 0 ]
}

@test "detects 'temp'" {
  run gd_is_wip "temp"
  [ "$status" -eq 0 ]
}

@test "detects 'temporary'" {
  run gd_is_wip "temporary"
  [ "$status" -eq 0 ]
}

@test "detects 'fixup'" {
  run gd_is_wip "fixup"
  [ "$status" -eq 0 ]
}

@test "detects 'squash'" {
  run gd_is_wip "squash"
  [ "$status" -eq 0 ]
}

@test "detects 'squash me'" {
  run gd_is_wip "squash me"
  [ "$status" -eq 0 ]
}

@test "detects 'hack'" {
  run gd_is_wip "hack"
  [ "$status" -eq 0 ]
}

@test "detects 'xxx'" {
  run gd_is_wip "xxx"
  [ "$status" -eq 0 ]
}

@test "detects 'oops'" {
  run gd_is_wip "oops"
  [ "$status" -eq 0 ]
}

@test "detects 'asdf'" {
  run gd_is_wip "asdf"
  [ "$status" -eq 0 ]
}

@test "detects 'test commit'" {
  run gd_is_wip "test commit"
  [ "$status" -eq 0 ]
}

@test "detects 'done'" {
  run gd_is_wip "done"
  [ "$status" -eq 0 ]
}

@test "detects 'ok'" {
  run gd_is_wip "ok"
  [ "$status" -eq 0 ]
}

@test "detects 'checkpoint'" {
  run gd_is_wip "checkpoint"
  [ "$status" -eq 0 ]
}

@test "detects 'update'" {
  run gd_is_wip "update"
  [ "$status" -eq 0 ]
}

@test "detects 'changes'" {
  run gd_is_wip "changes"
  [ "$status" -eq 0 ]
}

@test "detects 'misc'" {
  run gd_is_wip "misc"
  [ "$status" -eq 0 ]
}

@test "detects 'stuff'" {
  run gd_is_wip "stuff"
  [ "$status" -eq 0 ]
}

@test "detects 'cleanup'" {
  run gd_is_wip "cleanup"
  [ "$status" -eq 0 ]
}

@test "detects 'refactor'" {
  run gd_is_wip "refactor"
  [ "$status" -eq 0 ]
}

@test "detects leading whitespace before wip" {
  run gd_is_wip "  wip"
  [ "$status" -eq 0 ]
}

# ── Should NOT be detected as WIP ────────────────────────────────────────────

@test "does not flag conventional commit" {
  run gd_is_wip "feat(auth): add OAuth login"
  [ "$status" -ne 0 ]
}

@test "does not flag descriptive message" {
  run gd_is_wip "Add user authentication module"
  [ "$status" -ne 0 ]
}

@test "does not flag fix with context" {
  run gd_is_wip "fix null pointer in login handler"
  [ "$status" -ne 0 ]
}

@test "does not flag message starting with wip keyword but longer" {
  run gd_is_wip "update user profile settings"
  [ "$status" -ne 0 ]
}

@test "does not flag refactor with context" {
  run gd_is_wip "refactor authentication to use services"
  [ "$status" -ne 0 ]
}

@test "does not flag empty string" {
  run gd_is_wip ""
  [ "$status" -ne 0 ]
}
