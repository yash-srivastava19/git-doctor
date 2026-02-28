# git-precheck — catch embarrassing things before reviewers do

You are scanning the diff of the current branch for problems a developer would be embarrassed to have a reviewer find. Be thorough, be specific (include file + line), and give a clear pass/fail at the end.

## Step 1: Get the diff

```bash
# Find base
BASE=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E '^(main|master|develop|trunk)$' | head -1)
MERGE_BASE=$(git merge-base HEAD $BASE)

# Full diff with line numbers
git diff $MERGE_BASE..HEAD

# File list
git diff --name-only $MERGE_BASE..HEAD

# Check for large files (>500KB)
git diff --stat $MERGE_BASE..HEAD
```

## Step 2: Scan for each category

Go through the diff line by line (only added lines — starting with `+`, not `++`). Check every category below.

---

### 🔴 CRITICAL — must fix before merge

**Secrets & credentials**
Patterns in added lines:
- `password\s*=\s*['"][^'"]{4,}` (hardcoded password value)
- `secret\s*=\s*['"][^'"]{4,}`
- `api_key\s*=\s*['"][^'"]{4,}`
- `token\s*=\s*['"][^'"]{8,}` (looks like a real token, not a variable)
- `AUTH_TOKEN\s*=\s*['"]`, `PRIVATE_KEY\s*=\s*`
- Long strings that look like base64 secrets or JWT tokens
- AWS key pattern: `AKIA[0-9A-Z]{16}`
- Private key headers: `-----BEGIN RSA PRIVATE KEY-----`

**Merge conflict markers**
- Lines containing `<<<<<<<`, `=======`, `>>>>>>>`

**Hardcoded non-local IPs or URLs**
- IP addresses other than 127.0.0.1, 0.0.0.0, localhost
- Hardcoded production URLs in source code (not config/env)

---

### 🟡 WARNING — should fix, explains if acceptable

**Debug statements**
- JS/TS: `console.log(`, `console.debug(`, `console.warn(`, `debugger;`
- Python: `print(`, `pdb.set_trace()`, `breakpoint()`
- Ruby: `binding.pry`, `byebug`
- Go: `fmt.Println(`, `log.Println(` in non-main/non-test files
- Any language: `// DEBUG`, `# DEBUG`

**Skipped or focused tests**
- JS/TS: `it.skip(`, `test.skip(`, `describe.skip(`, `xit(`, `xdescribe(`
- JS/TS: `it.only(`, `test.only(`, `describe.only(` (focused — will skip everything else in CI)
- Python: `@pytest.mark.skip`, `@unittest.skip`
- Go: `t.Skip(`

**TODO / FIXME left in new code**
- `TODO:`, `FIXME:`, `HACK:`, `XXX:` in lines you added (not pre-existing ones)
- Only flag ones in added lines (`+`) not context lines

---

### 🔵 NOTICE — worth knowing, not necessarily a problem

**Environment variables**
- New `process.env.X`, `os.environ['X']`, `ENV['X']` references
- List them so the reviewer knows to update `.env.example` or deployment config

**Large files added**
- Any single file with >300 added lines — flag it as "large, may want to split"

**package.json / requirements changes**
- New dependencies added — list them so reviewer knows what's being pulled in

---

## Step 3: Report results

Format the output like this:

```
git-precheck — feat/auth-system
────────────────────────────────────────

🔴 CRITICAL (must fix)
  • src/auth/jwt.js:12  — hardcoded secret: secret = "abc123xyz"
  • src/config.js:3     — merge conflict marker: <<<<<<< HEAD

🟡 WARNINGS (should fix)
  • src/auth/jwt.js:45  — console.log("token:", token)
  • tests/auth.test.js  — test.only("validates JWT") ← will block CI
  • src/routes/login.js:8 — TODO: handle refresh tokens

🔵 NOTICES (fyi)
  • New env var: process.env.JWT_SECRET — add to .env.example?
  • New dependency: jsonwebtoken@9.0.0 added to package.json
  • src/auth/password.js — 340 lines added, consider splitting

────────────────────────────────────────
Result: ❌ NOT READY — 2 critical issue(s) to fix
         Run /git-precheck again after fixing
```

Or if clean:

```
────────────────────────────────────────
Result: ✅ CLEAR — nothing embarrassing found
         Ready for /git-pr-desc → push → PR
```

## Rules

- Only report on **added lines** (lines starting with `+` in the diff, not `++` file headers). Don't flag pre-existing issues that aren't in the current diff.
- For each finding, give the **exact file and line number** from the diff context
- If a `console.log` is inside a test file, lower it to NOTICE not WARNING
- If `TODO` is in a comment that already existed (context line, not added line), skip it
- Don't flag `console.error` used for actual error handling in a catch block — use judgment
- At the end, always state clearly: ready or not ready
