#!/usr/bin/env bash
# git-doctor: organize — group messy commits into logical topics
# Sourced by bin/git-doctor. Requires colors.sh and checks.sh.

# ── Global state (parallel indexed arrays, bash 3 compatible) ────────────────

GD_ORG_GROUP_COUNT=0
GD_ORG_MERGE_BASE=""

# Indexed arrays — one entry per group
declare -a GD_ORG_GROUP_TOPIC   # topic string per group
declare -a GD_ORG_GROUP_ANCHOR  # "HASH SUBJECT" of the anchor commit
declare -a GD_ORG_GROUP_WIPS    # newline-separated "HASH SUBJECT" of WIP commits
declare -a GD_ORG_GROUP_SIZE    # total commits in group (1 anchor + N wips)

# ── Topic inference ───────────────────────────────────────────────────────────

# _org_infer_topic HASH SUBJECT
# Prints the topic string for a commit.
_org_infer_topic() {
  local hash="$1"
  local subject="$2"

  # Priority 1: conventional commit scope  feat(auth): ...  → "auth"
  if [[ "$subject" =~ ^[a-z]+\(([a-zA-Z0-9_/-]+)\): ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  # Priority 2: most common top-level dir touched by this commit
  local top_dir
  top_dir="$(git diff-tree --no-commit-id -r --name-only "$hash" 2>/dev/null \
    | awk -F/ 'NF>1{print $1}' \
    | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
  if [[ -n "$top_dir" ]]; then
    echo "$top_dir"
    return
  fi

  # Priority 3: extension heuristic on files touched
  local files
  files="$(git diff-tree --no-commit-id -r --name-only "$hash" 2>/dev/null)"
  if [[ -z "$files" ]]; then
    echo "misc"
    return
  fi

  local test_count=0 doc_count=0 cfg_count=0
  while IFS= read -r f; do
    case "$f" in
      *.test.*|*.spec.*|*_test.*|*test_*|*spec_*|*/test/*|*/tests/*|*/__tests__/*) (( ++test_count )) ;;
      *.md|*.rst|*.txt|*/docs/*|*/doc/*)                                             (( ++doc_count )) ;;
      *.yml|*.yaml|*.toml|*.json|*.ini|*.cfg|*.conf|Makefile|Dockerfile*)           (( ++cfg_count )) ;;
    esac
  done <<< "$files"

  local total
  total="$(echo "$files" | wc -l | tr -d ' ')"

  if (( test_count * 2 >= total && total > 0 )); then echo "tests"; return; fi
  if (( doc_count  * 2 >= total && total > 0 )); then echo "docs";  return; fi
  if (( cfg_count  * 2 >= total && total > 0 )); then echo "config"; return; fi

  # Fallback: root-level filename stem without extension
  local first_file
  first_file="$(echo "$files" | head -1)"
  local stem
  stem="$(basename "$first_file")"
  stem="${stem%%.*}"
  if [[ -n "$stem" && "$stem" != "." ]]; then
    echo "$stem"
    return
  fi

  echo "misc"
}

# ── Analysis ──────────────────────────────────────────────────────────────────

# gd_org_analyze
# Reads gd_branch_log (newest-first), classifies commits, groups by topic.
# Populates all GD_ORG_* globals.
# Returns 1 if there are no commits.
gd_org_analyze() {
  GD_ORG_GROUP_COUNT=0
  GD_ORG_COMMIT_COUNT=0
  GD_ORG_MERGE_BASE="$(gd_merge_base)"
  GD_ORG_GROUP_TOPIC=()
  GD_ORG_GROUP_ANCHOR=()
  GD_ORG_GROUP_WIPS=()
  GD_ORG_GROUP_SIZE=()

  # Pass 1: read all commits (newest-first) into parallel arrays
  local -a all_hashes all_subjects all_is_wip all_topics
  local commit_count=0

  while IFS= read -r line; do
    local hash="${line%% *}"
    local subject="${line#* }"
    all_hashes+=("$hash")
    all_subjects+=("$subject")
    if gd_is_wip "$subject"; then
      all_is_wip+=("1")
      all_topics+=("wip")
    else
      all_is_wip+=("0")
      all_topics+=("$(_org_infer_topic "$hash" "$subject")")
    fi
    (( ++commit_count ))
  done < <(gd_branch_log)

  if [[ "$commit_count" -eq 0 ]]; then
    return 1
  fi

  # Pass 2: assign WIP commits to nearest preceding anchor (newest-first order).
  # We work oldest-to-newest (reverse of the log) so we can build groups naturally.
  # Reverse the arrays first.
  local -a rev_hashes rev_subjects rev_is_wip rev_topics
  local i
  for (( i = commit_count - 1; i >= 0; i-- )); do
    rev_hashes+=("${all_hashes[$i]}")
    rev_subjects+=("${all_subjects[$i]}")
    rev_is_wip+=("${all_is_wip[$i]}")
    rev_topics+=("${all_topics[$i]}")
  done

  # Find index of first non-WIP commit (to handle leading WIPs)
  local first_anchor_idx=-1
  for (( i = 0; i < commit_count; i++ )); do
    if [[ "${rev_is_wip[$i]}" == "0" ]]; then
      first_anchor_idx="$i"
      break
    fi
  done

  # If ALL commits are WIP, force the oldest to be an anchor
  if [[ "$first_anchor_idx" -eq -1 ]]; then
    rev_is_wip[0]="0"
    rev_topics[0]="${rev_topics[0]:-misc}"
    first_anchor_idx=0
  fi

  # Build groups: each anchor starts a new group; WIPs before the first anchor
  # get attached to it.
  local cur_group_idx=-1
  local -a pending_wips  # buffer for WIPs before any anchor

  for (( i = 0; i < commit_count; i++ )); do
    local h="${rev_hashes[$i]}"
    local s="${rev_subjects[$i]}"
    local is_wip="${rev_is_wip[$i]}"
    local topic="${rev_topics[$i]}"

    if [[ "$is_wip" == "0" ]]; then
      # New anchor — start a new group
      (( cur_group_idx++ )) || true
      GD_ORG_GROUP_TOPIC[$cur_group_idx]="$topic"
      GD_ORG_GROUP_ANCHOR[$cur_group_idx]="$h $s"
      # Flush any pending WIPs into this group
      local wip_str=""
      local pending_count=0
      for pw in "${pending_wips[@]+"${pending_wips[@]}"}"; do
        wip_str+="$pw"$'\n'
        (( pending_count++ )) || true
      done
      GD_ORG_GROUP_WIPS[$cur_group_idx]="${wip_str%$'\n'}"
      GD_ORG_GROUP_SIZE[$cur_group_idx]=$(( 1 + pending_count ))
      pending_wips=()
    else
      if [[ "$cur_group_idx" -lt 0 ]]; then
        # WIP before any anchor — buffer it
        pending_wips+=("$h $s")
      else
        # Append WIP to current group
        local existing="${GD_ORG_GROUP_WIPS[$cur_group_idx]}"
        if [[ -z "$existing" ]]; then
          GD_ORG_GROUP_WIPS[$cur_group_idx]="$h $s"
        else
          GD_ORG_GROUP_WIPS[$cur_group_idx]="${existing}"$'\n'"$h $s"
        fi
        GD_ORG_GROUP_SIZE[$cur_group_idx]=$(( GD_ORG_GROUP_SIZE[$cur_group_idx] + 1 ))
      fi
    fi
  done

  GD_ORG_GROUP_COUNT=$(( cur_group_idx + 1 ))

  # Pass 3: merge adjacent groups with the same topic
  _org_merge_same_topic_groups
}

# _org_merge_same_topic_groups
# Collapses adjacent groups that share the same topic into one.
_org_merge_same_topic_groups() {
  if [[ "$GD_ORG_GROUP_COUNT" -le 1 ]]; then return; fi

  local -a new_topic new_anchor new_wips new_size
  local new_count=0

  # Groups are oldest-first in arrays (index 0 = oldest)
  new_topic[0]="${GD_ORG_GROUP_TOPIC[0]}"
  new_anchor[0]="${GD_ORG_GROUP_ANCHOR[0]}"
  new_wips[0]="${GD_ORG_GROUP_WIPS[0]}"
  new_size[0]="${GD_ORG_GROUP_SIZE[0]}"
  new_count=1

  local i
  for (( i = 1; i < GD_ORG_GROUP_COUNT; i++ )); do
    local prev=$(( new_count - 1 ))
    if [[ "${GD_ORG_GROUP_TOPIC[$i]}" == "${new_topic[$prev]}" ]]; then
      # Same topic as the previous group — merge: make old anchor a WIP, keep
      # the newer group's anchor (it has the "real" message if both are good)
      # Actually: keep older anchor, merge newer anchor+wips as wips
      local newer_anchor="${GD_ORG_GROUP_ANCHOR[$i]}"
      local newer_wips="${GD_ORG_GROUP_WIPS[$i]}"
      local combined_wips="${new_wips[$prev]}"
      # Append newer anchor as a wip
      if [[ -n "$combined_wips" ]]; then
        combined_wips+=$'\n'"$newer_anchor"
      else
        combined_wips="$newer_anchor"
      fi
      # Append newer group's wips
      if [[ -n "$newer_wips" ]]; then
        combined_wips+=$'\n'"$newer_wips"
      fi
      new_wips[$prev]="$combined_wips"
      new_size[$prev]=$(( new_size[$prev] + GD_ORG_GROUP_SIZE[$i] ))
    else
      new_topic[$new_count]="${GD_ORG_GROUP_TOPIC[$i]}"
      new_anchor[$new_count]="${GD_ORG_GROUP_ANCHOR[$i]}"
      new_wips[$new_count]="${GD_ORG_GROUP_WIPS[$i]}"
      new_size[$new_count]="${GD_ORG_GROUP_SIZE[$i]}"
      (( ++new_count ))
    fi
  done

  GD_ORG_GROUP_COUNT="$new_count"
  GD_ORG_GROUP_TOPIC=("${new_topic[@]}")
  GD_ORG_GROUP_ANCHOR=("${new_anchor[@]}")
  GD_ORG_GROUP_WIPS=("${new_wips[@]}")
  GD_ORG_GROUP_SIZE=("${new_size[@]}")
}

# ── Display helpers ───────────────────────────────────────────────────────────

# gd_org_display_before
# Shows the current messy commit list (reuses history inline style).
gd_org_display_before() {
  printf "  ${C_BOLD}Current commits${RESET} ${C_DIM}(newest first):${RESET}\n\n"
  local count=0
  while IFS= read -r line; do
    local hash="${line%% *}"
    local subject="${line#* }"
    local quality
    quality="$(gd_classify_message "$subject")"
    local sym
    case "$quality" in
      GOOD) sym="${SYM_OK}" ;;
      OK)   sym="${SYM_INFO}" ;;
      WARN) sym="${SYM_WARN}" ;;
      BAD)  sym="${SYM_ERROR}" ;;
    esac
    local display="$subject"
    if [[ ${#subject} -gt 56 ]]; then display="${subject:0:53}..."; fi
    printf "  %s ${C_DIM}%s${RESET}  %s\n" "$sym" "$hash" "$display"
    (( count++ )) || true
  done < <(gd_branch_log)
  echo ""
}

# gd_org_display_groups
# Shows the proposed grouping plan, oldest-first.
gd_org_display_groups() {
  printf "  ${C_BOLD}Proposed grouping${RESET} ${C_DIM}(oldest first, will become commits in this order):${RESET}\n\n"

  local i
  for (( i = 0; i < GD_ORG_GROUP_COUNT; i++ )); do
    local topic="${GD_ORG_GROUP_TOPIC[$i]}"
    local anchor="${GD_ORG_GROUP_ANCHOR[$i]}"
    local wips="${GD_ORG_GROUP_WIPS[$i]}"
    local size="${GD_ORG_GROUP_SIZE[$i]}"

    local anchor_hash="${anchor%% *}"
    local anchor_subject="${anchor#* }"

    printf "  ${C_BOLD}${C_MAGENTA}[%d] topic: %s${RESET}  ${C_DIM}(%d commit%s)${RESET}\n" \
      "$(( i + 1 ))" "$topic" "$size" "$([[ "$size" -eq 1 ]] && echo "" || echo "s")"
    printf "      ${SYM_OK} ${C_DIM}%s${RESET}  ${C_BOLD}%s${RESET}\n" "$anchor_hash" "$anchor_subject"

    if [[ -n "$wips" ]]; then
      while IFS= read -r wip_line; do
        [[ -z "$wip_line" ]] && continue
        local wip_hash="${wip_line%% *}"
        local wip_subject="${wip_line#* }"
        local wip_display="$wip_subject"
        if [[ ${#wip_subject} -gt 48 ]]; then wip_display="${wip_subject:0:45}..."; fi
        printf "      ${SYM_ERROR} ${C_DIM}%s  %s${RESET}  ${C_DIM}← fixup${RESET}\n" "$wip_hash" "$wip_display"
      done <<< "$wips"
    fi
    echo ""
  done
}

# ── Rebase todo builder ───────────────────────────────────────────────────────

# gd_org_build_todo FILEPATH [auto|reword]
# Writes a rebase todo file, oldest-first (groups in ascending index order).
# mode=auto    → pick for anchors, fixup for wips
# mode=reword  → reword for anchors, fixup for wips
gd_org_build_todo() {
  local filepath="$1"
  local mode="${2:-auto}"

  # We need to output oldest-first (same as _squash_wip_only with tac).
  # Our arrays are already oldest-first (index 0 = oldest).
  : > "$filepath"  # truncate

  local i
  for (( i = 0; i < GD_ORG_GROUP_COUNT; i++ )); do
    local anchor="${GD_ORG_GROUP_ANCHOR[$i]}"
    local wips="${GD_ORG_GROUP_WIPS[$i]}"

    local anchor_hash="${anchor%% *}"
    local anchor_subject="${anchor#* }"

    # WIPs come before the anchor in chronological order, but we want
    # the anchor to be the "kept" commit message so: wips first as fixup,
    # then the anchor as pick/reword.
    if [[ -n "$wips" ]]; then
      while IFS= read -r wip_line; do
        [[ -z "$wip_line" ]] && continue
        local wh="${wip_line%% *}"
        local ws="${wip_line#* }"
        echo "fixup $wh $ws" >> "$filepath"
      done <<< "$wips"
    fi

    local anchor_cmd="pick"
    if [[ "$mode" == "reword" ]]; then anchor_cmd="reword"; fi
    echo "$anchor_cmd $anchor_hash $anchor_subject" >> "$filepath"
  done
}

# ── Strategy helpers ─────────────────────────────────────────────────────────

# _org_suggest_group_message TOPIC FILES
# Returns a conventional commit prefix suggestion.
_org_suggest_group_message() {
  local topic="$1"
  # shift; local files="$*"  # reserved for future use

  case "$topic" in
    tests|test)  echo "test($topic)" ;;
    docs|doc)    echo "docs($topic)" ;;
    config|cfg)  echo "chore($topic)" ;;
    misc)        echo "feat" ;;
    *)           echo "feat($topic)" ;;
  esac
}

# ── Option 1: Auto-rebase ─────────────────────────────────────────────────────

# gd_org_auto_rebase
# Injects pre-built todo and runs non-interactive rebase.
gd_org_auto_rebase() {
  local todo_file
  todo_file="$(mktemp /tmp/git-doctor-org-todo.XXXXXX)"

  gd_org_build_todo "$todo_file" "auto"

  gd_dim "Rebase plan:"
  while IFS= read -r l; do gd_dim "  $l"; done < "$todo_file"
  echo ""
  printf "  Proceed? [Y/n]: "
  read -r confirm
  confirm="${confirm:-Y}"
  echo ""

  if [[ "${confirm,,}" != "y" ]]; then
    rm -f "$todo_file"
    gd_dim "Cancelled."
    echo ""
    return 0
  fi

  GIT_SEQUENCE_EDITOR="cp '$todo_file' " git rebase -i "$GD_ORG_MERGE_BASE" 2>/dev/null \
    || GIT_SEQUENCE_EDITOR="cat '$todo_file' >" git rebase -i "$GD_ORG_MERGE_BASE"

  local exit_code=$?
  rm -f "$todo_file"

  if [[ "$exit_code" -eq 0 ]]; then
    echo ""
    gd_ok "Rebase complete — ${GD_ORG_GROUP_COUNT} clean commit(s)."
  else
    echo ""
    gd_warn "Rebase encountered conflicts."
    gd_dim  "Fix conflicts, then: git add -A && git rebase --continue"
    gd_dim  "To abort: git rebase --abort"
  fi
  echo ""
}

# ── Option 2: Edit-then-rebase ────────────────────────────────────────────────

# gd_org_edit_rebase
# Writes a commented todo, opens in $EDITOR, strips comments, then rebases.
gd_org_edit_rebase() {
  local editor="${EDITOR:-${GIT_EDITOR:-vi}}"
  local todo_file
  todo_file="$(mktemp /tmp/git-doctor-org-todo.XXXXXX)"

  gd_org_build_todo "$todo_file" "reword"

  # Append helpful comments
  cat >> "$todo_file" <<'COMMENTS'

# git-doctor organize — edit this rebase todo, then save and quit.
#
# Commands:
#   pick   = use commit as-is
#   reword = use commit, but edit the commit message
#   fixup  = meld into previous commit, discard its log message
#   squash = meld into previous commit, keep its log message for editing
#   drop   = remove commit
#
# Lines starting with '#' are ignored.
COMMENTS

  "$editor" "$todo_file"

  # Strip comment lines before passing to git
  local clean_file
  clean_file="$(mktemp /tmp/git-doctor-org-clean.XXXXXX)"
  grep -v '^[[:space:]]*#' "$todo_file" | grep -v '^[[:space:]]*$' > "$clean_file" || true
  rm -f "$todo_file"

  if [[ ! -s "$clean_file" ]]; then
    rm -f "$clean_file"
    gd_warn "Empty todo — rebase cancelled."
    echo ""
    return 0
  fi

  gd_dim "Running rebase with your edited plan..."
  echo ""

  GIT_SEQUENCE_EDITOR="cp '$clean_file' " git rebase -i "$GD_ORG_MERGE_BASE" 2>/dev/null \
    || GIT_SEQUENCE_EDITOR="cat '$clean_file' >" git rebase -i "$GD_ORG_MERGE_BASE"

  local exit_code=$?
  rm -f "$clean_file"

  if [[ "$exit_code" -eq 0 ]]; then
    echo ""
    gd_ok "Rebase complete."
  else
    echo ""
    gd_warn "Rebase encountered conflicts."
    gd_dim  "Fix conflicts, then: git add -A && git rebase --continue"
    gd_dim  "To abort: git rebase --abort"
  fi
  echo ""
}

# ── Option 3: Guided re-commit ────────────────────────────────────────────────

# gd_org_guided_recommit
# Soft-resets to merge base, unstages everything, then walks through each group
# asking for a commit message.
gd_org_guided_recommit() {
  gd_info "Soft-resetting to ${GD_ORG_MERGE_BASE:0:8}..."
  git reset --soft "$GD_ORG_MERGE_BASE"
  git restore --staged . 2>/dev/null || git reset HEAD -- . 2>/dev/null || true
  echo ""

  local i
  for (( i = 0; i < GD_ORG_GROUP_COUNT; i++ )); do
    local topic="${GD_ORG_GROUP_TOPIC[$i]}"
    local anchor="${GD_ORG_GROUP_ANCHOR[$i]}"
    local wips="${GD_ORG_GROUP_WIPS[$i]}"
    local size="${GD_ORG_GROUP_SIZE[$i]}"

    local anchor_hash="${anchor%% *}"
    local anchor_subject="${anchor#* }"

    printf "  ${C_BOLD}${C_MAGENTA}Group %d/%d${RESET}: ${C_BOLD}%s${RESET}  ${C_DIM}(%d commit%s)${RESET}\n\n" \
      "$(( i + 1 ))" "$GD_ORG_GROUP_COUNT" "$topic" "$size" \
      "$([[ "$size" -eq 1 ]] && echo "" || echo "s")"

    # Collect all files from all commits in this group
    local all_files=""
    # Wip hashes first (chronologically older)
    if [[ -n "$wips" ]]; then
      while IFS= read -r wip_line; do
        [[ -z "$wip_line" ]] && continue
        local wh="${wip_line%% *}"
        local wf
        wf="$(git diff-tree --no-commit-id -r --name-only "$wh" 2>/dev/null)"
        if [[ -n "$wf" ]]; then
          all_files+="$wf"$'\n'
        fi
      done <<< "$wips"
    fi
    # Anchor files
    local anchor_files
    anchor_files="$(git diff-tree --no-commit-id -r --name-only "$anchor_hash" 2>/dev/null)"
    if [[ -n "$anchor_files" ]]; then
      all_files+="$anchor_files"$'\n'
    fi

    # Deduplicate
    local unique_files
    unique_files="$(echo "$all_files" | sort -u | grep -v '^[[:space:]]*$' || true)"

    if [[ -n "$unique_files" ]]; then
      printf "  ${C_DIM}Files to stage:${RESET}\n"
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        printf "    ${C_DIM}%s${RESET}\n" "$f"
        # Stage each file if it still exists in working tree
        if [[ -e "$f" ]]; then
          git add -- "$f" 2>/dev/null || true
        fi
      done <<< "$unique_files"
      echo ""
    else
      gd_dim "No files found for this group — it may have been an empty commit."
      echo ""
    fi

    # Suggest a message
    local prefix
    prefix="$(_org_suggest_group_message "$topic")"
    local suggestion="${prefix}: ${anchor_subject}"

    printf "  ${C_BOLD}Commit message${RESET} ${C_DIM}(empty = use suggestion):${RESET}\n"
    printf "  ${C_DIM}Suggested: %s${RESET}\n\n" "$suggestion"
    printf "  > "
    read -r user_msg
    echo ""

    local final_msg="${user_msg:-$suggestion}"
    if [[ -z "$final_msg" ]]; then
      final_msg="$suggestion"
    fi

    git commit -m "$final_msg" 2>/dev/null || {
      gd_warn "Nothing to commit for group ${topic} — skipping."
    }
    echo ""
  done

  gd_ok "Guided re-commit complete."
  echo ""
  gd_dim "Run 'git log --oneline' to review your new history."
  echo ""
}
