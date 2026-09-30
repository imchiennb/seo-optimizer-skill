# 15 — Quản trị nhiều website

Dành cho trường hợp bạn sở hữu **nhiều site** — đây là bài toán khác về bản chất so với tối ưu một site.

---

## 15.1. Vấn đề cốt lõi

Khi một chủ sở hữu có nhiều domain, ba rủi ro xuất hiện mà tối ưu từng site riêng lẻ không giải quyết được:

| Rủi ro | Biểu hiện |
| --- | --- |
| **Tự cạnh tranh** (self-cannibalization across domains) | Hai site của bạn thay nhau xuất hiện cho cùng truy vấn, không site nào lên top |
| **Trùng lặp nội dung giữa các site** | Google chọn một bản, bản còn lại bị lọc khỏi kết quả |
| **Tín hiệu phân tán** | Backlink, brand search, thẩm quyền bị chia cho nhiều domain yếu thay vì gom về một domain mạnh |
| **Không biết site nào đang hỏng** | Không có cái nhìn tổng thể, sửa site này bỏ quên site kia |

---

## 15.2. Danh mục site — bắt buộc phải có

Trước khi tối ưu, phải có **một tài liệu duy nhất** mô tả mọi site. Dùng `templates/site-config.md`.

Tối thiểu mỗi site cần ghi:

| Trường | Vì sao cần |
| --- | --- |
| Domain | Định danh |
| Mục đích kinh doanh | Quyết định ưu tiên |
| Đối tượng | Tránh chồng lấn |
| **Từ khoá sở hữu** | Chống tự cạnh tranh |
| Loại site (ecommerce / SaaS / content / local / catalog) | Quyết định chiến lược |
| Next.js version + Router | Lên kế hoạch nâng cấp |
| Chiến lược render chính | Kiểm tra tính nhất quán |
| Ngôn ngữ / thị trường | i18n |
| Owner (người/team) | Trách nhiệm |
| Ngày audit gần nhất + điểm | Theo dõi |
| Repo | Chạy script tự động |
| GSC property | Đo lường |

---

## 15.3. Phân bổ từ khoá — quy tắc một chủ

> **Một từ khoá chính chỉ thuộc MỘT site.**

Đây là quy tắc quan trọng nhất của multi-site. Vi phạm nó tạo ra tự cạnh tranh.

### Ma trận phân bổ

| Từ khoá | Site sở hữu | Site không được target | Ghi chú |
| --- | --- | --- | --- |
| `dịch vụ seo tổng thể` | siteA.com | siteB.com | siteB chỉ làm dịch vụ quảng cáo |
| `mua máy nén khí` | shopB.com | siteA.com | siteA là blog kiến thức |
| `hướng dẫn bảo trì máy nén khí` | siteA.com | shopB.com | Nội dung thông tin thuộc blog |

Cách làm:
1. Xuất toàn bộ truy vấn từ GSC của **từng** site (16 tháng gần nhất).
2. Tìm truy vấn xuất hiện ở **≥ 2 site** của bạn → đây là danh sách chồng lấn.
3. Với mỗi truy vấn chồng lấn: chọn site thắng, và ở site còn lại thì **gỡ mục tiêu** — sửa nội dung, `noindex`, hoặc chuyển hướng người đọc sang site thắng.

```bash
# Xuất truy vấn từ GSC (qua Search Console API hoặc export CSV)
# rồi tìm trùng giữa các site
awk -F'\t' 'NR>1 {print $1}' siteA-queries.tsv | sort > /tmp/a.txt
awk -F'\t' 'NR>1 {print $1}' siteB-queries.tsv | sort > /tmp/b.txt
comm -12 /tmp/a.txt /tmp/b.txt    # truy vấn xuất hiện ở cả hai site
```

---

## 15.4. Chống trùng lặp nội dung giữa các site

### Bảng quyết định

| Tình huống | Chiến lược đúng |
| --- | --- |
| Cùng sản phẩm, hai site khác thương hiệu | Viết **nội dung gốc khác nhau** cho mỗi site (mô tả, ảnh, FAQ, thông số riêng) |
| Cùng sản phẩm, một site là "site chính" | Site phụ `canonical` cross-domain về site chính — **chấp nhận mất traffic ở site phụ** |
| Blog chia sẻ bài giữa các site | Chỉ **một** site index bản gốc; site còn lại `noindex` hoặc viết lại |
| Nội dung syndicate ra báo/Medium/LinkedIn | Trang gốc có canonical tự thân; bản syndicate phải trỏ canonical về bạn (yêu cầu đối tác) |
| Trang liên hệ/giới thiệu/chính sách | Có thể giống nhau — đây là ngoại lệ được chấp nhận |

### Về cross-domain canonical

```tsx
// Trên site phụ, trỏ về site chính
export const metadata: Metadata = {
  alternates: { canonical: 'https://sitechinh.com/san-pham/abc' },
}
```

**Đánh đổi phải hiểu rõ:**

| Được | Mất |
| --- | --- |
| Không bị coi là trùng lặp | Site phụ **không** được index cho nội dung đó |
| Tín hiệu gom về site chính | Site phụ mất khả năng xếp hạng |
| Đơn giản, nhanh | Không thể đo traffic organic của site phụ cho trang đó |

