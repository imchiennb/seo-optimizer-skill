#!/usr/bin/env bash
# detect-project.sh — nhận diện cấu hình Next.js của một dự án bất kỳ.
# Dùng: bash detect-project.sh [đường_dẫn_dự_án]
# Không sửa gì. Chỉ báo cáo.

set -uo pipefail

ROOT="${1:-.}"
if ! cd "$ROOT" 2>/dev/null; then
  echo "❌ Không vào được thư mục: $ROOT"
  exit 1
fi

hr() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

echo "═══════════════════════════════════════════════════════════"
echo " NHẬN DIỆN DỰ ÁN NEXT.JS"
echo " Thư mục: $(pwd)"
echo "═══════════════════════════════════════════════════════════"

# ---------- 1. package.json ----------
hr "1. Dependencies"
if [ -f package.json ]; then
  node -e '
    const p = require("./package.json");
    const d = { ...p.dependencies, ...p.devDependencies };
    const pick = (k) => d[k] ?? "(không có)";
    console.log("   next          :", pick("next"));
    console.log("   react         :", pick("react"));
    console.log("   react-dom     :", pick("react-dom"));
    console.log("");
    console.log("   Thư viện SEO / liên quan:");
    const seo = ["next-seo","next-sitemap","schema-dts","@next/third-parties","next-intl","next-i18next","@vercel/analytics","@vercel/speed-insights"];
    let found = false;
    for (const k of seo) if (d[k]) { console.log("     •", k, d[k]); found = true; }
    if (!found) console.log("     (không có)");
    console.log("");
    console.log("   Scripts:");
    for (const [k,v] of Object.entries(p.scripts ?? {})) console.log("     " + k + ": " + v);
  ' 2>/dev/null || echo "   ⚠ không parse được package.json"
else
  echo "   ❌ Không tìm thấy package.json — đây có phải dự án Node?"
fi

# ---------- 2. Router ----------
hr "2. Router"
HAS_APP=0; HAS_PAGES=0
[ -d app ] && HAS_APP=1
[ -d src/app ] && HAS_APP=1
[ -d pages ] && HAS_PAGES=1
[ -d src/pages ] && HAS_PAGES=1

APP_DIR=""
for c in app src/app; do [ -d "$c" ] && APP_DIR="$c" && break; done
PAGES_DIR=""
for c in pages src/pages; do [ -d "$c" ] && PAGES_DIR="$c" && break; done

if [ "$HAS_APP" = 1 ] && [ "$HAS_PAGES" = 1 ]; then
  echo "   ⚠ HYBRID — có cả App Router lẫn Pages Router"
  echo "     App Router  : $APP_DIR"
  echo "     Pages Router: $PAGES_DIR"
  echo "     → Cần xác định nhánh nào đang phục vụ URL nào trước khi sửa."
elif [ "$HAS_APP" = 1 ]; then
  echo "   ✅ APP ROUTER  ($APP_DIR)"
elif [ "$HAS_PAGES" = 1 ]; then
  echo "   ✅ PAGES ROUTER ($PAGES_DIR)"
  echo "     → Dùng bảng ánh xạ ở references/14-migration-and-upgrade.md"
  echo "     → Lưu ý: Pages Router VẪN được hỗ trợ đầy đủ trong Next.js 16.x."
else
  echo "   ⚠ Không tìm thấy app/ hay pages/"
fi

# ---------- 3. Số route ----------
hr "3. Quy mô route"
if [ -n "$APP_DIR" ]; then
  # Next cho phép .js / .jsx / .ts / .tsx cho mọi file convention — phải đếm đủ cả 4.
  N_PAGE=$(find "$APP_DIR" -type f \( -name "page.tsx" -o -name "page.ts" -o -name "page.jsx" -o -name "page.js" \) 2>/dev/null | wc -l | tr -d ' ')
  N_LAYOUT=$(find "$APP_DIR" -type f \( -name "layout.tsx" -o -name "layout.ts" -o -name "layout.jsx" -o -name "layout.js" \) 2>/dev/null | wc -l | tr -d ' ')
  N_DYNAMIC=$(find "$APP_DIR" -type d -name "\[*\]" 2>/dev/null | wc -l | tr -d ' ')
  N_API=$(find "$APP_DIR" -type f \( -name "route.ts" -o -name "route.tsx" -o -name "route.js" -o -name "route.jsx" \) 2>/dev/null | wc -l | tr -d ' ')
  echo "   page.*     : $N_PAGE"
  echo "   layout.*   : $N_LAYOUT"
  echo "   route.*    : $N_API"
  echo "   segment động [param]: $N_DYNAMIC"
  [ "$N_DYNAMIC" -gt 0 ] && echo "     → Kiểm tra dynamicParams ở từng segment động (chống không gian URL vô hạn)"
