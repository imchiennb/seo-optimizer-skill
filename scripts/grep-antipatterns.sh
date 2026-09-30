#!/usr/bin/env bash
# grep-antipatterns.sh — quét dấu hiệu rủi ro SEO trong repo Next.js App Router.
# Dùng: bash scripts/grep-antipatterns.sh [thư_mục_app]
# Không sửa gì. Chỉ báo cáo.

APP_DIR="${1:-app}"

if [ ! -d "$APP_DIR" ]; then
  echo "Không tìm thấy thư mục '$APP_DIR'. Truyền đường dẫn tới app/ làm tham số."
  exit 1
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

hr "12. Xung đột robots.ts vs public/robots.txt"
if [ -f "$APP_DIR/robots.ts" ] || [ -f "$APP_DIR/robots.tsx" ]; then
  [ -f "public/robots.txt" ] && echo "  ✗ TỒN TẠI CẢ HAI — bỏ một" || echo "  ✓ chỉ có app/robots.ts"
else
  echo "  (không có app/robots.ts)"
fi

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
if [ -f "next.config.ts" ] || [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
  CONF=$(ls next.config.* 2>/dev/null | head -1)
  echo "  File: $CONF"
  for key in trailingSlash poweredByHeader redirects headers images formats optimizePackageImports cacheComponents; do
    grep -q "$key" "$CONF" && echo "  ✓ $key" || echo "  · $key (chưa set)"
  done
else
  echo "  ✗ không tìm thấy next.config"
fi

printf '\n\033[1mHoàn tất.\033[0m Đánh giá từng mục theo references/10-antipatterns.md\n'