Nếu mục tiêu của site phụ là tự có traffic, **canonical cross-domain là sai**. Khi đó phải viết nội dung khác.

### Cảnh báo: site vệ tinh và link scheme

Nếu nhiều site tồn tại **chủ yếu để link cho nhau**, đây là vi phạm chính sách của Google (link scheme). Hậu quả có thể là manual action trên toàn bộ nhóm site.

Dấu hiệu bị coi là link scheme:
- Nhiều site cùng template, cùng nội dung gần giống
- Link qua lại với anchor text thương mại
- Site "vệ tinh" không có traffic tự nhiên, không có nội dung gốc
- Đăng ký cùng một người, cùng hosting, cùng dải IP, cùng Analytics ID

**Nếu bạn đang có cấu trúc này: đó không phải vấn đề kỹ thuật cần tối ưu, mà là rủi ro cần loại bỏ.**

---

## 15.5. Khi nào gộp site, khi nào tách

### Nên gộp khi

- Hai site cùng đối tượng, cùng chủ đề, cùng ngôn ngữ
- Cả hai đều yếu (DR thấp, traffic thấp)
- Cùng nhắm một tập từ khoá
- Backlink bị chia nhỏ
- Bạn không đủ nguồn lực để duy trì cả hai

Gộp = cộng dồn backlink, brand signal và thẩm quyền về một domain. Với hai site yếu, gộp gần như luôn tốt hơn.

### Nên tách khi

- Thương hiệu khác biệt rõ ràng với đối tượng khác nhau
- Ngôn ngữ / thị trường địa lý khác nhau (nên dùng **thư mục con** hoặc **subdomain** thay vì domain riêng nếu cùng thương hiệu)
- Mô hình kinh doanh khác (B2B vs B2C, bán hàng vs dịch vụ)
- Yêu cầu pháp lý / thương hiệu riêng
- Một site có nguy cơ bị ảnh hưởng tiêu cực kéo site kia xuống

### Gộp site đúng cách (migration domain → domain)

1. Chọn domain đích (domain khỏe hơn, thương hiệu chính)
2. Ánh xạ **1-1** URL từ domain bị gộp sang domain đích
3. 301 vĩnh viễn, giữ ≥ 12 tháng
4. Cập nhật internal link trên domain đích trỏ về URL mới
5. GSC: Change of Address
6. Không gộp hai site có nội dung na ná nhau mà không viết lại — bạn chỉ đang dồn trùng lặp vào một chỗ
7. Giữ domain cũ đăng ký (đừng để người khác mua lại)

---

## 15.6. Cấu trúc domain: bảng quyết định

| Mô hình | Dùng khi | SEO |
| --- | --- | --- |
| Thư mục con `/vi/`, `/blog/` | Cùng thương hiệu, cùng thị trường | ✅ Tốt nhất — gom tín hiệu |
| Subdomain `blog.example.com` | Cần tách hệ thống kỹ thuật | ⚠️ Tín hiệu tách một phần, phải xác minh riêng trong GSC |
| Domain riêng | Thương hiệu khác biệt, thị trường khác | ⚠️ Phải xây từ đầu, chi phí cao |
| Multi-zone Next.js | Nhiều app Next.js, một domain | ✅ Dùng `assetPrefix` + rewrites; cẩn thận canonical |

Với hầu hết trường hợp: **giữ trên một domain, dùng thư mục con**.

---

## 15.7. Chuẩn hoá kỹ thuật giữa các site

Khi có nhiều site, chi phí bảo trì tăng theo số site. Chuẩn hoá là cách duy nhất để giữ được.

### Thư viện SEO dùng chung

```
packages/seo/
├── buildMetadata.ts     # sinh Metadata theo loại trang, đảm bảo luôn có OG image
├── JsonLd.tsx           # component JSON-LD có escape
├── slugify.ts           # xử lý đúng tiếng Việt
├── breadcrumb.ts
└── index.ts
```

```ts
// buildMetadata — tập trung hoá để không site nào quên og:image
import type { Metadata } from 'next'

type SiteConfig = {
  name: string
  url: string
  defaultOgImage: string
  twitter?: string
  locale?: string
}

export function buildMetadata(
  site: SiteConfig,
  page: {
    title: string
    description: string
    path: string
    ogImage?: string
    type?: 'website' | 'article'
    noindex?: boolean
    languages?: Record<string, string>
  },
): Metadata {
  const url = new URL(page.path, site.url).toString()
  return {
    metadataBase: new URL(site.url),
    title: page.title,
    description: page.description,
    alternates: { canonical: page.path, languages: page.languages },
    robots: page.noindex ? { index: false, follow: true } : undefined,
    openGraph: {
      type: page.type ?? 'website',
      url,
      title: page.title,
      description: page.description,
      siteName: site.name,
      locale: site.locale ?? 'vi_VN',
      // Luôn có ảnh — chống bẫy merge nông
      images: [{ url: page.ogImage ?? site.defaultOgImage, width: 1200, height: 630, alt: page.title }],
    },
    twitter: {
      card: 'summary_large_image',
      site: site.twitter,
      title: page.title,
      description: page.description,
      images: [page.ogImage ?? site.defaultOgImage],
    },
  }
}
```

