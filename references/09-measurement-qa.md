# 09 — Đo lường, kiểm thử, CI guardrail

Không có tầng này thì mọi thay đổi SEO chỉ là phỏng đoán.

---

## 9.1. Bộ công cụ chuẩn

| Công cụ | Dùng cho | Tần suất |
| --- | --- | --- |
| **Google Search Console** | Hiệu suất tìm kiếm, index, CWV, lỗi schema | Hàng ngày/tuần |
| **Bing Webmaster Tools** | Index Bing, IndexNow | Hàng tháng |
| **Google Analytics 4** | Hành vi, chuyển đổi theo kênh | Liên tục |
| **PageSpeed Insights** | CWV lab + trường cho 1 URL | Khi sửa |
| **Lighthouse (CLI/CI)** | Kiểm thử tự động | Mỗi PR |
| **Rich Results Test** | Schema | Khi thêm schema |
| **Schema Markup Validator** | Cú pháp schema.org | Khi thêm schema |
| **Screaming Frog / Sitebulb** | Crawl toàn site, phát hiện lỗi | Hàng tháng |
| **`curl` + script** | Kiểm tra HTML thô, header | Mỗi deploy |
| **Ahrefs / Semrush / Sistrix** | Backlink, đối thủ | Hàng tháng |
| **CrUX / `next/web-vitals`** | Dữ liệu trường | Liên tục |

---

## 9.2. Google Search Console — dùng đúng

### Cấu hình ban đầu

1. Xác minh **cả** `https://example.com` và `https://www.example.com` (hoặc property dạng Domain để bao hết).
2. Submit `sitemap.xml` (và các sitemap chuyên biệt).
3. Kiểm tra `robots.txt` bằng công cụ trong GSC.
4. Đặt email cảnh báo.

### Báo cáo cần xem định kỳ

| Báo cáo | Câu hỏi nó trả lời |
| --- | --- |
| **Pages / Indexing** | URL nào không được index, vì lý do gì |
| **Sitemaps** | Sitemap có đọc được, có bao nhiêu URL phát hiện |
| **Performance** | Truy vấn, trang, quốc gia, thiết bị |
| **Core Web Vitals** | Nhóm URL nào kém |
| **Enhancements** | Lỗi schema, breadcrumb |
| **Links** | Backlink nội bộ/bên ngoài |
| **Manual actions** | Hình phạt thủ công |
| **Security issues** | Malware, phishing |

### Lý do "không được index" và cách đọc

| Lý do GSC báo | Ý nghĩa | Hành động |
| --- | --- | --- |
| `Discovered – currently not indexed` | Chưa crawl | Tăng internal link, cải thiện chất lượng, kiểm tra crawl budget |
| `Crawled – currently not indexed` | Đã đọc, chưa thấy đáng index | **Cải thiện nội dung**; không phải lỗi kỹ thuật |
| `Duplicate without user-selected canonical` | Trùng lặp, chưa chọn canonical | Thêm canonical |
| `Duplicate, Google chose different canonical` | Google thích URL khác | Kiểm tra tín hiệu nội bộ, gộp nội dung |
| `Alternate page with proper canonical tag` | Bình thường với trang phụ | Không cần sửa |
| `Excluded by 'noindex' tag` | Cố ý chặn | Xác nhận có chủ đích |
| `Blocked by robots.txt` | Bị chặn crawl | Kiểm tra có nhầm không |
| `Soft 404` | Trả 200 nhưng nội dung rỗng | Trả 404/410 thật |
| `Not found (404)` | Đúng | Sửa link trỏ tới hoặc redirect |
| `Redirect error` | Vòng lặp/chuỗi | Sửa redirect |

### URL Inspection

Dùng cho URL cụ thể:
- Xem **HTML đã render** (bản Google thực sự thấy).
- Xem **ảnh chụp trang**.
- Xem **canonical Google chọn** và canonical bạn khai báo.
- Yêu cầu **kiểm tra lại** (chỉ khi đã sửa thật; lạm dụng không giúp gì).

---

## 9.3. Kiểm thử tự động trong CI

### Script kiểm tra HTML thô sau build

