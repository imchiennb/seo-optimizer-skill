# 11 — Checklist triển khai

Dùng như **gate nghiệm thu**. Ba mức: chặn deploy (🔴), phải sửa trong sprint (🟡), cải thiện dần (🟢).

---

## 11.1. Gate A — Trước deploy lần đầu (chặn deploy)

### Crawl & index 🔴

- [ ] `robots.txt` hợp lệ, cho phép `/_next/static/`, `.js`, `.css`
- [ ] Không có `Disallow: /` ngoài môi trường non-production
- [ ] `sitemap.xml` sinh động, chỉ chứa URL canonical trả 200
- [ ] Sitemap đã khai báo trong `robots.txt`
- [ ] `noindex` không rò rỉ vào production (kiểm tra bằng `curl`)
- [ ] Trang không tồn tại trả `404` với `not-found.tsx` có `noindex`
- [ ] Staging/preview có `noindex` hoặc `X-Robots-Tag`
- [ ] HTTP → HTTPS, `www` ↔ non-`www` đã chốt một hướng
- [ ] Không có redirect chain > 1 bước

### Metadata 🔴

- [ ] `metadataBase` đặt ở `app/layout.tsx`, đọc từ env
- [ ] `title.template` + `title.default`
- [ ] Mọi trang index được có `<title>` riêng, không trùng
- [ ] Mọi trang index được có `<link rel="canonical">` tuyệt đối, HTTPS
- [ ] Mọi trang index được có `<meta name="description">` riêng
- [ ] `og:image` tồn tại trên mọi mẫu trang, URL tuyệt đối, 1200×630
- [ ] `viewport` export riêng, không nằm trong `metadata`
- [ ] `robots.googleBot['max-image-preview'] = 'large'`

### Rendering 🔴

- [ ] `params`/`searchParams` được `await` ở mọi nơi
- [ ] Nội dung chính có trong HTML thô (kiểm tra bằng `curl`)
- [ ] Điều hướng dùng `<a href>` hoặc `<Link>`, không `div onClick`
- [ ] Không có `metadata` export trong Client Component
- [ ] `'use client'` không đặt ở `layout.tsx`/`page.tsx`
- [ ] `dynamicParams = false` ở các route động hữu hạn

### Hiệu năng 🔴

- [ ] LCP ≤ 2.5s trên mobile (Lighthouse/PSI, mạng 4G)
- [ ] CLS ≤ 0.1
- [ ] Mọi ảnh có kích thước hoặc khung tỷ lệ
- [ ] Đúng một ảnh `priority` mỗi trang
- [ ] `next/font` có subset `vietnamese`, `display: swap`
- [ ] Không có request tới `fonts.googleapis.com`

### Nội dung 🔴

- [ ] Mỗi trang đúng một `<h1>`
- [ ] Mọi ảnh nội dung có `alt` mô tả
- [ ] Không có trang mồ côi
- [ ] Có trang liên hệ / giới thiệu / chính sách bảo mật
- [ ] Không có Lorem ipsum hoặc nội dung placeholder trong production

---

## 11.2. Gate B — Tuần đầu sau launch

### Xác minh hạ tầng 🟡

- [ ] Search Console xác minh (cả `www` và non-`www`)
- [ ] Sitemap đã submit, không lỗi
- [ ] Bing Webmaster Tools đã cấu hình
- [ ] `robots.txt` tester trong GSC trả OK
- [ ] URL Inspection một URL đại diện: HTML render có nội dung
- [ ] GA4 ghi nhận organic traffic

### Structured data 🟡

- [ ] `Organization` + `WebSite` ở layout gốc, không lỗi
- [ ] `BreadcrumbList` trên trang con
- [ ] `BlogPosting`/`Product` ở mẫu trang tương ứng
- [ ] Đã chạy Rich Results Test cho mỗi mẫu
- [ ] Không có lỗi schema trong GSC → Enhancements

### CWV & UX 🟡

- [ ] PSI ≥ 90 (mobile) cho trang chủ và 2 trang chính
- [ ] Không có CLS do font/ảnh
- [ ] Điều hướng bàn phím hoạt động
- [ ] Tương phản màu đạt WCAG AA
- [ ] Không có popup che nội dung ngay khi tải

### Theo dõi 🟡

- [ ] Đã ghi baseline: impressions, clicks, CTR, position
- [ ] Log monitoring hoặc GSC Crawl Stats đã xem lần đầu
- [ ] Cảnh báo 5xx đã thiết lập

---

## 11.3. Gate C — Định kỳ hàng tháng

### Index & crawl 🟢

- [ ] Báo cáo Pages: không có lỗi mới, lý do loại trừ hợp lý
- [ ] Không có `Soft 404` mới
- [ ] Số URL index tăng/giảm hợp lý
- [ ] Kiểm tra Crawl Stats: Googlebot chủ yếu crawl URL quan trọng
- [ ] Không có URL rác phát sinh

### Nội dung 🟢

- [ ] Trang có impression cao nhưng CTR thấp → viết lại title/description
- [ ] Trang có impression giảm → kiểm tra cập nhật thuật toán, đối thủ
- [ ] Kiểm tra cannibalization (nhiều URL cùng truy vấn)
- [ ] Trang cũ cập nhật nội dung (ít nhất 20% trang/năm)
- [ ] Trang mỏng/không ai truy cập → gộp, cải thiện hoặc `noindex`
- [ ] Kiểm tra link gãy nội bộ và bên ngoài

### Kỹ thuật 🟢

