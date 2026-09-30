#!/usr/bin/env bash
# self-test.sh — validate this skill repository's own integrity.
#
# Checks structure, frontmatter, script syntax, internal links, reference
# registration, and runs functional tests against generated fixtures.
#
# Usage: bash scripts/self-test.sh
# Exits non-zero if any check fails.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SKILL_DIR" || exit 2

PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
hr()   { printf '\n\033[1m── %s\033[0m\n' "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "═══════════════════════════════════════════════════════════"
echo " seo-optimizer — self test"
echo " $SKILL_DIR"
echo "═══════════════════════════════════════════════════════════"

# ---------------------------------------------------------------- structure
hr "1. Required files"
for f in SKILL.md README.md README.vi.md CONTRIBUTING.md CHANGELOG.md LICENSE \
         references/00-index.md templates/site-config.md templates/audit-report.md \
         scripts/detect-project.sh scripts/grep-antipatterns.sh scripts/check-seo.mjs \
         scripts/audit-url.sh scripts/self-test.sh; do
  [ -f "$f" ] && ok "$f" || bad "$f MISSING"
done

# ---------------------------------------------------------------- frontmatter
hr "2. SKILL.md frontmatter & size limit"
if head -1 SKILL.md | grep -q '^---$'; then
  ok "starts with YAML frontmatter"
else
  bad "missing YAML frontmatter"
fi
grep -qE '^name:' SKILL.md && ok "has 'name:'" || bad "missing 'name:'"
grep -qE '^description:' SKILL.md && ok "has 'description:'" || bad "missing 'description:'"

# Agent hosts reject oversized skill bodies. Measured limit is near 1.2 KB.
BODY_CHARS=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2' SKILL.md | wc -c | tr -d ' ')
if   [ "$BODY_CHARS" -le 1400 ]; then ok "body size ${BODY_CHARS} chars (limit ~1400)"
elif [ "$BODY_CHARS" -le 2000 ]; then warn "body size ${BODY_CHARS} chars — getting close to the host limit"
else bad "body size ${BODY_CHARS} chars — WILL BE REJECTED by agent hosts (limit ~1.2 KB)"
fi

# ---------------------------------------------------------------- syntax
hr "3. Script syntax"
for f in scripts/*.sh; do
  [ -e "$f" ] || continue
  if bash -n "$f" 2>/dev/null; then ok "bash -n $f"; else bad "bash -n $f"; fi
done
for f in scripts/*.mjs; do
  [ -e "$f" ] || continue
  if node --check "$f" 2>/dev/null; then ok "node --check $f"; else bad "node --check $f"; fi
done

# ---------------------------------------------------------------- links
hr "4. Internal Markdown links"
BROKEN=0
while IFS= read -r file; do
  dir="$(dirname "$file")"
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    case "$link" in http*|mailto:*|\#*) continue ;; esac
    if [ ! -e "$dir/$link" ]; then
      bad "$file → $link"
      BROKEN=$((BROKEN+1))
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" 2>/dev/null | sed 's/^](//; s/)$//' | cut -d'#' -f1)
done < <(find . -name '*.md' -not -path './.git/*')
[ "$BROKEN" -eq 0 ] && ok "all internal links resolve" || true

# ---------------------------------------------------------------- registration
hr "5. Every reference is registered in 00-index.md"
UNREG=0
for f in references/*.md; do
  base="$(basename "$f")"
  [ "$base" = "00-index.md" ] && continue
  if grep -q "$base" references/00-index.md; then
    :
  else
    bad "$base not registered in references/00-index.md"
    UNREG=$((UNREG+1))
  fi
done
[ "$UNREG" -eq 0 ] && ok "all $(( $(ls references/*.md | wc -l) - 1 )) references registered"

# ---------------------------------------------------------------- portability
hr "6. Portability"
HITS=$(grep -rn '/home/[a-z0-9_]*/' --include='*.md' --include='*.sh' --include='*.mjs' . 2>/dev/null \
        | grep -v '^\./\.git/' || true)
if [ -n "$HITS" ]; then
  bad "hard-coded home paths found (breaks on other machines):"
  printf '%s\n' "$HITS" | head -3 | sed 's/^/      /'
else
  ok "no hard-coded home paths"
fi
if grep -q 'npm install\|require(.next' scripts/*.mjs 2>/dev/null; then
  bad "check-seo.mjs appears to need npm packages"
else
  ok "check-seo.mjs uses Node built-ins only"
fi

# ---------------------------------------------------------------- functional
# Run from an unrelated cwd on purpose: scripts must not assume where they run.
cd "$TMP" || exit 2
hr "7. Functional tests (run from $TMP)"

# --- 7a. check-seo.mjs must PASS a clean page
mkdir -p good
cat > good/index.html <<'HTML'
<!DOCTYPE html><html lang="vi"><head>
<title>Bảng giá dịch vụ SEO trọn gói 2026 | Công ty ABC</title>
<meta name="description" content="Bảng giá dịch vụ SEO trọn gói năm 2026, minh bạch theo hạng mục, có cam kết KPI và báo cáo hiệu quả hàng tháng.">
<link rel="canonical" href="https://example.com/bang-gia">
<meta property="og:title" content="Bảng giá dịch vụ SEO">
<meta property="og:image" content="https://example.com/og.png">
<script type="application/ld+json">{"@context":"https://schema.org","@type":"Service"}</script>
</head><body><h1>Bảng giá dịch vụ SEO trọn gói</h1><img src="/a.png" alt="Biểu đồ giá"></body></html>
HTML

# --- 7b. check-seo.mjs must FAIL a broken page
mkdir -p bad
cat > bad/index.html <<'HTML'
<!DOCTYPE html><html><head><meta name="description" content="Ngắn"></head>
<body><h1>A</h1><h1>B</h1><img src="/b.png"></body></html>
HTML

node "$SKILL_DIR/scripts/check-seo.mjs" good >/dev/null 2>&1
[ $? -eq 0 ] && ok "check-seo.mjs → exit 0 on clean page" || bad "check-seo.mjs returned non-zero on a clean page"

node "$SKILL_DIR/scripts/check-seo.mjs" bad >/dev/null 2>&1
[ $? -eq 1 ] && ok "check-seo.mjs → exit 1 on broken page" || bad "check-seo.mjs did NOT flag a broken page"

# --- 7c. detect-project.sh must identify App Router
mkdir -p app-proj/app/danh-muc app-proj/public
printf '%s' '{"dependencies":{"next":"16.3.7","react":"19.2.0"}}' > app-proj/package.json
printf '%s' 'export const metadata = {}' > app-proj/app/page.tsx
printf '%s' 'const c = { trailingSlash: false }' > app-proj/next.config.ts
OUT=$(bash "$SKILL_DIR/scripts/detect-project.sh" app-proj 2>&1)
echo "$OUT" | grep -q 'APP ROUTER' && ok "detect-project.sh → APP ROUTER" || bad "did not detect App Router"
echo "$OUT" | grep -q '16.3.7'      && ok "detect-project.sh → reads Next version" || bad "did not read Next version"

# --- 7d. detect-project.sh must identify Pages Router
mkdir -p pages-proj/pages
printf '%s' '{"dependencies":{"next":"14.2.0","react":"18.3.0"}}' > pages-proj/package.json
printf '%s' 'export default function Home(){return null}' > pages-proj/pages/index.tsx
OUT2=$(bash "$SKILL_DIR/scripts/detect-project.sh" pages-proj 2>&1)
echo "$OUT2" | grep -q 'PAGES ROUTER' && ok "detect-project.sh → PAGES ROUTER" || bad "did not detect Pages Router"
echo "$OUT2" | grep -q '14-migration-and-upgrade' && ok "detect-project.sh → points Pages Router at migration ref" || warn "does not reference the migration doc"

# --- 7e. grep-antipatterns.sh must find planted issues
mkdir -p scan/app
printf "%s\n" "'use client'" "export const metadata = { title: 'x' }" > scan/app/layout.tsx
printf '%s\n' "export const dynamic = 'force-dynamic'" > scan/app/page.tsx
OUT3=$(bash "$SKILL_DIR/scripts/grep-antipatterns.sh" scan/app 2>&1)
echo "$OUT3" | grep -q 'force-dynamic'      && ok "grep-antipatterns.sh → found force-dynamic" || bad "missed force-dynamic"
echo "$OUT3" | grep -q 'THIẾU metadataBase' && ok "grep-antipatterns.sh → found missing metadataBase" || bad "missed missing metadataBase"
echo "$OUT3" | grep -q 'Client Component'   && ok "grep-antipatterns.sh → found metadata in client component" || bad "missed metadata-in-client-component"

# ---------------------------------------------------------------- summary
cd "$SKILL_DIR" || exit 2
printf '\n═══════════════════════════════════════════════════════════\n'
printf ' %s passed · %s warnings · %s failed\n' "$PASS" "$WARN" "$FAIL"
printf '═══════════════════════════════════════════════════════════\n'
[ "$FAIL" -eq 0 ] || exit 1
echo "✅ self-test OK"
