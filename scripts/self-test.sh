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

# --- 7b2. REGRESSION: real Next.js build output must NOT produce false positives.
# Filename shapes captured from actual builds (Next 16.3.7 App Router, Next 15 Pages Router):
#   App Router  : _global-error.html, _not-found.html, index.html, pricing.html, san-pham/abc.html
#   Pages Router: 404.html, 500.html, index.html, san-pham/abc.html
# Before this regression test, BOTH healthy projects exited 1 because framework-internal
# pages were audited as if they were real pages.
mk_clean() {  # $1=file path  $2=title  $3=canonical  $4=description
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<HTML
<!DOCTYPE html><html lang="vi"><head><title>$2</title>
<meta name="description" content="$4">
<link rel="canonical" href="$3">
<meta property="og:title" content="$2">
<meta property="og:image" content="https://example.com/og.png">
<script type="application/ld+json">{"@context":"https://schema.org"}</script>
</head><body><h1>$2</h1></body></html>
HTML
}
SHELL_MIN='<!DOCTYPE html><html><head></head><body></body></html>'

apx="app-real"
mk_clean "$apx/index.html"        "Trang chủ thương hiệu demo"  "https://example.com/"             "Mô tả trang chủ đủ dài để không kích hoạt cảnh báo về độ dài trong script kiểm tra này."
mk_clean "$apx/pricing.html"      "Bảng giá dịch vụ trọn gói"   "https://example.com/pricing"      "Mô tả trang bảng giá đủ dài để không kích hoạt cảnh báo về độ dài trong script kiểm tra này."
mk_clean "$apx/san-pham/abc.html" "Sản phẩm ABC chính hãng"     "https://example.com/san-pham/abc" "Mô tả sản phẩm ABC đủ dài để không kích hoạt cảnh báo về độ dài trong script kiểm tra."
printf '%s' "$SHELL_MIN" > "$apx/_global-error.html"
printf '%s' "$SHELL_MIN" > "$apx/_not-found.html"

node "$SKILL_DIR/scripts/check-seo.mjs" "$apx" >/dev/null 2>&1
[ $? -eq 0 ] && ok "REGRESSION app-router: _not-found/_global-error no longer break the build" \
             || bad "REGRESSION: healthy App Router output exits non-zero"

node "$SKILL_DIR/scripts/check-seo.mjs" "$apx" --all >/dev/null 2>&1
[ $? -eq 1 ] && ok "check-seo.mjs --all still audits framework pages" \
             || bad "--all no longer includes framework pages"

pgx="pages-real"
mk_clean "$pgx/index.html"        "Trang chủ Pages Router demo" "https://example.com/"             "Mô tả trang chủ Pages Router đủ dài để không kích hoạt cảnh báo về độ dài trong script."
mk_clean "$pgx/san-pham/abc.html" "Sản phẩm ABC Pages Router"  "https://example.com/san-pham/abc" "Mô tả sản phẩm Pages Router đủ dài để không kích hoạt cảnh báo về độ dài trong script."
printf '%s' "$SHELL_MIN" > "$pgx/404.html"
printf '%s' "$SHELL_MIN" > "$pgx/500.html"

node "$SKILL_DIR/scripts/check-seo.mjs" "$pgx" >/dev/null 2>&1
[ $? -eq 0 ] && ok "REGRESSION pages-router: 404.html/500.html no longer break the build" \
             || bad "REGRESSION: healthy Pages Router output exits non-zero"

# Guard against over-suppression: a REAL page missing <title> must still fail.
mk_clean "$pgx/thieu-title.html" "" "https://example.com/x" "Mô tả đủ dài cho trang thiếu title để chắc chắn script vẫn bắt được lỗi thật sự nghiêm trọng."
node "$SKILL_DIR/scripts/check-seo.mjs" "$pgx" >/dev/null 2>&1
[ $? -eq 1 ] && ok "check-seo.mjs still fails a real page missing <title>" \
             || bad "check-seo.mjs stopped catching missing <title> — over-suppression!"
rm -f "$pgx/thieu-title.html"

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

