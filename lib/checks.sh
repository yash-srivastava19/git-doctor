#!/usr/bin/env bash
# git-doctor: core check and analysis functions
# Sourced by the git-doctor CLI. Requires colors.sh to be sourced first.

GD_HOME="${GD_HOME:-$HOME/.git-doctor}"

# ── Configuration ──────────────────────────────────────────────────────────

gd_load_config() {
  # Source global config
  if [[ -f "$GD_HOME/config" ]]; then
    # shellcheck source=/dev/null
    source "$GD_HOME/config"
  fi
  # Per-repo override
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$repo_root" && -f "$repo_root/.git-doctor" ]]; then
    source "$repo_root/.git-doctor"
  fi
  # Defaults
  GD_WIP_THRESHOLD="${GD_WIP_THRESHOLD:-5}"
  GD_MIN_MSG_LENGTH="${GD_MIN_MSG_LENGTH:-10}"
  GD_PROTECTED_BRANCHES="${GD_PROTECTED_BRANCHES:-main master}"
}

# ── Git context ────────────────────────────────────────────────────────────

gd_require_repo() {
  if ! git rev-parse --git-dir &>/dev/null; then
    printf "  Not inside a git repository.\n" >&2
    exit 1
  fi
}

gd_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "HEAD"
}

gd_base_branch() {
  # 1. Per-repo config
  local configured
  configured="$(git config gitdoctor.basebranch 2>/dev/null)"
  if [[ -n "$configured" ]]; then echo "$configured"; return; fi

  # 2. Remote HEAD (fast path — cached after first call, use timeout to avoid hang)
  local remote_head
  remote_head="$(git remote show origin 2>/dev/null | awk '/HEAD branch:/{print $NF}')"
  if [[ -n "$remote_head" && "$remote_head" != "(unknown)" ]]; then
    echo "$remote_head"; return
  fi

  # 3. Local branches in priority order
  local candidates=("main" "master" "develop" "development" "trunk")
  local current
  current="$(gd_current_branch)"
  for b in "${candidates[@]}"; do
    if [[ "$b" != "$current" ]] && git show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then
      echo "$b"; return
    fi
  done

  # 4. Fallback
  echo "master"
}

gd_merge_base() {
  local base
  base="$(gd_base_branch)"
  # Try local branch first, then remote tracking
  git merge-base HEAD "refs/heads/$base" 2>/dev/null \
    || git merge-base HEAD "refs/remotes/origin/$base" 2>/dev/null \
    || git rev-list --max-parents=0 HEAD 2>/dev/null
}

gd_branch_commit_count() {
  local merge_base
  merge_base="$(gd_merge_base)"
  if [[ -z "$merge_base" ]]; then
    git rev-list --count HEAD 2>/dev/null || echo 0
  else
    git rev-list --count "${merge_base}..HEAD" 2>/dev/null || echo 0
  fi
}

# Returns lines of "HASH SUBJECT" for commits on this branch since base
gd_branch_log() {
  local merge_base
  merge_base="$(gd_merge_base)"
  if [[ -z "$merge_base" ]]; then
    git log --pretty=tformat:"%h %s" 2>/dev/null
  else
    git log --pretty=tformat:"%h %s" "${merge_base}..HEAD" 2>/dev/null
  fi
}

# ── Message classification ─────────────────────────────────────────────────

# WIP patterns — these commit messages are definitively "work in progress" noise
readonly GD_WIP_PATTERN='^(wip|fixup|squash|squash me|temp|temporary|hack|xxx|oops|asdf|asd|qwerty|qqq|zzz|aaa|test commit|test|commit|done|ok|yeah|untitled|checkpoint|save|savepoint|update|updates|changes|change|misc|stuff|fix|typo|cleanup|clean up|refactor)$'

# Bad message: matches WIP pattern or too short
gd_is_wip() {
  # Lowercase via tr for bash 3.2 / macOS compatibility
  local msg
  msg="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  msg="${msg#"${msg%%[![:space:]]*}"}"  # trim leading whitespace
  [[ "$msg" =~ $GD_WIP_PATTERN ]]
}

# GOOD: conventional commit format
readonly GD_CONVENTIONAL_PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert|wip)(\([a-zA-Z0-9_/-]+\))?: .{4,}'

