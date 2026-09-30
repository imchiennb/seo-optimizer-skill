# 00 — Index & bản đồ chủ điểm

Điểm vào của skill. Đọc file này trước khi làm bất cứ việc gì.

---

## 1. Bảng routing — nạp tài liệu nào khi nào

| Người dùng hỏi / vấn đề | Nạp file |
| --- | --- |
| Không được index, `robots.txt`, soft 404, crawl budget, status code | [01-crawl-and-index.md](01-crawl-and-index.md) |
| SSG / ISR / SSR / CSR, `'use client'`, `force-dynamic`, PPR, Cache Components | [02-rendering-and-caching.md](02-rendering-and-caching.md) |
| Title, description, canonical, Open Graph, Twitter, viewport, `metadataBase` | [03-metadata-api.md](03-metadata-api.md) |
| `sitemap.ts`, `robots.ts`, `manifest.ts`, `opengraph-image`, RSS, `not-found` | [04-file-conventions.md](04-file-conventions.md) |
| JSON-LD, Schema.org, rich results, Product / Article / Breadcrumb | [05-structured-data.md](05-structured-data.md) |
| Slug, redirect, trailing slash, canonical, hreflang, phân trang, faceted nav | [06-url-canonical-i18n.md](06-url-canonical-i18n.md) |
| Chậm, LCP / INP / CLS, ảnh, font, JS bundle, TTFB | [07-performance-cwv.md](07-performance-cwv.md) |
| Heading, internal link, alt text, E-E-A-T, nội dung mỏng, a11y | [08-onpage-content-a11y.md](08-onpage-content-a11y.md) |
| GSC, GA4, PSI, Lighthouse CI, kiểm thử tự động, log analysis | [09-measurement-qa.md](09-measurement-qa.md) |
| Tra cứu triệu chứng lỗi, catalog anti-pattern, lệnh grep tổng hợp | [10-antipatterns.md](10-antipatterns.md) |
| Gate trước launch, nghiệm thu, audit định kỳ, định nghĩa "done" | [11-launch-checklist.md](11-launch-checklist.md) |
| Tiếng Việt, dấu, slug tiếng Việt, thị trường VN, địa danh, local SEO | [13-vietnamese-and-vn-market.md](13-vietnamese-and-vn-market.md) |
| Migration Pages→App Router, nâng version Next.js, đổi domain, đổi URL | [14-migration-and-upgrade.md](14-migration-and-upgrade.md) |
| Nhiều website, tự cạnh tranh giữa các site, gộp/tách site, chuẩn hoá | [15-multi-site.md](15-multi-site.md) |
| Sản phẩm, biến thể, hết hàng, facet, giá, product feed, Merchant Center | [16-ecommerce.md](16-ecommerce.md) |
| Traffic đang giảm, cần chẩn đoán theo timeline | [17-debug-traffic-drop.md](17-debug-traffic-drop.md) |
| Ticket, PR review, CI guardrail, nhịp làm việc, tài liệu sống | [18-team-process.md](18-team-process.md) |

**Tra cứu nhanh theo triệu chứng:** [10-antipatterns.md](10-antipatterns.md) §bảng tra · [17-debug-traffic-drop.md](17-debug-traffic-drop.md) §cây quyết định.

> **Về đánh số:** số `12` được để trống có chủ đích. Tài liệu 12 trong bản gốc là ghi chú về cách đóng gói skill — không phải nội dung dùng khi hành nghề, nên không phát hành kèm. Các số còn lại giữ nguyên để không phá liên kết giữa các tài liệu.

---

## 2. Bản đồ 5 tầng

```
                    ┌─────────────────────────────┐
                    │  GOOGLE CÓ INDEX ĐƯỢC KHÔNG? │
                    └──────────────┬──────────────┘
            robots.txt ── meta robots ── X-Robots-Tag ── status code ── trùng lặp
                                   │
                    ┌──────────────▼──────────────┐
                    │  GOOGLE ĐỌC ĐƯỢC NỘI DUNG?  │
                    └──────────────┬──────────────┘
      render phía server ── <a href> thật ── không phụ thuộc JS ── không chặn JS trong robots
                                   │
                    ┌──────────────▼──────────────┐
                    │  GOOGLE HIỂU TRANG LÀ GÌ?   │
                    └──────────────┬──────────────┘
     title ── description ── heading ── URL ── canonical ── hreflang ── JSON-LD ── internal link
                                   │
                    ┌──────────────▼──────────────┐
                    │     TRANG CÓ ĐÁNG XẾP HẠNG? │
                    └──────────────┬──────────────┘
          chất lượng & độc đáo ── intent khớp ── E-E-A-T ── trải nghiệm trang
                                   │
                    ┌──────────────▼──────────────┐
                    │     TRẢI NGHIỆM CÓ TỐT?     │
                    └──────────────┬──────────────┘
              LCP ── INP ── CLS ── mobile-first ── HTTPS ── a11y ── không interstitial
```

Năm tầng này là **thứ tự ưu tiên sửa lỗi**. Tối ưu tầng 5 khi tầng 1 đang hỏng là vô nghĩa.

---

## 3. Nguyên tắc gốc