```js
// scripts/check-seo.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

const OUT = process.argv[2] ?? '.next/server/app'
const errors = []
const warnings = []

function walk(dir) {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f)
    return statSync(p).isDirectory() ? walk(p) : [p]
  })
}

const htmlFiles = walk(OUT).filter((f) => f.endsWith('.html'))
const titles = new Map()
const descs = new Map()

for (const file of htmlFiles) {
  const html = readFileSync(file, 'utf8')
  const route = file.replace(OUT, '').replace(/\.html$/, '') || '/'

  const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/)?.[1]?.trim()
  const desc = html.match(/<meta name="description" content="([^"]*)"/)?.[1]?.trim()
  const canonical = html.match(/<link rel="canonical" href="([^"]*)"/)?.[1]
  const h1s = html.match(/<h1[\s>]/g)?.length ?? 0
  const ogImage = html.match(/<meta property="og:image"/)?.[0]
  const noindex = /<meta name="robots"[^>]*noindex/.test(html)

  if (!title) errors.push(`${route}: thiếu <title>`)
  if (!desc) warnings.push(`${route}: thiếu meta description`)
  if (title && title.length > 65) warnings.push(`${route}: title dài ${title.length} ký tự`)
  if (desc && (desc.length < 50 || desc.length > 165)) warnings.push(`${route}: description dài ${desc.length}`)
  if (!noindex) {
    if (!canonical) errors.push(`${route}: thiếu canonical nhưng không noindex`)
    if (!ogImage) warnings.push(`${route}: thiếu og:image`)
    if (h1s !== 1) errors.push(`${route}: có ${h1s} thẻ <h1>`)
  }
  if (canonical && canonical.startsWith('http://')) errors.push(`${route}: canonical dùng HTTP`)

  if (title) titles.set(title, [...(titles.get(title) ?? []), route])
  if (desc) descs.set(desc, [...(descs.get(desc) ?? []), route])
}

for (const [t, routes] of titles) if (routes.length > 1) errors.push(`Title trùng "${t}": ${routes.join(', ')}`)
for (const [d, routes] of descs) if (routes.length > 1) warnings.push(`Description trùng: ${routes.join(', ')}`)

console.log(`Đã kiểm tra ${htmlFiles.length} trang`)
warnings.forEach((w) => console.log(`⚠️  ${w}`))
errors.forEach((e) => console.error(`❌ ${e}`))
if (errors.length) process.exit(1)
console.log('✅ Không có lỗi SEO chặn deploy')
```

```json
// package.json
{
  "scripts": {
    "seo:check": "node scripts/check-seo.mjs"
  }
}
```

### Lighthouse CI

```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse
on: [pull_request]
jobs:
  lhci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci && npm run build
      - run: npx @lhci/cli@latest autorun
        with:
          # cấu hình trong lighthouserc.json
```

```json
// lighthouserc.json
{
  "ci": {
    "collect": { "startServerCommand": "npm run start", "url": ["http://localhost:3000/", "http://localhost:3000/san-pham"], "numberOfRuns": 3 },
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.85 }],
        "categories:seo": ["error", { "minScore": 0.95 }],
        "categories:accessibility": ["warn", { "minScore": 0.9 }],
        "largest-contentful-paint": ["error", { "maxNumericValue": 2500 }],
        "cumulative-layout-shift": ["error", { "maxNumericValue": 0.1 }],
        "total-blocking-time": ["warn", { "maxNumericValue": 300 }]
      }
    }
  }
}
```

---

## 9.4. Kiểm tra thủ công nhanh

```bash
URL=https://example.com/san-pham/abc

# 1. Status code và redirect
curl -sIL "$URL" | grep -E '^HTTP/|^location:'

# 2. HTML thô có nội dung chính không (không chạy JS)
curl -sL "$URL" | wc -c
curl -sL "$URL" | grep -o '<h1[^>]*>[^<]*' | head -3

# 3. Title, canonical, robots
curl -sL "$URL" | grep -Eo '<title>[^<]*</title>|<link rel="canonical"[^>]*>|<meta name="robots"[^>]*>'

# 4. OG
curl -sL "$URL" | grep -Eo '<meta property="og:[^>]*>'

# 5. JSON-LD
curl -sL "$URL" | grep -c 'application/ld+json'

# 6. Trang 404 trả đúng status
curl -sI https://example.com/khong-ton-tai | head -1

# 7. robots.txt không chặn asset
curl -s https://example.com/robots.txt

# 8. Sitemap hợp lệ
curl -s https://example.com/sitemap.xml | head -20

# 9. Cache header
curl -sI https://example.com/ | grep -i -E 'cache-control|x-vercel-cache|cf-cache'

# 10. Kiểm tra Googlebot có bị chặn khác không
curl -s -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" https://example.com/robots.txt
```