# --- 7f. REGRESSION: .js/.jsx projects must be detected (was .ts/.tsx only)
jsx="jsx-proj"
mkdir -p "$jsx/app"
printf '%s' '{"dependencies":{"next":"16.3.7","react":"19.2.0"}}' > "$jsx/package.json"
printf '%s' 'export const metadata = {}' > "$jsx/app/page.jsx"
printf '%s' 'export default function L({children}){return children}' > "$jsx/app/layout.jsx"
printf '%s' 'export default function s(){return []}' > "$jsx/app/sitemap.js"
printf '%s' 'export default function r(){return {}}' > "$jsx/app/robots.js"
printf '%s' 'export default function N(){return null}' > "$jsx/app/not-found.jsx"
printf '%s' 'module.exports = {}' > "$jsx/next.config.js"
OUT4=$(bash "$SKILL_DIR/scripts/detect-project.sh" "$jsx" 2>&1)
echo "$OUT4" | grep -q 'app/sitemap.js'   && ok "REGRESSION detect-project.sh finds sitemap.js" || bad "REGRESSION: sitemap.js reported missing"
echo "$OUT4" | grep -q 'app/robots.js'    && ok "REGRESSION detect-project.sh finds robots.js"  || bad "REGRESSION: robots.js reported missing"
echo "$OUT4" | grep -q 'layout.\*   : 1'  && ok "detect-project.sh counts layout.jsx"          || bad "layout.jsx not counted"

# --- 7g. REGRESSION: grep-antipatterns.sh must resolve the project root, not the cwd
OUT5=$(bash "$SKILL_DIR/scripts/grep-antipatterns.sh" "$TMP/$jsx/app" 2>&1)
echo "$OUT5" | grep -q 'next.config.js'        && ok "REGRESSION grep-antipatterns.sh finds next.config from another cwd" || bad "REGRESSION: next.config not found when cwd differs"
echo "$OUT5" | grep -q 'không tìm thấy next.config' && bad "REGRESSION: still reports next.config missing" || true
echo "$OUT5" | grep -q 'chỉ có .*app/robots.js' && ok "grep-antipatterns.sh resolves public/ against project root" || warn "robots conflict check did not report the convention file"
echo "$OUT3" | grep -q 'Client Component'   && ok "grep-antipatterns.sh → found metadata in client component" || bad "missed metadata-in-client-component"

# --- 7h. REGRESSION: audit-url.sh must read headers from the FINAL response.
# Found against a real site: the tested path returned 308 and the page's
# Cache-Control lived on the redirect target, so `curl -sI` on the original URL
# silently reported nothing. A live site with `no-store` was reported as having
# no cache header at all.
srv_js="$TMP/srv.mjs"
cat > "$srv_js" <<'JS'
import { createServer } from 'node:http'
import { writeFileSync } from 'node:fs'
const server = createServer((req, res) => {
  if (req.url === '/') {
    res.writeHead(308, { Location: '/final' })
    res.end()
  } else {
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'private, no-store, max-age=0',
      'X-Robots-Tag': 'noindex',
    })
    res.end('<!DOCTYPE html><html lang="vi"><head><title>Trang đích sau redirect</title></head><body><h1>x</h1></body></html>')
  }
})
server.listen(0, '127.0.0.1', () => writeFileSync(process.argv[2], String(server.address().port)))
JS
rm -f "$TMP/port"
node "$srv_js" "$TMP/port" &
SRV_PID=$!
i=0
while [ ! -f "$TMP/port" ] && [ "$i" -lt 60 ]; do sleep 0.1; i=$((i+1)); done
PORT="$(cat "$TMP/port" 2>/dev/null)"
if [ -n "$PORT" ]; then
  OUT6=$(bash "$SKILL_DIR/scripts/audit-url.sh" "http://127.0.0.1:$PORT/" 2>&1)
  echo "$OUT6" | grep -q 'no-store' && ok "REGRESSION audit-url.sh reads Cache-Control from the FINAL response" \
                                    || bad "REGRESSION: audit-url.sh misses headers behind a redirect"
  echo "$OUT6" | grep -q 'URL cuối' && ok "audit-url.sh reports the final URL after redirects" \
                                    || warn "final URL not reported"
  echo "$OUT6" | grep -q 'noindex'  && ok "audit-url.sh picks up X-Robots-Tag from the final response" \
                                    || warn "X-Robots-Tag not reported"
else
  warn "could not start local test server — redirect-header regression skipped"
fi
kill "$SRV_PID" 2>/dev/null