gd_classify_message() {
  local msg="$1"
  local subject
  # Get just the subject line (first non-empty line)
  subject="$(echo "$msg" | grep -v '^#' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  local len=${#subject}

  # BAD: empty, too short, or WIP pattern
  if [[ $len -lt ${GD_MIN_MSG_LENGTH:-10} ]] || gd_is_wip "$subject"; then
    echo "BAD"; return
  fi

  # GOOD: conventional commit
  if [[ "$subject" =~ $GD_CONVENTIONAL_PATTERN ]]; then
    echo "GOOD"; return
  fi

  # WARN: subject too long (> 72 chars) or all lowercase single word
  if [[ $len -gt 72 ]] || [[ "$subject" =~ ^[a-z][a-z\ ]+$ && ! "$subject" =~ [A-Z] && ${#subject} -lt 30 ]]; then
    echo "WARN"; return
  fi

  echo "OK"
}

# Count WIP commits on current branch
gd_wip_count() {
  local count=0
  while IFS= read -r line; do
    local subject="${line#* }"  # strip hash prefix
    gd_is_wip "$subject" && (( ++count ))
  done < <(gd_branch_log)
  echo "$count"
}

# ── Message suggestion ─────────────────────────────────────────────────────

gd_suggest_message() {
  local merge_base
  merge_base="$(gd_merge_base)"
  local changed_files
  changed_files="$(git diff --name-only "${merge_base}..HEAD" 2>/dev/null)"

  if [[ -z "$changed_files" ]]; then
    echo "feat: <describe your changes>"
    return
  fi

  # Score file types to pick a conventional commit prefix
  local test_score=0 doc_score=0 ci_score=0 build_score=0 src_score=0

  while IFS= read -r f; do
    case "$f" in
      *test*|*spec*)  (( ++test_score )) ;;
      *.md|*.rst|*.txt|docs/*|doc/*)                 (( ++doc_score )) ;;
      .github/*|.circleci/*|*.yml|*.yaml|Dockerfile*)  (( ++ci_score )) ;;
      Makefile|package.json|*.toml|*.lock|setup.py)  (( ++build_score )) ;;
      *)                                              (( ++src_score )) ;;
    esac
  done <<< "$changed_files"

  local prefix
  if   (( test_score  > src_score  && test_score  > doc_score  )); then prefix="test"
  elif (( doc_score   > src_score  && doc_score   > test_score )); then prefix="docs"
  elif (( ci_score    > src_score                               )); then prefix="ci"
  elif (( build_score > src_score                               )); then prefix="build"
  else prefix="feat"
  fi

  # Try to extract a meaningful scope from changed paths
  local scope=""
  local top_dir
  top_dir="$(echo "$changed_files" | awk -F/ 'NF>1{print $1}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
  if [[ -n "$top_dir" && "$top_dir" != "." ]]; then
    scope="($top_dir)"
  fi

  echo "${prefix}${scope}: <describe your changes>"
}

# ── Diff stats ─────────────────────────────────────────────────────────────

gd_diff_stats() {
  local merge_base
  merge_base="$(gd_merge_base)"
  git diff --shortstat "${merge_base}..HEAD" 2>/dev/null \
    | sed 's/^ //' \
    | sed 's/changed,/files changed,/' 2>/dev/null \
    || echo "no changes"
}

gd_files_changed_count() {
  local merge_base
  merge_base="$(gd_merge_base)"
  git diff --name-only "${merge_base}..HEAD" 2>/dev/null | wc -l | tr -d ' '
}

# ── Quality scoring for history display ────────────────────────────────────

# Returns: symbol + reason string for display
gd_commit_display_quality() {
  local subject="$1"
  local quality
  quality="$(gd_classify_message "$subject")"
  case "$quality" in
    GOOD) printf "%s" "${SYM_OK}" ;;
    OK)   printf "%s" "${SYM_INFO}" ;;
    WARN) printf "%s" "${SYM_WARN}" ;;
    BAD)  printf "%s" "${SYM_ERROR}" ;;
  esac
}

gd_commit_reason() {
  local subject="$1"
  local len=${#subject}

  if [[ $len -lt ${GD_MIN_MSG_LENGTH:-10} ]]; then
    echo "too short"
  elif gd_is_wip "$subject"; then
    echo "WIP — squash this"
  elif [[ "$subject" =~ $GD_CONVENTIONAL_PATTERN ]]; then
    echo ""  # good, no reason needed
  elif [[ $len -gt 72 ]]; then
    echo "subject too long (${len} chars)"
  else
    echo ""
  fi
}

# ── Branch health summary ──────────────────────────────────────────────────

# Prints counts: good ok warn bad
gd_message_quality_counts() {
  local good=0 ok=0 warn=0 bad=0
  while IFS= read -r line; do
    local subject="${line#* }"
    case "$(gd_classify_message "$subject")" in
      GOOD) (( ++good )) ;;
      OK)   (( ++ok )) ;;
      WARN) (( ++warn )) ;;
      BAD)  (( ++bad )) ;;
    esac
  done < <(gd_branch_log)
  echo "$good $ok $warn $bad"
}