---

## 9.5. Đo hiệu quả thay đổi SEO

**Nguyên tắc:** mọi thay đổi phải có baseline trước và so sánh sau, có khoảng thời gian đủ dài (thường ≥ 28 ngày do tính mùa và độ trễ index).

| Bước | Việc làm |
| --- | --- |
| 1 | Ghi lại baseline: impressions, clicks, CTR, position trung bình theo URL/nhóm |
| 2 | Ghi ngày deploy thay đổi |
| 3 | Không thay đổi gì khác trong cửa sổ đo (tránh nhiễu) |
| 4 | So sánh cùng kỳ (year-over-year) nếu có yếu tố mùa |
| 5 | Tách nhóm URL bị ảnh hưởng và nhóm đối chứng |
| 6 | Ghi lại kết luận vào tài liệu dự án |

**Cảnh báo:** Google cập nhật thuật toán liên tục (core update, spam update). Biến động không phải lúc nào cũng do thay đổi của bạn.

---

## 9.6. Log file analysis

Với site lớn, log server cho biết Googlebot thực sự crawl gì.

```bash
# Top URL được Googlebot crawl
grep -i "Googlebot" access.log \
  | awk '{print $7}' | sort | uniq -c | sort -rn | head -50

# URL Googlebot crawl nhưng không nên crawl
grep -i "Googlebot" access.log \
  | grep -E '\?(sort|filter|utm_)' | wc -l

# Tỷ lệ 5xx mà Googlebot gặp
grep -i "Googlebot" access.log | awk '$9 >= 500' | wc -l

# Số URL riêng biệt Googlebot đã crawl trong ngày
grep -i "Googlebot" access.log | awk '{print $7}' | sort -u | wc -l
```

Với Vercel/host không cho log thô, dùng log drain hoặc Search Console Crawl Stats.

---

## 9.7. Cảnh báo tự động nên thiết lập

| Cảnh báo | Ngưỡng gợi ý |
| --- | --- |
| Tỷ lệ lỗi 5xx cho Googlebot | > 1% |
| Số URL `noindex` tăng đột biến | +10% trong 1 ngày |
| Sitemap trả lỗi hoặc rỗng | Bất kỳ |
| Số URL trả 404 tăng đột biến | +20% trong 1 ngày |
| CWV p75 vượt ngưỡng | LCP > 2.5s hoặc INP > 200ms |
| Mất `canonical` trên nhiều trang | Bất kỳ đợt deploy |
| Manual action trong GSC | Bất kỳ |
| Điểm Lighthouse SEO < 95 | Mỗi PR |
| Thời gian build tăng vượt 2× | Mỗi build |

---

## 9.8. Checklist đo lường

- [ ] Search Console đã xác minh cho cả `www` và non-`www`
- [ ] Sitemap đã submit, không có lỗi
- [ ] GA4 ghi nhận organic traffic, có phân biệt brand/non-brand
- [ ] Bing Webmaster Tools đã cấu hình, cân nhắc IndexNow
- [ ] Thu thập CWV thực tế từ production (`useReportWebVitals`)
- [ ] Script `check-seo.mjs` chạy trong CI, chặn lỗi title/canonical/h1
- [ ] Lighthouse CI chạy mỗi PR với ngưỡng performance/seo/accessibility
- [ ] Kiểm tra `curl` HTML thô cho các mẫu trang chính
- [ ] Log analysis định kỳ (hoặc Crawl Stats trong GSC)
- [ ] Cảnh báo 5xx, noindex, 404 bất thường
- [ ] Baseline hiệu suất được ghi lại trước mỗi thay đổi lớn
- [ ] Có tài liệu theo dõi thay đổi SEO (changelog)
- [ ] Đã kiểm tra trên thiết bị mobile thật
- [ ] Đã kiểm tra với JS bị tắt (đại diện cho bot đợt 1)