fi
if [ -n "$PAGES_DIR" ]; then
  N_PAGES=$(find "$PAGES_DIR" -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" \) 2>/dev/null | wc -l | tr -d ' ')
  N_PDYN=$(find "$PAGES_DIR" -type f -name "\[*\]*" 2>/dev/null | wc -l | tr -d ' ')
  echo "   pages/*    : $N_PAGES"
  echo "   route động : $N_PDYN"
fi

# ---------- 4. next.config ----------
hr "4. next.config"
CONF=""
for c in next.config.ts next.config.mjs next.config.js next.config.cjs; do
  [ -f "$c" ] && CONF="$c" && break
done
if [ -n "$CONF" ]; then
  echo "   File: $CONF"
  for key in trailingSlash poweredByHeader output cacheComponents compress basePath assetPrefix i18n rewrites redirects headers images formats optimizePackageImports experimental; do
    if grep -q "$key" "$CONF" 2>/dev/null; then
      echo "   ✓ $key"
    fi
  done
  echo "   --- Kiểm tra thủ công các mục quan trọng ---"
  grep -q "trailingSlash" "$CONF" || echo "   · trailingSlash: chưa set (mặc định false)"
  grep -q "poweredByHeader" "$CONF" || echo "   · poweredByHeader: chưa set (mặc định true → nên tắt)"
  if grep -q "output.*export" "$CONF" 2>/dev/null; then
    echo "   ⚠ STATIC EXPORT — không có ISR, không có Route Handler động, phải tự lo redirect/header"
  fi
  if grep -q "i18n" "$CONF" 2>/dev/null && [ "$HAS_APP" = 1 ]; then
    echo "   ⚠ Có 'i18n' trong config nhưng đang dùng App Router — config này KHÔNG hoạt động ở App Router"
  fi
else
  echo "   (không có next.config — mặc định)"
fi

# ---------- 5. Hạ tầng SEO hiện có ----------
hr "5. Hạ tầng SEO hiện có"
chk_ext() {  # $1 = nhãn, $2 = đường dẫn không phần mở rộng
  for e in ts tsx js jsx mjs; do
    if [ -f "$2.$e" ]; then echo "   ✅ $1 → $2.$e"; return; fi
  done
  echo "   ❌ $1 → $2.{ts,tsx,js,jsx} (THIẾU)"
}
chk_icon() {  # $1 = nhãn, $2 = đường dẫn không phần mở rộng
  for e in png ico svg jpg jpeg tsx jsx ts js; do
    if [ -f "$2.$e" ]; then echo "   ✅ $1 → $2.$e"; return; fi
  done
  echo "   ❌ $1 → $2.{png,ico,svg,jpg} (THIẾU)"
}
if [ -n "$APP_DIR" ]; then
  chk_ext "sitemap"        "$APP_DIR/sitemap"
  chk_ext "robots"         "$APP_DIR/robots"
  chk_ext "not-found"      "$APP_DIR/not-found"
  chk_ext "manifest"       "$APP_DIR/manifest"
  chk_ext "opengraph-image" "$APP_DIR/opengraph-image"
  chk_ext "twitter-image"  "$APP_DIR/twitter-image"
  chk_icon "icon"          "$APP_DIR/icon"
  chk_icon "apple-icon"    "$APP_DIR/apple-icon"
fi
[ -f public/robots.txt ] && echo "   ⚠ public/robots.txt tồn tại — kiểm tra xung đột với app/robots.*"
[ -f public/sitemap.xml ] && echo "   ⚠ public/sitemap.xml tồn tại — kiểm tra xung đột với app/sitemap.*"
[ -d public ] && [ -z "$(ls -A public 2>/dev/null | grep -iE 'robots|sitemap')" ] && echo "   · public/: không có robots/sitemap tĩnh"

hr "6. Middleware / Proxy"
for f in middleware.ts middleware.js proxy.ts proxy.js src/middleware.ts src/proxy.ts; do
  [ -f "$f" ] && echo "   ✓ $f"
done
[ -f middleware.ts ] || [ -f middleware.js ] || [ -f src/middleware.ts ] || [ -f proxy.ts ] || [ -f src/proxy.ts ] || echo "   (không có middleware/proxy)"

# ---------- 7. Metadata ----------
hr "7. Metadata"
if [ -n "$APP_DIR" ]; then
  MB=$(grep -rl "metadataBase" "$APP_DIR" 2>/dev/null | head -3)
  GEN=$(grep -rl "generateMetadata" "$APP_DIR" 2>/dev/null | wc -l | tr -d ' ')
  VIEW=$(grep -rl "export const viewport" "$APP_DIR" 2>/dev/null | head -1)
  CANON=$(grep -rl "canonical" "$APP_DIR" 2>/dev/null | wc -l | tr -d ' ')
  echo "   metadataBase      : ${MB:-❌ THIẾU (bắt buộc ở layout gốc)}"
  echo "   generateMetadata  : $GEN file"
  echo "   export viewport   : ${VIEW:-❌ thiếu}"
  echo "   canonical         : $CANON file"
fi
if grep -rq "next/head\|<Head>" ${PAGES_DIR:-pages} 2>/dev/null; then
  echo "   Pages Router dùng next/head — kiểm tra từng trang có title/description/canonical"
fi

# ---------- 8. i18n ----------
hr "8. i18n / locale"
find "${APP_DIR:-app}" -maxdepth 2 -type d -name "\[locale\]" 2>/dev/null | sed 's/^/   ✓ segment locale: /'
grep -rl "hreflang\|alternates.*languages" "${APP_DIR:-app}" 2>/dev/null | head -3 | sed 's/^/   ✓ hreflang: /' || true

# ---------- 9. Font ----------
hr "9. Font"
if grep -rq "next/font" "${APP_DIR:-app}" ${PAGES_DIR:-pages} 2>/dev/null; then
  if grep -rq "vietnamese" "${APP_DIR:-app}" ${PAGES_DIR:-pages} 2>/dev/null; then
    echo "   ✅ có subset 'vietnamese'"
  else
    echo "   ⚠ dùng next/font nhưng KHÔNG thấy subset 'vietnamese' — kiểm tra nếu site có tiếng Việt"
  fi
else
  echo "   (không dùng next/font)"
fi

# ---------- 10. CI ----------
hr "10. CI / guardrail"
[ -d .github/workflows ] && ls .github/workflows | sed 's/^/   ✓ .github\/workflows\//' || echo "   (không có GitHub Actions)"
grep -rl "lighthouse\|lhci" .github 2>/dev/null | sed 's/^/   ✓ lighthouse: /' || true
if [ -f package.json ] && node -e 'process.exit(require("./package.json").scripts?.["seo:check"]?0:1)' 2>/dev/null; then
  echo "   ✅ có script seo:check"
else
  echo "   · chưa có script seo:check"
fi

# ---------- Tổng kết ----------
printf '\n\033[1m═══════════════════════════════════════════════════════════\033[0m\n'
printf '\033[1m BƯỚC TIẾP THEO\033[0m\n'
printf '\033[1m═══════════════════════════════════════════════════════════\033[0m\n'
echo " 1. Quét anti-pattern :"
echo "      bash <SKILL_DIR>/scripts/grep-antipatterns.sh ${APP_DIR:-app}"
echo " 2. Build rồi kiểm tra HTML:"
echo "      npm run build && node <SKILL_DIR>/scripts/check-seo.mjs .next/server/app --site=<domain>"
echo " 3. Kiểm tra HTML thô production:"
echo "      bash <SKILL_DIR>/scripts/audit-url.sh https://<domain> / /<trang-chinh>"
echo " 4. Đọc reference theo bảng routing trong SKILL.md §9"
echo
