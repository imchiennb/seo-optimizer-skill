# Báo cáo audit SEO — `<domain>`

| | |
| --- | --- |
| **Site** | |
| **Ngày audit** | |
| **Người thực hiện** | |
| **Phạm vi** | toàn site / một nhóm route / một trang |
| **Next.js version** | |
| **Router** | App Router / Pages Router |
| **Công cụ đã dùng** | `curl`, `check-seo.mjs`, GSC, PSI, Rich Results Test |

---

## 0. Tóm tắt điều hành

> 3–5 câu. Người đọc chỉ đọc phần này vẫn hiểu tình hình.

**Kết luận:** 🔴 có lỗi chặn index · 🟡 có vấn đề cần sửa · 🟢 khỏe mạnh

**Ba vấn đề nghiêm trọng nhất:**

1.
2.
3.

**Việc cần làm ngay:**

| # | Việc | Mức độ | Ước lượng |
| --- | --- | --- | --- |
| 1 | | 🔴 | |
| 2 | | 🟡 | |

---

## 1. Tầng 1 — Crawl & Index

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| `robots.txt` hợp lệ, không chặn asset | | |
| Không có `Disallow: /` ngoài non-prod | | |
| `sitemap.xml` tồn tại, chỉ chứa URL canonical 200 | | |
| Sitemap khai báo trong `robots.txt` | | |
| Không có `noindex` rò rỉ | | |
| Trang không tồn tại trả 404/410 | | |
| Không có redirect chain > 1 | | |
| HTTP→HTTPS, www↔non-www đã chốt | | |
| `dynamicParams = false` ở route động hữu hạn | | |

**Lỗi phát hiện:**

```
(dán output lệnh)
```

## 2. Tầng 2 — Rendering

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Nội dung chính có trong HTML thô | | `curl \| wc -c` = |
| Điều hướng dùng `<a href>` | | số `<a href>` = |
| `'use client'` không ở page/layout | | |
| `params`/`searchParams` được `await` | | |
| Không có `force-dynamic` tràn lan | | |
| `generateMetadata` dùng `cache()` dedupe | | |
| Chiến lược render phù hợp từng loại trang | | |

## 3. Tầng 3 — Metadata & cấu trúc

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| `metadataBase` ở layout gốc | | |
| `title.template` + `title.default` | | |
| Title riêng, không trùng, ≤ 58 ký tự | | số title trùng = |
| Description riêng, 140–155 ký tự | | số desc trùng = |
| Canonical tuyệt đối, HTTPS, đúng domain | | |
| `og:image` mọi mẫu trang, 1200×630 | | |
| `og:title`, `twitter:card` | | |
| `viewport` export riêng | | |
| `robots.googleBot['max-image-preview']='large'` | | |
| Đúng một `<h1>` mỗi trang | | |
| `<html lang>` đúng | | |
| JSON-LD: `Organization`, `WebSite`, `BreadcrumbList` | | |
| JSON-LD: schema theo loại trang | | |
| JSON-LD escape `<`, không double-stringify | | |
| Hreflang đối xứng + `x-default` (nếu i18n) | | |

## 4. Tầng 4 — Nội dung

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Mỗi trang có một chủ đề rõ | | |
| Không có trang mỏng đang index | | |
| Không có cannibalization | | |
| Internal link đủ (không trang mồ côi) | | |
| Anchor text mô tả | | |
| Ảnh có `alt` mô tả | | số `<img>` thiếu alt = |
| Có tác giả + ngày cập nhật | | |
| E-E-A-T: trang giới thiệu, liên hệ | | |
| Không có nội dung copy giữa các site | | |

## 5. Tầng 5 — Hiệu năng & trải nghiệm

| Chỉ số | Giá trị | Ngưỡng | Kết quả |
| --- | --- | --- | --- |
| LCP (p75 mobile) | | ≤ 2.5s | |
| INP (p75 mobile) | | ≤ 200ms | |
| CLS (p75 mobile) | | ≤ 0.1 | |
| TTFB | | ≤ 0.8s | |
| Lighthouse Performance | | ≥ 90 | |
| Lighthouse SEO | | ≥ 95 | |
| Lighthouse Accessibility | | ≥ 90 | |
| JS tải lần đầu | | ≤ 150KB gzip | |
| Số ảnh `priority` mỗi trang | | = 1 | |
| Font subset `vietnamese` | | ✅ | |
| Third-party script strategy | | | |

---

## 6. Chi tiết lỗi

> Mỗi lỗi: mô tả · mức độ · bằng chứng · URL/file · cách sửa · tiêu chí nghiệm thu

### 6.1. `<tiêu đề lỗi>`

| Trường | Nội dung |
| --- | --- |
| **Mức độ** | 🔴 chặn index / 🟡 nên sửa / 🟢 cải thiện |
| **Bằng chứng** | |
| **URL bị ảnh hưởng** | |
| **File liên quan** | |
| **Nguyên nhân** | |
| **Cách sửa** | |
| **Tiêu chí nghiệm thu** | |
| **Ước lượng** | |

```bash
# Lệnh kiểm chứng sau khi sửa
```

### 6.2. `<tiêu đề lỗi>`

(lặp lại)

---

## 7. Điểm số & xu hướng

| Nhóm | Điểm | So với kỳ trước |
| --- | --- | --- |
| Crawl & Index | /10 | |
| Rendering | /10 | |
| Metadata & cấu trúc | /10 | |
| Nội dung | /10 | |
| Hiệu năng | /10 | |
| **Tổng** | | |

---

## 8. Kế hoạch hành động

| # | Việc | Mức độ | Người làm | Thời hạn | Trạng thái |
| --- | --- | --- | --- | --- | --- |
| 1 | | 🔴 | | | |
| 2 | | 🟡 | | | |
| 3 | | 🟢 | | | |

---

## 9. Baseline để đo lại

| Chỉ số | Giá trị hiện tại | Ngày đo lại |
| --- | --- | --- |
| Clicks / 28 ngày | | |
| Impressions / 28 ngày | | |
| CTR | | |
| Position trung bình | | |
| Số URL index | | |

> Đo lại sau **≥ 28 ngày**. Ghi lại kết quả vào `seo-changelog.md`.

---

## 10. Ghi chú & giới hạn của audit

- Những gì **chưa** kiểm tra được (ví dụ: cần quyền GSC, cần truy cập log, cần thiết bị thật):
- Giả định đã dùng:
- Nguồn dữ liệu:
