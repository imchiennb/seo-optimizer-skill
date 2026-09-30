# 18 — Quy trình team & review

SEO thất bại phần lớn không vì thiếu kiến thức kỹ thuật, mà vì **không có ai chịu trách nhiệm và không có bước kiểm tra trong quy trình**.

---

## 18.1. Nguyên tắc: shift-left

Chi phí sửa một lỗi SEO tăng theo thời điểm phát hiện:

| Phát hiện ở | Chi phí | Thời gian khắc phục |
| --- | --- | --- |
| Lúc viết code | Rất thấp | Phút |
| Code review | Thấp | Phút |
| CI | Thấp | Phút |
| Staging | Trung bình | Giờ |
| Sau launch vài ngày | Cao | Ngày |
| Sau khi mất traffic | **Rất cao** | **Tuần đến tháng** |

Một dòng trong CI rẻ hơn một tháng mất traffic. Đây là toàn bộ lý do của file này.

---

## 18.2. Ranh giới trách nhiệm

| Vai trò | Chịu trách nhiệm | Không chịu trách nhiệm |
| --- | --- | --- |
| **SEO** | Chiến lược từ khoá, ánh xạ URL, tài liệu `site-config`, phân tích GSC, viết yêu cầu | Viết code, quyết định kiến trúc |
| **Dev** | Metadata API, sitemap/robots, schema, render strategy, CWV, redirect | Quyết định nhắm từ khoá nào |
| **Content** | Chất lượng nội dung, E-E-A-T, internal link, title/description đề xuất | Cấu hình kỹ thuật |
| **Design** | Không gây CLS, không interstitial, a11y, tương phản | Metadata |
| **DevOps** | CDN, cache header, uptime, SSL, monitoring | Nội dung |
| **Chủ sở hữu** | Quyết định ưu tiên, ngân sách, chấp nhận đánh đổi | Chi tiết kỹ thuật |

**Điểm giao thường xảy ra lỗi:** giữa SEO (yêu cầu) và Dev (thực thi). Cách chống: **ticket có tiêu chí nghiệm thu kỹ thuật cụ thể**, không phải mô tả chung.

---

## 18.3. Ticket SEO — mẫu

Đặt ở `.github/ISSUE_TEMPLATE/seo.md`.

```markdown
---
name: Yêu cầu SEO
about: Thay đổi có ảnh hưởng SEO
labels: seo
---

## Vấn đề
<!-- Bằng chứng cụ thể, không phải nhận định chung -->
Ví dụ: 120 trang danh mục dùng chung title "Sản phẩm" → CTR 0,8% (GSC 30 ngày).

## URL bị ảnh hưởng
- https://example.com/danh-muc/ao-thun
- (hoặc: tất cả route khớp `/danh-muc/[slug]`)

## Bằng chứng
<!-- Output lệnh, ảnh chụp GSC, số liệu -->
```
$ curl -s https://example.com/danh-muc/ao-thun | grep -o '<title>[^<]*'
<title>Sản phẩm</title>
```

## Thay đổi yêu cầu
- [ ] `generateMetadata` sinh title theo tên danh mục
- [ ] Thêm canonical tự thân
- [ ] Thêm `BreadcrumbList`

## Tiêu chí nghiệm thu
- [ ] Mỗi trang danh mục có title riêng, ≤ 58 ký tự
- [ ] `curl` xác nhận title đúng trên 3 URL mẫu
- [ ] `node scripts/check-seo.mjs` không có lỗi title trùng
- [ ] Không thay đổi URL hiện có
- [ ] Lighthouse SEO ≥ 95

## Rủi ro
- Nếu đổi title hàng loạt, CTR có thể dao động 2–4 tuần trước khi ổn định.

## Kế hoạch đo
Baseline: impressions 45.200 · clicks 361 · CTR 0,80%
Đo lại: sau 28 ngày
```

---

## 18.4. PR review checklist SEO

Dùng khi diff có thay đổi chạm vào SEO. Thêm vào `.github/pull_request_template.md`.

