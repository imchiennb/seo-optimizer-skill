# Site config — `<tên site>`

> Điền một bản cho **mỗi** website. Cập nhật hàng quý.
> Đây là nguồn sự thật duy nhất về site. Nếu không có file này, mọi quyết định SEO đều dựa trên trí nhớ.

---

## 1. Định danh

| Trường | Giá trị |
| --- | --- |
| Tên site | |
| Domain chính | `https://` |
| Domain phụ / redirect | |
| Repo | |
| Môi trường production | (Vercel / self-host / CDN) |
| Owner | |
| Ngày tạo file | |
| Ngày cập nhật gần nhất | |

## 2. Mục đích & đối tượng

| Trường | Giá trị |
| --- | --- |
| Mục đích kinh doanh | (bán hàng / lead gen / nhận diện / hỗ trợ) |
| Loại site | ecommerce / SaaS / content / local / catalog / docs |
| Đối tượng chính | |
| Khu vực địa lý | |
| Ngôn ngữ | |
| Chuyển đổi chính | (mua / đăng ký / liên hệ / tải) |

## 3. Từ khoá sở hữu

> **Quy tắc: một từ khoá chính chỉ thuộc MỘT site.** Nếu trùng với site khác, ghi rõ ai thắng.

| Từ khoá chính | URL đích | Intent | Volume ước tính | Site khác có target? |
| --- | --- | --- | --- | --- |
| | | | | không / tên site (site này thắng) |
| | | | | |
| | | | | |

**Từ đồng nghĩa / cách gọi khác trong ngành:**
- (ví dụ: máy lạnh = máy điều hòa = điều hòa nhiệt độ)

**Từ khoá KHÔNG target** (thuộc site khác hoặc ngoài phạm vi):
-

## 4. Kỹ thuật

| Trường | Giá trị |
| --- | --- |
| Next.js version | |
| Router | App Router / Pages Router |
| `cacheComponents` | bật / tắt |
| `trailingSlash` | `false` / `true` |
| Chiến lược render mặc định | SSG / ISR / SSR / hỗn hợp |
| Hosting / CDN | |
| `NEXT_PUBLIC_SITE_URL` | |
| Có i18n? | không / danh sách locale |
| Có static export? | không / có |
| Có CMS? | không / tên |
| Webhook revalidate | có / không |

## 5. Cấu trúc URL

| Loại trang | Pattern | Index? | Render |
| --- | --- | --- | --- |
| Trang chủ | `/` | ✅ | |
| Danh mục | `/danh-muc/[slug]` | ✅ | |
| Chi tiết | `/san-pham/[slug]` | ✅ | |
| Bài viết | `/bai-viet/[slug]` | ✅ | |
| Phân trang | `?page=N` | ✅ | |
| Search nội bộ | `/tim-kiem?q=` | ❌ | |
| Giỏ hàng | `/gio-hang` | ❌ | |
| Tài khoản | `/tai-khoan/*` | ❌ | |

## 6. Structured data đang dùng

| Loại schema | Trang áp dụng | Đã kiểm tra Rich Results Test? |
| --- | --- | --- |
| `Organization` | layout gốc | |
| `WebSite` | layout gốc | |
| `BreadcrumbList` | | |
| `Product` + `Offer` | | |
| `BlogPosting` | | |
| `LocalBusiness` | | |

## 7. Đo lường

| Trường | Giá trị |
| --- | --- |
| GSC property | |
| GA4 property ID | |
| Bing Webmaster Tools | đã xác minh? |
| IndexNow | bật? key? |
| Thu thập CWV trường | endpoint? |
| Dashboard / báo cáo | |

## 8. Kênh ngoài site (cho `sameAs`)

| Kênh | URL |
| --- | --- |
| Facebook | |
| Zalo OA | |
| YouTube | |
| TikTok | |
| LinkedIn | |
| Google Business Profile | |

## 9. Trạng thái & lịch sử

| Mốc | Ngày | Kết quả |
| --- | --- | --- |
| Audit gần nhất | | (điểm / số lỗi) |
| Nâng cấp Next.js gần nhất | | |
| Migration gần nhất | | |
| Sự cố gần nhất | | |

## 10. Baseline hiệu suất

| Chỉ số | Giá trị | Ngày đo | Nguồn |
| --- | --- | --- | --- |
| Clicks / 28 ngày | | | GSC |
| Impressions / 28 ngày | | | GSC |
| CTR | | | GSC |
| Position trung bình | | | GSC |
| Số URL được index | | | GSC |
| LCP p75 (mobile) | | | CrUX |
| INP p75 (mobile) | | | CrUX |
| CLS p75 (mobile) | | | CrUX |
| Số URL trong sitemap | | | sitemap.xml |

## 11. Rủi ro & ghi chú

| Rủi ro | Mức độ | Ghi chú |
| --- | --- | --- |
| (ví dụ: chưa có redirect cho URL cũ) | | |
| | | |

## 12. Việc cần làm tiếp

- [ ]
- [ ]