- [ ] Lighthouse CI vẫn xanh
- [ ] CWV p75 vẫn trong ngưỡng
- [ ] Cập nhật Next.js: đọc breaking changes trước khi nâng
- [ ] Kiểm tra lại danh sách schema Google còn hỗ trợ
- [ ] Sao lưu `redirects.json`, sitemap config
- [ ] Rà soát dependency phình bundle

### Đối thủ & thị trường 🟢

- [ ] So sánh tốc độ với 3 đối thủ chính
- [ ] Rà soát từ khoá mới có tiềm năng
- [ ] Kiểm tra backlink mới/mất
- [ ] Kiểm tra xuất hiện trong AI answers cho truy vấn chính

---

## 11.4. Checklist theo mẫu trang

### Trang chủ

- [ ] Title có thương hiệu + giá trị cốt lõi
- [ ] Có `Organization` + `WebSite` schema
- [ ] Có internal link tới các mục chính
- [ ] Ảnh hero `priority`, tối ưu LCP
- [ ] Canonical `/`

### Trang danh mục

- [ ] Title riêng cho từng trang phân trang
- [ ] Canonical tự thân mỗi trang
- [ ] `CollectionPage` + `ItemList` + `BreadcrumbList`
- [ ] `dynamicParams = false` nếu số trang hữu hạn
- [ ] Facet có giá trị SEO đã tách route
- [ ] Facet rác `noindex, follow`

### Trang chi tiết sản phẩm

- [ ] Title = tên + thuộc tính phân biệt
- [ ] `Product` + `Offer` đầy đủ trường bắt buộc
- [ ] `availability` đúng theo tồn kho
- [ ] Ảnh có `sizes`, ảnh chính có `priority`
- [ ] Mô tả riêng, không copy nhà cung cấp
- [ ] Canonical tự thân
- [ ] Sản phẩm hết hàng: `OutOfStock` hoặc 301 tới danh mục

### Bài viết

- [ ] `BlogPosting`/`NewsArticle` đầy đủ
- [ ] Có tác giả thật + link trang tác giả
- [ ] Ngày đăng và ngày cập nhật hiển thị
- [ ] Ảnh cover có `alt`, `og:image`
- [ ] Internal link tới bài liên quan và trang trụ
- [ ] Có mục lục nếu bài dài

### Trang liên hệ

- [ ] `LocalBusiness` schema nếu là doanh nghiệp địa phương
- [ ] NAP (Name, Address, Phone) nhất quán với Google Business Profile
- [ ] Bản đồ, giờ mở cửa
- [ ] Form có label, thông báo lỗi rõ

### Trang 404

- [ ] Trả status 404 thật
- [ ] `noindex`
- [ ] Có link về trang chủ và các mục chính
- [ ] Không tự redirect về trang chủ

### Trang search / tài khoản / giỏ hàng

- [ ] `noindex, follow`
- [ ] Không nằm trong sitemap
- [ ] Không có internal link từ trang công khai (hoặc `nofollow`)

---

## 11.5. Định nghĩa "done" cho một thay đổi SEO

Một thay đổi SEO chỉ được coi là hoàn thành khi:

1. ✅ Code đã merge và deploy lên production
2. ✅ Đã kiểm chứng bằng `curl` trên HTML thô (không chỉ DevTools)
3. ✅ Đã kiểm tra trên ít nhất 1 URL thuộc mẫu trang bị ảnh hưởng
4. ✅ Lighthouse/PSI không tệ hơn trước
5. ✅ Script `seo:check` chạy xanh trong CI
6. ✅ Đã ghi vào changelog SEO: ngày, thay đổi, lý do, kỳ vọng
7. ✅ Đã ghi baseline để đo lại sau ≥ 28 ngày
8. ✅ Nếu là thay đổi URL: đã có redirect và cập nhật sitemap

---

## 11.6. Mẫu changelog SEO

```markdown
## 2026-04-10 — Cải thiện metadata trang danh mục

**Vấn đề:** 120 trang danh mục dùng chung title "Sản phẩm", CTR 0.8%.
**Thay đổi:**
- `generateMetadata` sinh title/description theo tên danh mục
- Thêm canonical tự thân cho trang phân trang
- Thêm `BreadcrumbList` schema

**File ảnh hưởng:** `app/danh-muc/[slug]/page.tsx`, `lib/seo.ts`
**Kiểm chứng:** `curl` OK 3 mẫu; LHCI seo 98; `seo:check` xanh
**Baseline (30 ngày trước):** impressions 45.200 · clicks 361 · CTR 0.80% · pos 18.4
**Đo lại ngày:** 2026-05-10
```

---

## 11.7. Câu hỏi chẩn đoán khi site không lên

Trả lời theo thứ tự, dừng ở câu trả lời "không" đầu tiên:

1. Google có **crawl** được trang không? (`robots.txt`, status code, log)
2. Google có **thấy nội dung** trong HTML thô không? (`curl`)
3. Trang có bị **`noindex`** không? (meta, header)
4. Google có **chọn canonical** đúng không? (URL Inspection)
5. Trang có **đủ khác biệt** với các trang khác của bạn không? (trùng lặp)
6. Trang có **khớp intent** của truy vấn mục tiêu không?
7. Nội dung có **tốt hơn** những gì đang xếp hạng không?
8. Trang có **được link nội bộ** đủ mạnh không?
9. Có **tín hiệu E-E-A-T** (tác giả, thẩm quyền) không?
10. Trải nghiệm trang (CWV, mobile) có **đạt** không?

Nếu tất cả đều "có" mà vẫn không lên: vấn đề nằm ở **mức độ cạnh tranh của truy vấn** hoặc **thẩm quyền domain**, không phải kỹ thuật.
