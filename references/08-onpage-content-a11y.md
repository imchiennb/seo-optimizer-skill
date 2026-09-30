# 08 — On-page, nội dung, accessibility

Tầng này quyết định xếp hạng thật. Kỹ thuật chỉ đưa trang vào index; nội dung mới đưa trang lên top.

---

## 8.1. Semantic HTML — nền tảng của cả SEO và a11y

Google dùng cấu trúc DOM để hiểu trang. Dùng đúng thẻ vừa tốt cho bot vừa tốt cho screen reader.

```tsx
// ✅ Cấu trúc đúng
<body>
  <a href="#main" className="sr-only focus:not-sr-only">Bỏ qua điều hướng</a>
  <header>
    <nav aria-label="Chính">
      <Link href="/">Trang chủ</Link>
      <Link href="/san-pham">Sản phẩm</Link>
    </nav>
  </header>
  <main id="main">
    <article>
      <h1>Tiêu đề chính của trang</h1>
      <p>...</p>
      <section aria-labelledby="sec-1">
        <h2 id="sec-1">Mục con</h2>
        <p>...</p>
      </section>
    </article>
    <aside aria-label="Liên quan">...</aside>
  </main>
  <footer>...</footer>
</body>
```

| Thẻ | Vai trò |
| --- | --- |
| `<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>` | Landmark — screen reader nhảy nhanh |
| `<article>` | Nội dung độc lập, có thể syndicate |
| `<section>` | Nhóm chủ đề, nên có heading |
| `<h1>`–`<h6>` | Cấu trúc thông tin |
| `<time datetime="...">` | Ngày tháng có ngữ nghĩa máy đọc |
| `<figure>`/`<figcaption>` | Ảnh + chú thích |
| `<address>` | Thông tin liên hệ |
| `<ol>`/`<ul>`/`<dl>` | Danh sách có ngữ nghĩa |

> **Không** lạm dụng `<div>` cho mọi thứ. Đây là vấn đề phổ biến nhất của code sinh bởi AI/utility-class.

---

## 8.2. Heading

| Quy tắc | Chi tiết |
| --- | --- |
| Đúng **một** `<h1>` mỗi trang | Khớp chủ đề chính, không nhất thiết trùng `<title>` |
| Không nhảy cấp | `<h1>` → `<h2>` → `<h3>`, không `<h1>` → `<h4>` |
| Heading mô tả nội dung | "Hướng dẫn cài đặt" tốt hơn "Bước 2" |
| Không dùng heading để tạo style | Dùng CSS |
| Không nhồi từ khoá | Heading là tín hiệu ngữ nghĩa, không phải chỗ nhét keyword |

```tsx
// ❌ Sai: hai h1, nhảy cấp, heading trang trí
<h1>Sản phẩm</h1>
<div className="text-4xl">Áo thun</div>
<h4>Chi tiết</h4>

// ✅ Đúng
<h1>Áo thun nam cotton</h1>
<h2>Chất liệu và form dáng</h2>
<h3>Hướng dẫn chọn size</h3>
```

---

## 8.3. Link và anchor text

| Quy tắc | Lý do |
| --- | --- |
| Dùng `<a href>` cho điều hướng | `<button onClick={router.push}>` **không** được Google theo |
| Dùng `<button>` cho hành động | Phân biệt rõ chức năng |
| Anchor text mô tả | "Xem bảng giá dịch vụ SEO" > "Xem thêm" |
| Không dùng "click here", "tại đây" | Không mang thông tin |
| Không nhồi từ khoá vào anchor | Có thể bị coi là spam |
| Link nội bộ phải là `<Link>` của Next | Prefetch + điều hướng client-side |

```tsx
// ❌ Googlebot không theo được
<div onClick={() => router.push('/bang-gia')}>Bảng giá</div>

// ✅
<Link href="/bang-gia">Bảng giá dịch vụ SEO</Link>
```

**Link nội bộ (internal linking):**
- Mỗi trang quan trọng phải được link từ ít nhất 2–3 trang khác.
- Trang trụ (pillar) link tới các trang con, trang con link ngược lại trụ.
- Breadcrumb là một dạng internal link có cấu trúc.
- Tránh trang mồ côi (orphan) — URL chỉ có trong sitemap.
- Giới hạn số link mỗi trang một cách hợp lý (không có giới hạn cứng, nhưng 1000 link rác là dấu hiệu xấu).

---

## 8.4. Ảnh: alt text và image SEO

```tsx
// ❌
<Image src="/a.jpg" alt="image" />
<Image src="/a.jpg" alt="" />          {/* chỉ đúng khi ảnh thuần trang trí */}
<Image src="/a.jpg" alt="áo thun áo thun nam áo thun đẹp" />

// ✅
<Image src="/ao-thun-nam-cotton.webp" alt="Áo thun nam cotton trắng, form regular" />
```

