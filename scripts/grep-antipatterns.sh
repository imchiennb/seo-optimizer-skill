#!/usr/bin/env bash
# grep-antipatterns.sh — quét dấu hiệu rủi ro SEO trong repo Next.js.
# Dùng: bash scripts/grep-antipatterns.sh [thư_mục_app_or_src]
# Không sửa gì. Chỉ báo cáo.
#
# Script chạy được từ bất kỳ cwd nào: gốc dự án được suy ra từ thư mục app
# (hoặc đặt tường minh bằng biến PROJECT_ROOT).

APP_DIR="${1:-app}"
APP_DIR="${APP_DIR%/}"

if [ ! -d "$APP_DIR" ]; then
  echo "Không tìm thấy thư mục '$APP_DIR'. Truyền đường dẫn tới app/ (hoặc src/) làm tham số."
  exit 1
fi

# Suy ra gốc dự án để các kiểm tra như next.config.* và public/ không phụ thuộc cwd.
if [ -n "${PROJECT_ROOT:-}" ]; then
  PROJECT_ROOT="${PROJECT_ROOT%/}"
else
  PROJECT_ROOT="$(cd "$APP_DIR" && pwd)"
  [ "$(basename "$PROJECT_ROOT")" = "app" ] && PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
  [ "$(basename "$PROJECT_ROOT")" = "src" ] && PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
fi

hr() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

hr "1. 'use client' ở cấp page/layout (nên tránh)"
grep -rl "^'use client'" "$APP_DIR" --include="page.tsx" --include="layout.tsx" 2>/dev/null || echo "  ✓ không có"

hr "2. metadata export trong Client Component (lỗi)"
grep -rl "^'use client'" "$APP_DIR" 2>/dev/null \
  | xargs -r grep -l "export const metadata" 2>/dev/null || echo "  ✓ không có"

hr "3. force-dynamic (kiểm tra có thật sự cần)"
grep -rn "force-dynamic" "$APP_DIR" 2>/dev/null || echo "  ✓ không có"

hr "4. params chưa await [Next 15+]"
grep -rn "params\." "$APP_DIR" --include="*.tsx" 2>/dev/null | grep -v "await" || echo "  ✓ không có"

hr "5. metadataBase (bắt buộc ở layout gốc)"
grep -rn "metadataBase" "$APP_DIR" 2>/dev/null || echo "  ✗ THIẾU metadataBase"

hr "6. font subsets (cần 'vietnamese' nếu có tiếng Việt)"
grep -rn "subsets" "$APP_DIR" 2>/dev/null || echo "  (không dùng next/font)"

hr "7. priority trên next/image (mỗi trang chỉ nên có 1)"
grep -rn "priority" "$APP_DIR" --include="*.tsx" 2>/dev/null || echo "  ✓ không có"

hr "8. ảnh thiếu sizes (gây tải ảnh quá lớn)"
grep -rn "<Image" "$APP_DIR" --include="*.tsx" 2>/dev/null | grep -v "sizes=" || echo "  ✓ không có"

hr "9. JSON-LD double-stringify (lỗi)"
grep -rn "JSON.stringify(JSON.stringify" "$APP_DIR" 2>/dev/null || echo "  ✓ không có"

hr "10. dangerouslySetInnerHTML không escape '<' (rủi ro XSS với JSON-LD)"
DSI=$(grep -rn "dangerouslySetInnerHTML" "$APP_DIR" 2>/dev/null | grep -v "u003c" || true)
if [ -n "$DSI" ]; then echo "$DSI"; else echo "  ✓ không có (hoặc đã escape)"; fi

hr "11. index: false / noindex (kiểm tra có điều kiện môi trường không)"
grep -rn "index: false" "$APP_DIR" 2>/dev/null || echo "  ✓ không có"

hr "12. Xung đột file convention vs file tĩnh trong public/"
ROBOTS_APP=""
for e in ts tsx js jsx; do [ -f "$APP_DIR/robots.$e" ] && ROBOTS_APP="$APP_DIR/robots.$e" && break; done
SITEMAP_APP=""
for e in ts tsx js jsx; do [ -f "$APP_DIR/sitemap.$e" ] && SITEMAP_APP="$APP_DIR/sitemap.$e" && break; done
if [ -n "$ROBOTS_APP" ]; then
  if [ -f "$PROJECT_ROOT/public/robots.txt" ]; then
    echo "  ✗ TỒN TẠI CẢ HAI: $ROBOTS_APP và public/robots.txt — bỏ một"
  else
    echo "  ✓ chỉ có $ROBOTS_APP"
  fi