```markdown
## Checklist SEO (bỏ qua nếu PR không chạm SEO)

### Nếu thêm/sửa route
- [ ] Có `generateMetadata` hoặc `metadata`
- [ ] Có `alternates.canonical`
- [ ] Có `openGraph.images` (nhớ bẫy merge nông)
- [ ] `params`/`searchParams` được `await`
- [ ] Trang riêng tư/dynamic có `robots: { index: false }`

### Nếu thêm component
- [ ] `'use client'` chỉ ở component lá
- [ ] Điều hướng dùng `<Link>`, không `div onClick`
- [ ] Một `<h1>` duy nhất, không nhảy cấp heading
- [ ] Ảnh có `alt` và `width`/`height` hoặc khung tỷ lệ

### Nếu sửa ảnh
- [ ] Dùng `next/image`
- [ ] Có `sizes` nếu ảnh responsive
- [ ] Chỉ một ảnh `priority` mỗi trang
- [ ] Tên file có nghĩa, không dấu

### Nếu sửa `next.config`
- [ ] Redirect là `permanent: true` nếu vĩnh viễn
- [ ] Không có redirect chain
- [ ] `trailingSlash` không đổi (trừ khi có chủ đích + redirect)
- [ ] Header không chặn Googlebot

### Nếu sửa font/script
- [ ] `next/font` có subset `vietnamese`
- [ ] Script bên thứ ba dùng `afterInteractive` hoặc `lazyOnload`

### Nếu sửa JSON-LD
- [ ] Có escape `<`
- [ ] Không double-stringify
- [ ] Trường bắt buộc đầy đủ
- [ ] Nội dung khớp những gì hiển thị trên trang

### Nếu đổi URL
- [ ] Có redirect 308 ánh xạ 1-1
- [ ] Cập nhật sitemap
- [ ] Cập nhật internal link
- [ ] Cập nhật canonical

### Bắt buộc
- [ ] `npm run build` xanh
- [ ] `node scripts/check-seo.mjs` xanh
- [ ] Lighthouse CI xanh
```

---

## 18.5. Guardrail tự động

### CI đầy đủ

```yaml
# .github/workflows/seo.yml
name: SEO guardrails
on: [pull_request]

jobs:
  seo:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }

      - run: npm ci

      - name: Quét anti-pattern
        run: bash scripts/grep-antipatterns.sh app

      - name: Build
        run: npm run build

      - name: Kiểm tra HTML đã build
        run: node scripts/check-seo.mjs .next/server/app --site=${{ vars.SITE_URL }}

      - name: Lighthouse CI
        run: npx @lhci/cli@latest autorun
```

### Pre-commit hook

```bash
#!/usr/bin/env bash
# .husky/pre-commit
set -e

# Chặn commit nếu có dấu hiệu SEO rõ ràng trong file thay đổi
changed=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(tsx|ts)$' || true)
[ -z "$changed" ] && exit 0

# Metadata trong client component
for f in $changed; do
  if head -1 "$f" | grep -q "use client" && grep -q "export const metadata" "$f"; then
    echo "❌ $f: metadata export trong Client Component"
    exit 1
  fi
done

# JSON-LD double-stringify
if git diff --cached -U0 | grep -q "JSON.stringify(JSON.stringify"; then
  echo "❌ Phát hiện JSON-LD double-stringify"
  exit 1
fi

echo "✅ Pre-commit SEO OK"
```

---

## 18.6. Nhịp làm việc

| Nhịp | Việc làm | Người làm | Thời lượng |
| --- | --- | --- | --- |
| **Hàng ngày** | Kiểm tra cảnh báo 5xx, uptime, deploy | DevOps/Dev | 5 phút |
| **Hàng tuần** | Xem GSC: impression, click, CTR, trang mới mất index | SEO | 30 phút |
| **Hàng tuần** | Xem lỗi CI, PR tồn đọng | Dev | 15 phút |
| **Hàng tháng** | Audit đầy đủ theo `11-launch-checklist.md` gate C | SEO + Dev | 2–3 giờ |
| **Hàng tháng** | Rà soát truy vấn chồng lấn giữa các site | SEO | 1 giờ |
| **Hàng quý** | Rà soát chiến lược, cập nhật `site-config`, kế hoạch nâng cấp | Cả nhóm | 2 giờ |
| **Hàng quý** | Cập nhật kiến thức: schema nào còn hỗ trợ, Next.js có gì mới | SEO/Dev | 1 giờ |