1. **HTML thô trên server là nguồn sự thật.** Mọi thứ quan trọng (nội dung, link, metadata, JSON-LD) phải có trong response HTML đầu tiên, không phải sau hydration.
2. **Một URL = một nội dung = một canonical.** Không có ngoại lệ.
3. **Metadata là dữ liệu, không phải trang trí.** Title/description/canonical phải sinh từ dữ liệu thật của trang, không hard-code hàng loạt.
4. **Đừng chặn Googlebot bằng JS.** Không `noindex` qua client component, không phụ thuộc `useEffect` để render nội dung chính.
5. **Tốc độ là hệ quả của kiến trúc, không phải của thư viện.** Ít JS gửi xuống client quan trọng hơn mọi thủ thuật khác.
6. **Đo trước, sửa sau, đo lại.** Mọi thay đổi SEO phải có bằng chứng trước/sau.
7. **Không có "SEO trick" trong tài liệu này.** Chỉ có quy tắc kỹ thuật đúng/sai và các đánh đổi.

---

## 4. Templates & scripts

| Đường dẫn | Dùng để |
| --- | --- |
| `templates/site-config.md` | Điền **một bản cho mỗi website** — nguồn sự thật duy nhất về site đó |
| `templates/audit-report.md` | Mẫu báo cáo audit thống nhất, có baseline để đo lại sau ≥ 28 ngày |
| `scripts/detect-project.sh` | Nhận diện router / Next version / cấu hình của một dự án |
| `scripts/grep-antipatterns.sh` | Quét 20 dấu hiệu rủi ro SEO trong codebase |
| `scripts/check-seo.mjs` | Kiểm tra HTML đã build; exit 1 nếu có lỗi chặn deploy |
| `scripts/audit-url.sh` | Kiểm tra HTML thô của URL production |

> ⚠️ **Mọi đường dẫn `scripts/...` và `templates/...` trong bộ tài liệu này tính từ thư mục skill (`<SKILL_DIR>`), KHÔNG phải từ thư mục dự án.** Khi chạy trên dự án người dùng, dùng đường dẫn tuyệt đối tới `<SKILL_DIR>`:
>
> ```bash
> bash <SKILL_DIR>/scripts/detect-project.sh /path/to/project
> node <SKILL_DIR>/scripts/check-seo.mjs .next/server/app --site=https://example.com
> ```
>
> Cả 4 script đều nhận thư mục/URL làm tham số nên chạy được từ bất kỳ cwd nào.

---

## 5. Nguồn chính thức nên đối chiếu định kỳ

| Nguồn | Dùng để kiểm tra |
| --- | --- |
| [Next.js — Metadata & OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images) | Cú pháp Metadata API hiện hành |
| [Next.js — `generateMetadata`](https://nextjs.org/docs/app/api-reference/functions/generate-metadata) | Toàn bộ field metadata, merge behavior |
| [Next.js — JSON-LD guide](https://nextjs.org/docs/app/guides/json-ld) | Cách chèn JSON-LD đúng |
| [Next.js — Production checklist](https://nextjs.org/docs/app/guides/production-checklist) | Checklist chính thức trước deploy |
| [Next.js 16 release](https://nextjs.org/blog/next-16) | Cache Components, `proxy.ts`, breaking changes |
| [Next.js — Pages Router docs](https://nextjs.org/docs/pages) | Xác nhận Pages Router còn được hỗ trợ |
| [Google Search Essentials](https://developers.google.com/search/docs/essentials) | Yêu cầu tối thiểu để được index/xếp hạng |
| [Google — JavaScript SEO](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics) | Cách Google xử lý JS |
| [Google — Crawl budget](https://developers.google.com/crawling/docs/crawl-budget) | Quản lý crawl budget |
| [Schema.org](https://schema.org/) · [Google structured data](https://developers.google.com/search/docs/appearance/structured-data) | Loại schema còn được hỗ trợ |
| [Statcounter — VN search share](https://gs.statcounter.com/search-engine-market-share/all/viet-nam) | Thị phần công cụ tìm kiếm tại Việt Nam |

**Cảnh báo:** tài liệu SEO trên internet có tỷ lệ thông tin sai/lỗi thời rất cao. Khi mâu thuẫn, luôn tin docs chính thức của Next.js và Google hơn bài blog.

---

## 6. Nhắc theo phiên bản Next.js

| Version | Điểm cần nhớ |
| --- | --- |
| `[13]` | App Router ra đời; Pages Router vẫn dùng `next/head` |
| `[14]` | `viewport` / `themeColor` tách khỏi `metadata` |
| `[15]` | `params` / `searchParams` thành **Promise** (phải `await`); `fetch` không cache mặc định; Route Handler GET không cache mặc định |
| `[16]` | `middleware.ts` → `proxy.ts`; `experimental.ppr` bị bỏ, thay bằng `cacheComponents`; Turbopack mặc định; React 19; `next/image` đổi một số mặc định |

**Pages Router vẫn được hỗ trợ đầy đủ trong Next.js 16.x.** Migration sang App Router là lựa chọn chiến lược, không phải bắt buộc kỹ thuật, và **không mang lại lợi ích xếp hạng trực tiếp**.
