#!/usr/bin/env bash
# audit-url.sh — kiểm tra HTML thô (không chạy JS) của URL production.
# Đây là thứ Googlebot nhận ở đợt crawl đầu.
#
# Dùng: bash scripts/audit-url.sh https://example.com/san-pham/abc
#       bash scripts/audit-url.sh https://example.com / /bang-gia /lien-he

set -uo pipefail

if [ $# -eq 0 ]; then
  echo "Dùng: $0 <domain> [path1 path2 ...]"
  echo "Ví dụ: $0 https://example.com / /san-pham /bai-viet/abc"
  exit 1
fi

DOMAIN="${1%/}"
shift
PATHS=("$@")
[ ${#PATHS[@]} -eq 0 ] && PATHS=("/")

for PATH_ in "${PATHS[@]}"; do
  URL="${DOMAIN}${PATH_}"
  echo "══════════════════════════════════════════════════════════════"
  echo "URL: $URL"
  echo "══════════════════════════════════════════════════════════════"

  # 1. Status + redirect chain + thời gian
  echo "── Status / redirect / timing"
  curl -sL -o /dev/null -w "   HTTP cuối: %{http_code}\n   Số redirect: %{num_redirects}\n   TTFB: %{time_starttransfer}s\n   Tổng: %{time_total}s\n   Kích thước: %{size_download} bytes\n" "$URL"

  echo "── Chuỗi redirect"
  curl -sIL "$URL" | grep -iE '^HTTP/|^location:' | sed 's/^/   /'

  # 2. Cache header — PHẢI xem response CUỐI sau redirect.
  # Dùng -sI trên URL gốc sẽ đọc header của response 3xx, vốn không mang
  # Cache-Control của trang thật → bỏ sót lỗi cache nghiêm trọng.
  FINAL=$(curl -sL -o /dev/null -w '%{url_effective}' "$URL")
  echo "── Cache header (response cuối)"
  [ "$FINAL" != "$URL" ] && echo "   URL cuối: $FINAL"
  curl -sI "$FINAL" | grep -iE 'cache-control|x-vercel-cache|cf-cache-status|age:|x-robots-tag' | sed 's/^/   /'
  if ! curl -sI "$FINAL" | grep -qi 'cache-control'; then
    echo "   ⚠ KHÔNG có Cache-Control → CDN không thể cache HTML (TTFB cao, tốn crawl budget)"
  elif curl -sI "$FINAL" | grep -qiE 'no-store|no-cache'; then
    echo "   ⚠ Cache-Control chứa no-store/no-cache → mọi request đều render lại từ đầu"
  fi
  if curl -sI "$FINAL" | grep -qi 'cf-cache-status: DYNAMIC'; then
    echo "   ⚠ cf-cache-status: DYNAMIC → Cloudflare không cache trang này"
  fi

  BODY=$(curl -sL "$URL")

  # 3. Metadata cơ bản
  echo "── Metadata"
  echo "$BODY" | grep -oiE '<title[^>]*>[^<]*</title>' | head -1 | sed 's/^/   /' || echo "   ✗ THIẾU title"
  echo "$BODY" | grep -oiE '<link[^>]*rel="canonical"[^>]*>' | head -1 | sed 's/^/   /' || echo "   ✗ THIẾU canonical"
  echo "$BODY" | grep -oiE '<meta[^>]*name="robots"[^>]*>' | head -1 | sed 's/^/   /' || echo "   (không có meta robots — mặc định index,follow)"
  echo "$BODY" | grep -oiE '<html[^>]*lang="[^"]*"' | head -1 | sed 's/^/   /' || echo "   ✗ THIẾU lang trên <html>"

  # 4. Open Graph
  echo "── Open Graph"
  echo "$BODY" | grep -oiE '<meta[^>]*property="og:[^"]*"[^>]*>' | head -8 | sed 's/^/   /' || echo "   ✗ THIẾU OG tags"
  OGIMG=$(echo "$BODY" | grep -oiE 'property="og:image"[^>]*content="[^"]*"' | head -1 | grep -oE 'https?://[^"]*')
  if [ -n "${OGIMG:-}" ]; then
    CODE=$(curl -sI -o /dev/null -w "%{http_code}" "$OGIMG")
    echo "   og:image status: $CODE"
  fi

  # 5. Cấu trúc nội dung trong HTML thô
  echo "── Nội dung trong HTML thô (bot đợt 1 thấy gì)"
  H1=$(echo "$BODY" | grep -oiE '<h1[^>]*>' | wc -l | tr -d ' ')
  LINKS=$(echo "$BODY" | grep -oiE '<a [^>]*href=' | wc -l | tr -d ' ')
  TEXT_LEN=$(echo "$BODY" | sed 's/<script[^>]*>.*<\/script>//g; s/<[^>]*>//g' | tr -s ' \n' ' ' | wc -c | tr -d ' ')
  echo "   Số <h1>: $H1"
  echo "   Số <a href>: $LINKS"
  echo "   Ký tự text (sau khi bỏ thẻ): $TEXT_LEN"
  [ "$TEXT_LEN" -lt 800 ] && echo "   ⚠ text rất ít — nội dung có thể chỉ render phía client"

  echo "── Heading outline"
  echo "$BODY" | grep -oiE '<h[1-3][^>]*>[^<]*' | sed 's/<[^>]*>//g; s/^/   /' | head -12

  # 6. Structured data
  echo "── Structured data"
  LD=$(echo "$BODY" | grep -c 'application/ld+json')
  echo "   Số block JSON-LD: $LD"
  if [ "$LD" -gt 0 ]; then
    echo "$BODY" | grep -oE '"@type"\s*:\s*"[^"]*"' | sort -u | sed 's/^/   /' | head -10
  fi

  # 7. Ảnh thiếu alt
  NOALT=$(echo "$BODY" | grep -oiE '<img[^>]*>' | grep -vic 'alt=' || true)
  echo "── Ảnh"
  echo "   <img> thiếu alt: ${NOALT:-0}"

  # 8. Tín hiệu xấu
  echo "── Tín hiệu xấu"
  echo "$BODY" | grep -qiE 'Lorem ipsum|TODO|FIXME|placeholder' && echo "   ⚠ có text placeholder trong HTML" || echo "   ✓ không có placeholder rõ ràng"
  echo "$BODY" | grep -qiE 'name="robots"[^>]*noindex' && echo "   ⚠ TRANG NÀY ĐANG NOINDEX" || true

  echo
done

echo "══════════════════════════════════════════════════════════════"
echo "Kiểm tra thêm tại:"
echo "  • https://search.google.com/test/rich-results"
echo "  • https://pagespeed.web.dev/"
echo "  • https://validator.schema.org/"
echo "══════════════════════════════════════════════════════════════"