| Quy tắc | Chi tiết |
| --- | --- |
| `alt` mô tả nội dung ảnh | Ngắn gọn, cụ thể |
| `alt=""` cho ảnh trang trí | Screen reader bỏ qua |
| Tên file có nghĩa | `ao-thun-nam.webp` > `IMG_2043.webp` |
| Định dạng hiện đại | AVIF/WebP |
| Image sitemap | Khai báo trong `sitemap.ts` với trường `images` |
| Ảnh trong ngữ cảnh | Đặt gần nội dung liên quan |
| Không nhồi keyword vào alt | Vi phạm a11y, không giúp SEO |

---

## 8.5. Chất lượng nội dung

Đây là yếu tố xếp hạng quan trọng nhất và cũng khó tự động hoá nhất.

### Câu hỏi kiểm tra chất lượng

1. **Trang này trả lời truy vấn nào?** Viết ra một câu.
2. **Nó có thông tin mà trang khác không có?** Dữ liệu gốc, kinh nghiệm thật, ảnh tự chụp, số liệu riêng.
3. **Người đọc có cần quay lại Google không?** Nếu có, nội dung chưa đủ.
4. **Ai là tác giả và tại sao tin được?** E-E-A-T.
5. **Trang này có tồn tại vì người dùng hay vì SEO?** Nếu chỉ vì SEO, bỏ đi.

### Tín hiệu E-E-A-T

| Thành phần | Cách thể hiện |
| --- | --- |
| **Experience** | Ảnh thật, case study, số liệu từ chính dự án |
| **Expertise** | Nội dung chuyên sâu, thuật ngữ dùng đúng |
| **Authoritativeness** | Được trích dẫn, backlink chất lượng |
| **Trustworthiness** | Trang tác giả, ngày cập nhật, nguồn tham chiếu, thông tin liên hệ, HTTPS |

Triển khai cụ thể:

```tsx
// Khối tác giả — có thật, có link tới trang tác giả
<aside className="author-box">
  <Image src={author.avatar} alt={author.name} width={64} height={64} />
  <div>
    <Link href={`/tac-gia/${author.slug}`} rel="author">{author.name}</Link>
    <p>{author.bio}</p>
  </div>
</aside>

// Ngày cập nhật hiển thị và có ngữ nghĩa
<p>Cập nhật lần cuối: <time dateTime={post.updatedAt.toISOString()}>
  {formatDate(post.updatedAt)}
</time></p>
```

### Nội dung mỏng (thin content)

| Dấu hiệu | Xử lý |
| --- | --- |
| < 300 từ và không có giá trị riêng | Gộp vào trang khác, hoặc bổ sung |
| Trang tag chỉ liệt kê link | `noindex` hoặc bổ sung mô tả |
| Trang sản phẩm chỉ có ảnh + giá | Thêm mô tả riêng, thông số, FAQ |
| Trang phân trang mỏng | Xem 6.7 |
| Nội dung trùng nhà cung cấp | Viết lại hoàn toàn |
| Trang "cảm ơn", "đăng ký thành công" | `noindex` |

---

## 8.6. Ánh xạ từ khoá & intent

| Bước | Việc làm |
| --- | --- |
| 1 | Liệt kê trang hiện có và mục đích từng trang |
| 2 | Xác định intent mỗi trang: thông tin / điều hướng / thương mại / giao dịch |
| 3 | Gán **một** chủ đề chính + 2–5 chủ đề phụ cho mỗi trang |
| 4 | Phát hiện **cannibalization**: nhiều trang cùng nhắm một truy vấn |
| 5 | Gộp hoặc phân biệt rõ các trang trùng ý định |
| 6 | Ghi lại trong tài liệu: URL → truy vấn chính → trang liên quan |

**Cannibalization** là lỗi chiến lược phổ biến nhất. Dấu hiệu: hai URL của bạn thay nhau xuất hiện cho cùng truy vấn trong Search Console. Cách sửa: gộp nội dung, canonical về trang chính, và internal link về trang chính.

---

## 8.7. Meta description — nghệ thuật viết

Description không xếp hạng nhưng quyết định CTR.

```
[Nội dung chính] + [lợi ích/khác biệt cụ thể] + [hành động hoặc thông tin hữu ích]
```

| Nên | Không nên |
| --- | --- |
| Nêu lợi ích cụ thể, có số liệu | "Chúng tôi là công ty hàng đầu..." |
| Khớp intent của truy vấn | Nhồi từ khoá |
| Có CTA khi phù hợp | Viết hoa toàn bộ |
| 140–160 ký tự | Cắt giữa câu |
| Khác nhau cho mỗi trang | Copy-paste hàng loạt |