### Cấu hình site tập trung

```ts
// sites.ts — nguồn sự thật duy nhất cho mọi site
export const sites = {
  main: {
    name: 'Thương hiệu A',
    url: process.env.NEXT_PUBLIC_SITE_URL!,
    defaultOgImage: '/og/default.png',
    locale: 'vi_VN',
    twitter: '@thuonghieuA',
  },
} as const

export const site = sites.main
```

### Script chạy cho mọi repo

```bash
#!/usr/bin/env bash
# audit-all-sites.sh — chạy kiểm tra cho toàn bộ danh mục
set -uo pipefail

repos=(
  "$HOME/works/site-a"
  "$HOME/works/site-b"
  "$HOME/works/site-c"
)

for repo in "${repos[@]}"; do
  echo "══════════════════════════════════════"
  echo "SITE: $(basename "$repo")"
  echo "══════════════════════════════════════"
  ( cd "$repo" || exit
    echo "--- Next.js version ---"
    node -p "require('./package.json').dependencies.next" 2>/dev/null || echo "?"
    echo "--- Anti-pattern ---"
    bash "$HOME/works/tekla-brainstorming/docs/seo-nextjs/scripts/grep-antipatterns.sh" app 2>/dev/null | grep -E '✗|⚠|──' | head -30
    echo "--- Build check ---"
    [ -d .next/server/app ] && node "$HOME/works/tekla-brainstorming/docs/seo-nextjs/scripts/check-seo.mjs" .next/server/app 2>&1 | tail -5 || echo "chưa build"
  )
  echo
done
```

---

## 15.8. Dashboard theo dõi danh mục

| Chỉ số | Nguồn | Tần suất |
| --- | --- | --- |
| Tổng click / impression mỗi site | GSC API | Hàng tuần |
| Số URL được index mỗi site | GSC API | Hàng tuần |
| Số lỗi 5xx | Log/monitoring | Hàng ngày |
| CWV p75 mỗi site | CrUX API / `useReportWebVitals` | Hàng tuần |
| Uptime | Monitoring | Liên tục |
| Chứng chỉ SSL hết hạn | Monitoring | Hàng tuần |
| Version Next.js mỗi site | `package.json` | Hàng tháng |
| Truy vấn chồng lấn giữa các site | GSC API | Hàng tháng |
| Số lỗi schema | GSC API | Hàng tháng |

**Cảnh báo cần thiết lập cho cả danh mục:**
- Bất kỳ site nào trả 5xx
- SSL sắp hết hạn (< 14 ngày)
- Số URL index giảm > 20% ở bất kỳ site
- `noindex` xuất hiện trên site production
- Sitemap trả lỗi

---

## 15.9. Ưu tiên khi nguồn lực hạn chế

Với nhiều site và ít người, thứ tự đầu tư:

| Ưu tiên | Việc làm | Lý do |
| --- | --- | --- |
| 1 | Sửa site đang có traffic (không phải site mới) | ROI cao nhất |
| 2 | Đảm bảo không site nào bị lỗi chặn index | Một site hỏng = mất toàn bộ traffic site đó |
| 3 | Gộp site yếu nếu có chồng lấn | Cộng dồn thay vì chia nhỏ |
| 4 | Chuẩn hoá thư viện SEO dùng chung | Giảm chi phí bảo trì |
| 5 | Tự động hoá audit | Phát hiện sớm |
| 6 | Mở site mới | Chỉ khi 1–5 đã ổn |

> **Cảnh báo chiến lược:** mở thêm site mới khi các site hiện có đang có lỗi index cơ bản là cách phân tán nguồn lực tệ nhất. Sửa cái đang có trước.

---

## 15.10. Checklist quản trị danh mục

- [ ] Có `site-config` cho **mỗi** site, cập nhật trong 3 tháng gần nhất
- [ ] Có ma trận từ khoá → site, không có từ khoá nào thuộc 2 site
- [ ] Đã xuất truy vấn GSC 16 tháng của mọi site và tìm chồng lấn
- [ ] Mọi truy vấn chồng lấn đã được quyết định site thắng
- [ ] Không có nội dung copy giữa các site (trừ trang pháp lý/liên hệ)
- [ ] Nếu dùng cross-domain canonical: đã ghi rõ lý do và chấp nhận mất traffic
- [ ] Không có cấu trúc site vệ tinh / link scheme
- [ ] Đã đánh giá lại: có site nào nên gộp không?
- [ ] Thư viện SEO dùng chung đã tách thành package
- [ ] Mọi repo chạy `check-seo.mjs` + `grep-antipatterns.sh` trong CI
- [ ] Dashboard danh mục hoạt động, có cảnh báo
- [ ] Mọi site đã xác minh GSC (và Bing nếu cần)
- [ ] SSL + uptime được giám sát cho toàn bộ
- [ ] Version Next.js mỗi site được ghi lại, có kế hoạch nâng cấp
- [ ] Mỗi site có owner rõ ràng