**Quan trọng:** nhịp hàng tháng phải có **người và ngày cụ thể**. Audit "khi nào rảnh" sẽ không bao giờ xảy ra.

---

## 18.7. Tài liệu sống

Phải tồn tại và được cập nhật. Nếu không, kiến thức nằm trong đầu một người và mất khi người đó rời đi.

| Tài liệu | Nội dung | Nơi lưu | Cập nhật |
| --- | --- | --- | --- |
| **Bản đồ từ khoá** | Truy vấn → URL → site → intent | `docs/keyword-map.md` | Khi thêm trang |
| **Site config** | Thông tin mỗi site (xem `templates/site-config.md`) | `docs/site-config/` | Hàng quý |
| **Changelog SEO** | Mọi thay đổi ảnh hưởng SEO | `docs/seo-changelog.md` | Mỗi thay đổi |
| **Bảng redirect** | URL cũ → mới + ngày + lý do | `data/redirects.json` + docs | Mỗi lần |
| **Nhật ký sự cố** | Sự cố traffic, nguyên nhân, cách xử lý | `docs/incidents/` | Mỗi sự cố |
| **Danh mục schema đang dùng** | Trang nào dùng schema nào | `docs/schema-inventory.md` | Khi thêm schema |

---

## 18.8. Chống "SEO bằng niềm tin"

Ba câu cần luôn trả lời được khi đề xuất một thay đổi SEO:

| Câu hỏi | Nếu không trả lời được |
| --- | --- |
| **Bằng chứng ở đâu?** | Đây là giả thuyết, không phải vấn đề — đừng đưa vào sprint |
| **Đo bằng gì?** | Không thể biết có hiệu quả hay không |
| **Đánh đổi là gì?** | Có thể gây hại mà không biết |

Ví dụ:

| Đề xuất | Bằng chứng | Đo bằng | Đánh đổi |
| --- | --- | --- | --- |
| Sửa title 120 trang danh mục | GSC: CTR 0,8% ở nhóm này | CTR nhóm URL, 28 ngày | CTR dao động 2–4 tuần |
| Chuyển sang `force-dynamic` | Không có | — | ❌ Từ chối: TTFB tăng, LCP tụt |
| Thêm FAQ schema | Trang có FAQ thật | Rich result test, GSC Enhancements | Thấp; kỳ vọng hiển thị thấp |
| Gộp 2 site | Truy vấn chồng lấn 60% | Traffic tổng sau 90 ngày | Rủi ro migration, cần redirect 12 tháng |

---

## 18.9. Khi nào cần escalation

| Tình huống | Escalate cho ai | Trong bao lâu |
| --- | --- | --- |
| Manual action trong GSC | Chủ sở hữu + SEO lead | Ngay |
| Site bị hack / malware | DevOps + bảo mật | Ngay |
| Traffic giảm > 30% | Cả nhóm | Trong 24h |
| SSL hết hạn | DevOps | Trước 7 ngày |
| 5xx kéo dài > 1 giờ | DevOps | Ngay |
| Phát hiện link scheme / site vệ tinh | Chủ sở hữu | Ngay — đây là rủi ro pháp lý & chính sách |
| Đề xuất vi phạm chính sách Google | Từ chối, ghi lý do | — |

---

## 18.10. Checklist quy trình

- [ ] Có ticket template cho yêu cầu SEO, có tiêu chí nghiệm thu kỹ thuật
- [ ] Có PR checklist SEO trong pull request template
- [ ] CI chạy `grep-antipatterns.sh` và `check-seo.mjs`, chặn khi lỗi
- [ ] Lighthouse CI có ngưỡng và chặn PR
- [ ] Pre-commit hook chặn lỗi SEO rõ ràng
- [ ] Có nhịp hàng tuần/tháng/quý với người và ngày cụ thể
- [ ] `keyword-map.md` tồn tại và được cập nhật
- [ ] `site-config/` cho mọi site
- [ ] Changelog SEO được ghi cho mọi thay đổi
- [ ] Bảng redirect được version control
- [ ] Nhật ký sự cố được ghi lại
- [ ] Mọi đề xuất SEO có: bằng chứng, cách đo, đánh đổi
- [ ] Có danh sách escalation rõ ràng
- [ ] Kiến thức không nằm trong đầu một người