else
  echo "  · không có app/robots.* (dùng public/robots.txt?)"
fi
if [ -n "$SITEMAP_APP" ] && [ -f "$PROJECT_ROOT/public/sitemap.xml" ]; then
  echo "  ✗ TỒN TẠI CẢ HAI: $SITEMAP_APP và public/sitemap.xml — bỏ một"
fi
echo "  (gốc dự án suy ra: $PROJECT_ROOT)"

hr "13. dynamicParams (chống không gian URL vô hạn)"
grep -rn "dynamicParams" "$APP_DIR" 2>/dev/null || echo "  ⚠ chưa set dynamicParams ở route động nào"

hr "14. canonical"
CANON=$(grep -rn "canonical" "$APP_DIR" 2>/dev/null | head -20 || true)
if [ -n "$CANON" ]; then echo "$CANON"; else echo "  ✗ KHÔNG thấy canonical ở đâu — kiểm tra alternates.canonical"; fi

hr "15. notFound() — chống soft 404"
NF=$(grep -rn "notFound()" "$APP_DIR" 2>/dev/null | head -20 || true)
if [ -n "$NF" ]; then echo "$NF"; else echo "  ⚠ không thấy notFound() — kiểm tra soft 404 ở route động"; fi

hr "16. Link dùng cho điều hướng vs div onClick (không crawl được)"
grep -rn "onClick={() => router.push" "$APP_DIR" 2>/dev/null || echo "  ✓ không có"

hr "17. next/script strategy"
grep -rn "strategy=" "$APP_DIR" 2>/dev/null || echo "  (không dùng next/script)"

hr "18. ImageResponse — kiểm tra font tiếng Việt"
grep -rln "ImageResponse" "$APP_DIR" 2>/dev/null | while read -r f; do
  grep -q "fonts:" "$f" || echo "  ⚠ $f: ImageResponse không khai báo fonts — chữ có dấu có thể lỗi"
done

hr "19. sitemap"
if [ -f "$APP_DIR/sitemap.ts" ] || [ -f "$APP_DIR/sitemap.tsx" ]; then
  echo "  ✓ có app/sitemap.ts"
else
  echo "  ✗ THIẾU app/sitemap.ts"
fi

hr "20. cấu hình next.config"
CONF=""
for e in ts mjs js cjs; do
  [ -f "$PROJECT_ROOT/next.config.$e" ] && CONF="$PROJECT_ROOT/next.config.$e" && break
done
if [ -n "$CONF" ]; then
  echo "  File: $CONF"
  for key in trailingSlash poweredByHeader redirects headers images formats optimizePackageImports cacheComponents; do
    grep -q "$key" "$CONF" && echo "  ✓ $key" || echo "  · $key (chưa set)"
  done
else
  echo "  · không tìm thấy next.config.* trong $PROJECT_ROOT (dùng mặc định)"
fi

hr "21. next/headers trong layout/page — nguyên nhân số 1 làm toàn site thành dynamic"
# Một lời gọi cookies() trong layout gốc kéo TOÀN BỘ cây route ra khỏi static
# rendering: không prerender được trang nào, Next trả
# `cache-control: private, no-store`, CDN không cache được gì, TTFB cao và mỗi
# lần Googlebot crawl là một lần render đầy đủ.
#
# Phát hiện thật: moai.profyai.vn KHÔNG import next/headers trong layout — nó gọi
# một helper `getPrefsFromCookies()` từ modules/utils/prefs.server.ts, và helper
# đó mới là chỗ đọc cookies(). Grep trực tiếp trên layout vì thế báo "không có",
# tức là bỏ sót đúng ca phổ biến nhất trong codebase được tổ chức tử tế.
# → Phải lần theo import nội bộ một cấp.