# --- 7i. REGRESSION: hybrid projects need BOTH output directories in one run.
# Found by building a real hybrid project (next@15): the App Router run alone
# reported exit 0 while a duplicate title lived in the Pages Router output.
hyb="hybrid"
mkdir -p "$hyb/app" "$hyb/pages"
mk_clean "$hyb/app/index.html"     "Matrix Demo"                 "https://example.com/"     "Mô tả trang chủ đủ dài để không kích hoạt cảnh báo về độ dài trong script kiểm tra."
mk_clean "$hyb/pages/legacy.html"  "Trang Pages Router riêng"    "https://example.com/legacy" "Mô tả trang Pages Router đủ dài để không kích hoạt cảnh báo về độ dài trong script."

node "$SKILL_DIR/scripts/check-seo.mjs" "$hyb/app" >/dev/null 2>&1
[ $? -eq 0 ] && ok "hybrid: App Router dir alone passes (as expected)" \
             || bad "hybrid: App Router dir alone did not pass"

OUT7=$(node "$SKILL_DIR/scripts/check-seo.mjs" "$hyb/app" 2>&1)
echo "$OUT7" | grep -q 'dự án hybrid' && ok "check-seo.mjs hints at the un-passed sibling pages dir" \
                                      || bad "no hint about the sibling pages dir"

node "$SKILL_DIR/scripts/check-seo.mjs" "$hyb/app" "$hyb/pages" >/dev/null 2>&1
[ $? -eq 0 ] && ok "hybrid: both dirs together pass" || bad "hybrid: both dirs together failed"

# now plant a duplicate title ACROSS the two routers
mk_clean "$hyb/pages/dup.html" "Matrix Demo" "https://example.com/dup" "Mô tả trang trùng title đủ dài để không kích hoạt cảnh báo về độ dài trong script kiểm."
node "$SKILL_DIR/scripts/check-seo.mjs" "$hyb/app" >/dev/null 2>&1
[ $? -eq 0 ] && ok "REGRESSION hybrid: app-only run STILL misses the cross-router duplicate (documented gap)" \
             || warn "app-only run now catches cross-router duplicates"
node "$SKILL_DIR/scripts/check-seo.mjs" "$hyb/app" "$hyb/pages" >/dev/null 2>&1
[ $? -eq 1 ] && ok "REGRESSION hybrid: both dirs catch the cross-router duplicate title" \
             || bad "REGRESSION: cross-router duplicate title not detected"
OUT8=$(node "$SKILL_DIR/scripts/check-seo.mjs" "$hyb/app" "$hyb/pages" 2>&1)
echo "$OUT8" | grep -q 'Title trùng' && ok "duplicate report names the offending routes" || bad "duplicate report lacks routes"

# --- 7j. REGRESSION: static export shape (trailingSlash: true).
# Captured from a real `next build` with output:'export': out/ holds
# index.html, san-pham/abc/index.html and BOTH 404.html and 404/index.html.
exp="export-out"
mkdir -p "$exp/san-pham/abc" "$exp/404"
mk_clean "$exp/index.html"           "Trang chủ static export" "https://example.com/"             "Mô tả trang chủ static export đủ dài để không kích hoạt cảnh báo về độ dài trong script."
mk_clean "$exp/san-pham/abc/index.html" "Sản phẩm ABC export" "https://example.com/san-pham/abc" "Mô tả sản phẩm static export đủ dài để không kích hoạt cảnh báo về độ dài trong script."
printf '%s' "$SHELL_MIN" > "$exp/404.html"
printf '%s' "$SHELL_MIN" > "$exp/404/index.html"

OUT9=$(node "$SKILL_DIR/scripts/check-seo.mjs" "$exp" 2>&1)
[ $? -eq 0 ] && ok "REGRESSION static export: out/ with trailingSlash shape passes" \
             || bad "REGRESSION: static export output fails"
echo "$OUT9" | grep -q 'Bỏ qua 1 trang nội bộ' && ok "static export: /404 deduplicated (404.html + 404/index.html)" \
                                               || warn "static export: /404 not deduplicated"
echo "$OUT9" | grep -q 'Đã kiểm tra 2 trang'  && ok "static export: routes resolved past /index.html" \
                                              || bad "static export: index.html shape not resolved"

# ---------------------------------------------------------------- summary
cd "$SKILL_DIR" || exit 2
printf '\n═══════════════════════════════════════════════════════════\n'
printf ' %s passed · %s warnings · %s failed\n' "$PASS" "$WARN" "$FAIL"
printf '═══════════════════════════════════════════════════════════\n'
[ "$FAIL" -eq 0 ] || exit 1
echo "✅ self-test OK"