---

## 8.8. Accessibility như yếu tố SEO

A11y trùng lặp đáng kể với SEO kỹ thuật: cấu trúc, alt text, heading, link. Ngoài ra:

| Yêu cầu | Chuẩn |
| --- | --- |
| Tương phản màu | ≥ 4.5:1 cho text thường (WCAG AA) |
| Điều hướng bàn phím | Mọi chức năng dùng được không cần chuột |
| Focus visible | Không xoá outline mà không thay thế |
| Label cho form | `<label htmlFor>` hoặc `aria-label` |
| Không dùng màu là tín hiệu duy nhất | Thêm text/icon |
| `lang` trên `<html>` | Đúng ngôn ngữ |
| Bỏ qua điều hướng | Skip link tới `#main` |
| Không `user-scalable=no` | Cho phép zoom |
| `prefers-reduced-motion` | Tôn trọng lựa chọn người dùng |

```tsx
// Skip link + tôn trọng reduced motion
<a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:z-50">Bỏ qua tới nội dung</a>
```

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```

---

## 8.9. Tối ưu cho AI answers / LLM

Ngoài SEO cổ điển, nội dung ngày càng được đọc bởi các hệ thống trả lời bằng AI.

| Kỹ thuật | Chi tiết |
| --- | --- |
| Trả lời trực tiếp sớm | Đặt câu trả lời ngắn ngay dưới heading, rồi mới giải thích |
| Cấu trúc rõ | Heading mô tả, danh sách, bảng — dễ trích xuất |
| Dữ liệu có nguồn | Số liệu, ngày tháng, đơn vị rõ ràng |
| Thực thể rõ ràng | Nêu tên tổ chức/sản phẩm nhất quán, có `sameAs` trong schema |
| FAQ ngắn | Câu hỏi–trả lời gọn, mỗi câu trả lời tự đủ nghĩa |
| Cho crawler AI truy cập | Kiểm tra `robots.txt` cho `GPTBot`, `ClaudeBot`, `PerplexityBot` |
| `llms.txt` | Không phải chuẩn chính thức; lợi ích chưa được chứng minh, đừng đặt cược |

Quyết định chiến lược: chặn hay cho AI crawler là **quyết định kinh doanh**, không phải kỹ thuật. Ghi rõ trong tài liệu dự án.

---

## 8.10. Anti-pattern on-page

| Anti-pattern | Vấn đề |
| --- | --- |
| Nội dung chính render bằng client | Bot không thấy |
| Nút điều hướng dạng `<div onClick>` | Không crawl được |
| Nhiều `<h1>` hoặc không có `<h1>` | Mất tín hiệu cấu trúc |
| Heading chỉ để tạo style | Nhiễu ngữ nghĩa |
| Alt text rỗng cho ảnh nội dung | Mất a11y + image SEO |
| Nhồi từ khoá trong alt/anchor | Có thể bị coi là spam |
| Trang tag/archive mỏng hàng loạt | Nội dung mỏng, loãng tín hiệu |
| Nội dung ẩn bằng `display:none` nhưng có text SEO | Vi phạm chính sách |
| Text trong ảnh | Không đọc được, không index |
| Cannibalization nhiều trang cùng intent | Không trang nào xếp hạng tốt |
| Không có tác giả / ngày cập nhật | Yếu E-E-A-T |
| Popup che nội dung ngay khi tải | Intrusive interstitial |

---

## 8.11. Checklist on-page

- [ ] Mỗi trang đúng một `<h1>`, cấu trúc heading không nhảy cấp
- [ ] Landmark đúng: `header`/`nav`/`main`/`footer`
- [ ] Mọi điều hướng dùng `<a href>` hoặc `<Link>`
- [ ] Anchor text mô tả, không "tại đây"
- [ ] Không có trang mồ côi
- [ ] Mọi ảnh nội dung có `alt` mô tả; ảnh trang trí `alt=""`
- [ ] Tên file ảnh có nghĩa
- [ ] Có khối tác giả + ngày cập nhật trên bài viết
- [ ] Có trang giới thiệu tác giả/tổ chức
- [ ] Đã ghi tài liệu ánh xạ từ khoá → URL
- [ ] Đã kiểm tra cannibalization trong Search Console
- [ ] Không có trang mỏng không mục đích đang index
- [ ] Tương phản màu đạt WCAG AA
- [ ] Điều hướng bàn phím hoạt động, focus visible
- [ ] Không có popup chặn nội dung khi tải
- [ ] `prefers-reduced-motion` được tôn trọng
- [ ] Đã quyết định chính sách với AI crawler và ghi lại
