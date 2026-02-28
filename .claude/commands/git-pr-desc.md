# git-pr-desc — AI-generated PR description from your branch

You are writing a pull request description by reading the actual code changes on the current branch. Be specific and technical — reference real function names, file names, and behaviour from the diff. Never write generic filler.

## Step 1: Gather everything

Run these to understand the branch:

```bash
# Base branch detection
git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E '^(main|master|develop|trunk)$' | head -1

# Merge base
git merge-base HEAD <base-branch>

# All commits on this branch
git log --pretty=format:"%h %s" <merge-base>..HEAD

# File-level summary
git diff --stat <merge-base>..HEAD

# Full diff (the actual code)
git diff <merge-base>..HEAD
```

Also check if a PR already exists:
```bash
gh pr view --json title,body 2>/dev/null
```

## Step 2: Understand the change

Read the full diff carefully. Identify:
- **What problem does this solve?** (infer from the code if no issue reference exists)
- **What is the approach?** (what did they build/change/remove and why)
- **What are the non-obvious parts?** (things a reviewer should pay attention to)
- **What type of change is this?** (new feature / bug fix / refactor / perf / docs / chore)
- **Is there anything risky?** (DB changes, API changes, auth changes, env vars needed)

## Step 3: Write the PR description

Write in this exact format. Be concrete — use real names from the code, not abstractions.

```markdown
## What

<1-3 sentences. What does this PR do? Write it as a fact, not a task.
Example: "Adds JWT-based authentication to the login route using a shared
validateJWT() utility. Passwords are now hashed via hashPassword() before
comparison." NOT "This PR adds some auth stuff.">

## Why

<1-2 sentences. What problem does this solve or what feature does it enable?
Skip this section only if it's completely obvious from What.>

## Changes

- `path/to/file.js` — <what changed and why, one line per file or logical group>
- `path/to/other.js` — <...>

## How to test

- [ ] <Specific step. E.g.: "POST /login with valid credentials → expect 200 + JWT cookie">
- [ ] <Specific step. E.g.: "POST /login with wrong password → expect 401">
- [ ] <Edge case worth testing>

## Notes for reviewer

<Optional. Only include if there's something non-obvious: a tricky decision,
a known limitation, a follow-up ticket, a migration needed, env vars to add.
Skip this section if there's nothing worth flagging.>
```

## Step 4: Present and offer actions

Print the description clearly. Then ask:

```
What would you like to do?
[1] Create the PR now (gh pr create)
[2] Copy description only — I'll create the PR myself
[3] Edit something first
```

If they choose [1], ask:
- PR title (suggest one based on the commits, conventional format)
- Base branch (confirm what was detected)
- Draft or ready for review?

Then run:
```bash
gh pr create --title "<title>" --base <base> --body "<description>" [--draft]
```

If the PR already exists, offer to update the body instead:
```bash
gh pr edit --body "<description>"
```

## Rules

- Never invent behaviour that isn't in the diff
- If the diff is huge (>500 lines), focus on the most important files — mention in the description that other files are supporting changes
- If there are test files, extract the test case names to make the "How to test" section concrete
- If you see env var references in the diff, call them out in Notes
- Keep the whole description under ~400 words
