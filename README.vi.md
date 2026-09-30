# seo-optimizer (Tiếng Việt)

> Skill cho agent để **audit và tối ưu SEO kỹ thuật cho bất kỳ dự án Next.js nào** — App Router, Pages Router, hoặc hybrid; bất kỳ phiên bản nào từ 13 đến 16.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Next.js](https://img.shields.io/badge/Next.js-13%20%E2%86%92%2016-black)](https://nextjs.org)

**Nguyên tắc chỉ đạo: HTML thô trên server là nguồn sự thật.** Mọi kết luận phải có bằng chứng từ `curl`, script, hoặc số liệu thực — không bao giờ từ việc đọc code rồi suy đoán.

> 📖 [English README](README.md)

---

## Vì sao có skill này

Phần lớn hướng dẫn SEO được viết cho thời WordPress — site render phía server, HTML tĩnh. Next.js phá vỡ những giả định đó theo những cách rất cụ thể, và các checklist chung bỏ sót toàn bộ.

**Điểm khác biệt:**

- **Bằng chứng là bắt buộc.** Skill bị cấm tuyên bố "đã sửa xong" mà không dán output lệnh chứng minh.
- **Nhận biết phiên bản.** `[14]` tách `viewport` khỏi `metadata`. `[15]` biến `params` thành Promise. `[16]` đổi `middleware.ts` → `proxy.ts` và thay `experimental.ppr` bằng `cacheComponents`. Skill biết luật nào áp dụng cho dự án của bạn.
- **Nhận biết router.** Tự nhận diện App Router / Pages Router / hybrid trước khi làm gì, và **không** ép dự án Pages Router phải migrate.
- **Chạy được, không chỉ là văn xuôi.** Bốn script làm phần kiểm tra; tài liệu giải thích lý do.
- **Đính chính thông tin sai phổ biến.** Xem [phần dưới](#một-đính-chính-đáng-nói).

---

## Cài đặt

Skill là Markdown thuần cộng script shell/Node — không build, không dependency.

```bash
git clone git@github.com:imchiennb/seo-optimizer-skill.git ~/.dsh/skills/seo-optimizer
```

Đổi đường dẫn đích theo agent bạn dùng:

| Agent host | Thư mục skill |
| --- | --- |
| DSH | `~/.dsh/skills/` |
| Claude Code | `~/.claude/skills/` |
| Khác | nơi agent của bạn nạp skill |

Kiểm tra:

```bash
bash ~/.dsh/skills/seo-optimizer/scripts/self-test.sh
```

Vì tất cả là Markdown, bạn cũng có thể dùng với bất kỳ LLM nào đọc được file — đưa `SKILL.md`, rồi đưa các file `references/*.md` liên quan.

---

## Cách dùng

### Với agent

Chỉ cần hỏi về SEO trên dự án Next.js, skill được chọn tự động:

> "Audit SEO kỹ thuật của app Next.js này."
> "Traffic organic tuần trước giảm 30% — chẩn đoán giúp."
> "Sao trang sản phẩm không được Google index?"

### Chạy tay

```bash
SKILL=~/.dsh/skills/seo-optimizer

# 1. Dự án này là loại Next.js gì?
bash $SKILL/scripts/detect-project.sh /đường/dẫn/dự/án

# 2. Quét dấu hiệu rủi ro SEO trong codebase
bash $SKILL/scripts/grep-antipatterns.sh /đường/dẫn/dự/án/app

# 3. Kiểm tra HTML đã build (chạy sau `npm run build`)
node $SKILL/scripts/check-seo.mjs .next/server/app --site=https://example.com

# 4. Kiểm tra HTML thô của production — thứ Googlebot thực sự nhận
bash $SKILL/scripts/audit-url.sh https://example.com / /bang-gia /lien-he
```

`check-seo.mjs` trả **exit code 1** khi có lỗi chặn deploy → dùng trực tiếp trong CI.

---

## Nội dung

### References — 18 tài liệu, ~5.700 dòng

| # | Tài liệu | Nội dung |
| --- | --- | --- |
| 00 | [Index & routing](references/00-index.md) | **Đọc trước** — bảng routing và mô hình 5 tầng |
| 01 | [Crawl & index](references/01-crawl-and-index.md) | Googlebot, robots.txt vs meta robots, crawl budget, status code, soft 404 |
| 02 | [Rendering & caching](references/02-rendering-and-caching.md) | SSG/ISR/SSR/CSR, PPR, Cache Components, server vs client component |
| 03 | [Metadata API](references/03-metadata-api.md) | title template, canonical, Open Graph, Twitter, viewport |
| 04 | [File conventions](references/04-file-conventions.md) | `sitemap.ts`, `robots.ts`, `manifest.ts`, `opengraph-image`, RSS, 404 |
| 05 | [Structured data](references/05-structured-data.md) | JSON-LD theo loại trang, `@graph`, breadcrumb, loại đã ngừng hỗ trợ |
| 06 | [URL, canonical, i18n](references/06-url-canonical-i18n.md) | slug, redirect, trailing slash, hreflang, phân trang, faceted nav |
| 07 | [Hiệu năng & CWV](references/07-performance-cwv.md) | `next/image`, `next/font`, `next/script`, bundle, LCP/INP/CLS, TTFB |
| 08 | [On-page, nội dung, a11y](references/08-onpage-content-a11y.md) | semantic, heading, internal link, alt, E-E-A-T |
| 09 | [Đo lường & QA](references/09-measurement-qa.md) | GSC, GA4, PSI, Lighthouse CI, log analysis, cảnh báo |
| 10 | [Antipatterns](references/10-antipatterns.md) | 27 lỗi đặc thù Next.js: triệu chứng → nguyên nhân → cách sửa → cách phát hiện |
| 11 | [Checklist triển khai](references/11-launch-checklist.md) | gate trước launch, sau launch, định kỳ |
| 13 | [Tiếng Việt & thị trường VN](references/13-vietnamese-and-vn-market.md) | dấu, NFC/NFD, đo title bằng pixel, local SEO, thị phần tìm kiếm |
| 14 | [Migration & nâng cấp](references/14-migration-and-upgrade.md) | ánh xạ Pages → App Router, nâng version, đổi domain |
| 15 | [Nhiều website](references/15-multi-site.md) | tự cạnh tranh giữa các site, gộp site, chuẩn hoá công cụ |
| 16 | [Thương mại điện tử](references/16-ecommerce.md) | biến thể, hết hàng, facet, schema giá, product feed |
| 17 | [Debug traffic tụt](references/17-debug-traffic-drop.md) | cây quyết định theo timeline, 4 kiểu "tụt" khác nhau |
| 18 | [Quy trình team](references/18-team-process.md) | ticket, PR review, CI guardrail, nhịp làm việc |

### Templates

| File | Dùng để |
| --- | --- |
| [`templates/site-config.md`](templates/site-config.md) | Điền **một bản cho mỗi site** — nguồn sự thật duy nhất |
| [`templates/audit-report.md`](templates/audit-report.md) | Báo cáo audit thống nhất, có baseline đo lại được |

### Scripts

| File | Việc nó làm |
| --- | --- |
| [`scripts/detect-project.sh`](scripts/detect-project.sh) | Nhận diện router, Next version, cấu hình, số route, hạ tầng SEO |
| [`scripts/grep-antipatterns.sh`](scripts/grep-antipatterns.sh) | Quét 20 dấu hiệu rủi ro SEO trong codebase |
| [`scripts/check-seo.mjs`](scripts/check-seo.mjs) | Kiểm tra HTML đã build; exit 1 nếu có lỗi chặn deploy |
| [`scripts/audit-url.sh`](scripts/audit-url.sh) | Kiểm tra HTML thô, header, redirect chain của production |
| [`scripts/self-test.sh`](scripts/self-test.sh) | Kiểm tra tính toàn vẹn của chính repo này |

---

## Mô hình 5 tầng

Thứ tự ưu tiên sửa lỗi. Tối ưu tầng 5 khi tầng 1 đang hỏng là vô nghĩa.

| Tầng | Câu hỏi | Reference |
| --- | --- | --- |
| **1** | Google có index được không? | 01 |
| **2** | Google có đọc được nội dung không? | 02 |
| **3** | Google có hiểu trang là gì không? | 03, 04, 05, 06 |
| **4** | Trang có đáng xếp hạng không? | 08 |
| **5** | Trải nghiệm có tốt không? | 07 |

---

## Những gì skill từ chối đề xuất

meta keywords · `rel=next/prev` · `noindex` trang phân trang · canonical trang 2 trỏ về trang 1 · `priority` cho mọi ảnh · `force-dynamic` toàn site · `'use client'` cho cả trang · nhồi schema để săn rich result · `FAQPage`/`HowTo` · xoá URL sản phẩm hết hàng · cross-domain canonical mà không nêu đánh đổi · khẳng định đã sửa khi chưa verify.

---

## Một đính chính đáng nói

Một thông tin được lặp lại rộng rãi: *"Next.js 16 đã xoá Pages Router."* **Điều này sai.** Pages Router vẫn được hỗ trợ đầy đủ trong Next.js 16.x — docs chính thức vẫn duy trì nguyên một nhánh `/docs/pages`.

Hệ quả thực tế: migration Pages → App Router **không mang lại lợi ích xếp hạng trực tiếp**. Nó mở khoá tính năng mới của framework, và chỉ có vậy.

---

## Ngôn ngữ

- Tài liệu cấp cao nhất (`README`, `CONTRIBUTING.md`, `SKILL.md`) bằng **tiếng Anh**.
- 18 tài liệu reference bằng **tiếng Việt**.

File `13-vietnamese-and-vn-market.md` được viết riêng cho tiếng Việt và chứa nội dung không có tương đương tiếng Anh: `đ` không tách được bằng Unicode NFD, lệch chuỗi NFC/NFD làm hỏng slug, và đo độ dài title bằng pixel thay vì ký tự.

Hoan nghênh bản dịch — xem [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Yêu cầu

| Thành phần | Yêu cầu |
| --- | --- |
| Script shell | Bash 4+, `curl` |
| `check-seo.mjs` | Node.js 18+ (không cần npm package) |
| `detect-project.sh` | Node.js để đọc `package.json` |
| Agent host | Bất kỳ host nào nạp được skill Markdown |

Không có thư viện bên thứ ba. Không cài gì vào dự án của bạn.

---

## Độ chính xác

Nội dung được đối chiếu với docs chính thức của Next.js (nhánh 16.x) và Google Search Central. Tài liệu SEO trên internet có tỷ lệ sai/lỗi thời rất cao, nên khi blog mâu thuẫn với docs chính thức thì docs thắng — và repo này nói thẳng điều đó.

Phát hiện sai sót? Mở issue kèm link tới nguồn chính thức. Đó là đường nhanh nhất để được merge.

---

## Giấy phép

[MIT](LICENSE) © 2026 imchiennb

Không liên kết, không được bảo trợ bởi Vercel hay Google. Next.js là thương hiệu của Vercel, Inc.
