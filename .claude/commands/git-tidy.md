# git-tidy — AI-powered commit history cleanup

You are helping the user clean up their git branch history before merging a PR. Your goal is to reorganize messy WIP commits into a small set of clean, logical, conventional commits that tell a clear story of what changed.

## Step 1: Gather context

Run these commands to understand the current state:

```bash
# Get the merge base
git merge-base HEAD $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E '^(main|master|develop|trunk)$' | head -1) 2>/dev/null || git rev-list --max-parents=0 HEAD
```

Then get the full commit list and diffs:
```bash
# List commits (newest first)
git log --pretty=format:"%h|%s|%ai" MERGE_BASE..HEAD
```

For each commit hash, get what changed:
```bash
git show --stat --no-patch HASH
git diff-tree --no-commit-id -r --name-only HASH
```

Also get the full cumulative diff summary:
```bash
git diff --stat MERGE_BASE..HEAD
```

## Step 2: Analyze and group

Read all commit messages and changed files. Using your understanding of the code, group the commits into **logical units of work** — not by filename pattern, but by *what feature, fix, or concern they collectively implement*.

For each proposed group:
- Give it a topic label
- Identify which commit should be the "anchor" (best existing message, or write a new one)
- List which commits are WIP noise to fixup into the anchor
- Suggest a clean conventional commit message: `type(scope): short description`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`, `style`

**Rules for good messages:**
- 50 chars or less for the subject
- Imperative mood ("add", "fix", "remove" not "added", "fixes")
- Scope = the primary module/area changed
- If all changes are one cohesive thing, one commit is fine

## Step 3: Present the plan

Show the user a clear before/after:

```
BEFORE (current, newest first):
  ✗ abc1234  wip
  ✗ def5678  oops forgot this
  ✓ 9ab0123  feat(auth): add JWT validation
  ✗ bcd4567  fix
  ✓ efg8901  feat(routes): login endpoint

PROPOSED (will become, oldest first):
  [1] feat(auth): add JWT validation with login endpoint
      squashes: abc1234, def5678, bcd4567, efg8901 → 9ab0123
  [2] test(auth): add integration tests
      squashes: ...
```

Then ask: **"Apply this plan? [Y/n/edit]"**

- `Y` → proceed
- `n` → cancel, suggest running `git doctor organize` manually
- `edit` → let the user modify the proposed messages before applying

## Step 4: Apply

If the user approves, apply using a soft reset approach (safest, no rebase conflicts):

```bash
# Save the proposed messages first
git reset --soft MERGE_BASE
git restore --staged .
```

Then for each group (oldest first):
1. Stage the files from all commits in that group using `git add -- <files>`
2. Commit with the clean message using `git commit -m "message"`

After applying:
```bash
git log --oneline MERGE_BASE..HEAD
```

Show the clean new history.

## Step 5: Offer to push

Ask: **"Push with --force-with-lease to update the PR? [Y/n]"**

If yes:
```bash
git push --force-with-lease
```

Explain: "This updates the PR's Commits tab so reviewers see clean history. The Files Changed tab was already clean."

## Edge cases to handle

- If already in a rebase or merge, stop and tell the user
- If on main/master/develop, stop and refuse
- If only 1 commit, offer to just reword it
- If all commits already look good (all conventional format, no WIPs), say so and skip
- If `git push --force-with-lease` fails (branch diverged), explain what happened and suggest `git fetch` first

## Tone

Be concise. Show the plan clearly. Don't narrate every git command you run — just show the meaningful output. After applying, show the before/after commit counts and the new `git log --oneline`.