# Gốc của alias "@/": đọc tsconfig.json nếu được, nếu không mặc định "src".
# Nhiều dự án đặt code ở gốc thay vì src/ — chỉ thử "src/" sẽ bỏ sót.
ALIAS_BASE=$(node -e '
  try {
    const t = require(process.argv[1]);
    const paths = (t.compilerOptions && t.compilerOptions.paths) || {};
    for (const k of Object.keys(paths)) {
      if (k === "@/*" || k === "@") {
        const v = (paths[k] && paths[k][0]) || "";
        const b = v.replace(/^\.\//, "").replace(/\/\*$/, "");
        if (b) { console.log(b); process.exit(0); }
      }
    }
  } catch {}
' "$PROJECT_ROOT/tsconfig.json" 2>/dev/null || true)
[ -z "$ALIAS_BASE" ] && ALIAS_BASE="src"

trace_headers() { # $1 = file; in ra "self" hoặc đường dẫn module nội bộ dùng next/headers
  grep -q "next/headers" "$1" 2>/dev/null && { echo "self"; return; }
  local mods m rel cand ext
  mods=$(grep -oE "from ['\"][^'\"]+['\"]" "$1" 2>/dev/null \
         | sed "s/from ['\"]//; s/['\"]$//" | grep -E '^(@/|\.)' || true)
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    case "$m" in @/*) rel="${m#@/}" ;; *) rel="$m" ;; esac
    for cand in \
        "$PROJECT_ROOT/$ALIAS_BASE/$rel" \
        "$PROJECT_ROOT/src/$rel" \
        "$PROJECT_ROOT/$rel" \
        "$(dirname "$1")/$rel"; do
      for ext in ts tsx js jsx; do
        if [ -f "$cand.$ext" ] && grep -q "next/headers" "$cand.$ext" 2>/dev/null; then
          echo "$cand.$ext"; return
        fi
      done
    done
  done <<< "$mods"
}

FOUND_LAYOUT=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  src=$(trace_headers "$f")
  [ -z "$src" ] && continue
  FOUND_LAYOUT=1
  if [ "$src" = "self" ]; then
    echo "  ❌ $f (import next/headers trực tiếp)"
  else
    echo "  ❌ $f  ←  $src"
  fi
done < <(find "$APP_DIR" -type f \( -name 'layout.tsx' -o -name 'layout.jsx' -o -name 'layout.ts' -o -name 'layout.js' \) 2>/dev/null)

if [ "$FOUND_LAYOUT" -eq 1 ]; then
  echo "     ↳ next/headers trong LAYOUT — MỌI route bên dưới thành dynamic:"
  echo "       không prerender được, CDN không cache được, TTFB cao."
  echo "       Cách sửa: cô lập phần đọc cookie vào một client component, hoặc bọc"
  echo "       trong <Suspense> kèm cacheComponents (PPR) để phần shell vẫn tĩnh."
else
  echo "  ✓ không có layout nào (trực tiếp hoặc qua module nội bộ) dùng next/headers"
fi

FOUND_PAGE=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  src=$(trace_headers "$f")
  [ -z "$src" ] && continue
  FOUND_PAGE=1
  echo "  ⚠ $f$([ "$src" = "self" ] || echo "  ←  $src")"
done < <(find "$APP_DIR" -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.ts' -o -name 'page.js' \) 2>/dev/null)
[ "$FOUND_PAGE" -eq 1 ] && echo "     ↳ next/headers trong page — chỉ trang đó dynamic (chấp nhận được hơn layout)"

# Xác nhận hậu quả: đếm route trong source so với số trang prerender được
if [ -d "$PROJECT_ROOT/.next/server/app" ]; then
  SRC_ROUTES=$(find "$APP_DIR" -type f \( -name 'page.tsx' -o -name 'page.jsx' -o -name 'page.ts' -o -name 'page.js' \) 2>/dev/null | wc -l | tr -d ' ')
  PRE_HTML=$(find "$PROJECT_ROOT/.next/server/app" -name '*.html' 2>/dev/null | grep -vcE '_(not-found|global-error|error)\.html$' || true)
  echo "  · route trong source: ${SRC_ROUTES:-0} | trang prerender: ${PRE_HTML:-0}"
  if [ "${SRC_ROUTES:-0}" -gt 0 ] && [ "${PRE_HTML:-0}" -eq 0 ]; then
    echo "    ❌ 0 trang prerender → mọi route đang dynamic (xem references/02 §2.9)"
  fi
fi

printf '\n\033[1mHoàn tất.\033[0m Đánh giá từng mục theo references/10-antipatterns.md\n'
