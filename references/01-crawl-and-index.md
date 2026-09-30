# 01 — Nền tảng: Crawl, Render, Index

Tầng gốc. Nếu tầng này hỏng thì mọi tối ưu phía sau vô nghĩa.

---

## 1.1. Chuỗi 4 bước của Google

| Bước | Việc Google làm | Thứ phá hỏng nó |
| --- | --- | --- |
| **1. Discovery** | Tìm URL từ link, sitemap, backlink, redirect | Không có internal link thật; sitemap sai; trang mồ côi |
| **2. Crawling** | Tải HTML, đọc `robots.txt`, header, status code | `Disallow` nhầm; chặn `.js`/`.css`; 5xx; redirect chain |
| **3. Rendering** | Chạy JS trong Chromium headless, hàng đợi render | Nội dung chỉ có sau `useEffect`; fetch client-side; bundle quá nặng |
| **4. Indexing** | Phân tích, canonical hoá, gán tín hiệu, lưu vào index | `noindex`; canonical trỏ sai; trùng lặp; chất lượng thấp |

**Hệ quả thực tế:** index không xảy ra ngay khi crawl. Với trang phụ thuộc JS, độ trễ giữa crawl và index thường tính bằng **ngày đến tuần**. Đây là lý do phải render phía server.

---

## 1.2. Googlebot và JavaScript

- Googlebot dùng **evergreen Chromium** — hỗ trợ JS hiện đại, nhưng **không** đảm bảo mọi API trình duyệt (ví dụ một số Web API mới, service worker không được dùng khi render).
- Google **không** cuộn trang khi render sơ bộ (lazy-load theo viewport có thể không được kích hoạt).
- Google **có** timeout render; trang nặng/hydration chậm có thể bị bỏ dở.
- Google **có** giới hạn tài nguyên render → trang càng nặng JS càng dễ bị render muộn hoặc thiếu.

### Quy tắc bất di bất dịch

| Phải có trong HTML thô | Có thể ở client |
| --- | --- |
| Nội dung chính của trang | Tương tác, dropdown, modal |
| Toàn bộ `<a href="...">` điều hướng | Hover state, animation |
| `<title>`, `<meta>`, canonical, hreflang | Ghi chú UI, toast |
| JSON-LD | Widget không quan trọng |
| Breadcrumb dạng link | Filter tạm thời trong phiên |

### Kiểm chứng bằng lệnh

```bash
# HTML thô — không JS. Đây là thứ Googlebot nhận ở đợt crawl đầu.
curl -sL https://example.com/san-pham/abc | grep -Eo '<title>[^<]*</title>'
curl -sL https://example.com/san-pham/abc | grep -c '<a href='

# Kiểm tra JS/CSS có bị chặn không (phải KHÔNG thấy Disallow cho /_next/)
curl -s https://example.com/robots.txt
```

> Nếu nội dung chỉ xuất hiện trong DevTools nhưng không có trong `curl`, bạn đang phụ thuộc vào đợt render thứ hai — rủi ro cao.

---

## 1.3. `robots.txt` vs meta robots vs `X-Robots-Tag`

Ba cơ chế khác nhau, rất hay bị dùng sai lẫn nhau.

| Cơ chế | Tác dụng | Có chặn index không? | Ghi chú |
| --- | --- | --- | --- |
| `robots.txt` `Disallow` | Chặn **crawl** | ❌ Không | URL vẫn có thể được index nếu còn link trỏ tới |
| `<meta name="robots" content="noindex">` | Chặn **index** | ✅ Có | Phải nằm trong HTML mà bot đọc được |
| `X-Robots-Tag: noindex` (HTTP header) | Chặn **index** | ✅ Có | Dùng cho file không phải HTML (PDF, ảnh) |

**Bẫy kinh điển:** `Disallow: /admin` + `noindex` trong trang admin ⇒ bot **không đọc được** `noindex` vì bị chặn crawl ⇒ trang vẫn có thể vào index với nội dung rỗng. Muốn loại khỏi index: cho crawl, đặt `noindex`, chờ hết, rồi mới `Disallow`.

Trong App Router, header cấu hình ở `next.config.ts`:

```ts
const nextConfig = {
  async headers() {
    return [
      {
        source: '/tai-lieu/:path*.pdf',
        headers: [{ key: 'X-Robots-Tag', value: 'noindex' }],
      },
      {
        source: '/:path*',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
        ],
      },
    ]
  },
}
export default nextConfig
```

---

## 1.4. Crawl budget

Crawl budget chỉ thực sự đáng lo với site **hàng chục nghìn URL trở lên**, hoặc site có server chậm.

**Dấu hiệu lãng phí crawl budget:**
- Parameter rác sinh vô hạn (`?sort=`, `?utm_`, `?page=99999`, `?color=`)
- Trang mồ côi không có internal link nhưng nằm trong sitemap
- Soft 404 (trả 200 cho trang rỗng)
- Redirect chain dài
- Trang lịch (calendar) hoặc search nội bộ sinh URL vô hạn
- Faceted navigation mở toàn bộ tổ hợp filter

**Cách xử lý chuẩn:**

| Đối tượng | Xử lý |
| --- | --- |
| Trang search nội bộ | `noindex` + `Disallow` (không cần crawl) |
| Parameter sắp xếp/lọc không tạo nội dung mới | canonical về URL gốc + `Disallow` có kiểm soát |
| Tổ hợp filter có giá trị SEO | Tạo URL tĩnh riêng, có nội dung riêng, canonical riêng |
| URL sinh vô hạn theo param | `dynamicParams = false` + validate trong page |
| Trang phân trang | Cho crawl, tự canonical về chính nó, không canonical về trang 1 |

Trong Next.js, chặn không gian URL vô hạn ở cấp segment:

```tsx
// app/(shop)/san-pham/[slug]/page.tsx
export const dynamicParams = false   // param không nằm trong generateStaticParams → 404

export async function generateStaticParams() {
  const products = await getProducts()
  return products.map((p) => ({ slug: p.slug }))
}
```

---

## 1.5. Status code — tín hiệu mạnh nhất bị bỏ quên

| Code | Nghĩa với Google | Dùng khi |
| --- | --- | --- |
| `200` | Trang hợp lệ | Trang thật, kể cả trang rỗng có chủ đích |
| `301`/`308` | Chuyển vĩnh viễn, chuyển tín hiệu | Đổi URL, gộp `www`, gộp HTTP→HTTPS |
| `302`/`307` | Chuyển tạm | A/B test, bảo trì ngắn |
| `404` | Không tồn tại | URL sai thật |
| `410` | Đã xoá vĩnh viễn | Xoá nội dung có chủ đích, Google loại nhanh hơn |
| `429` | Quá nhiều request | Rate limit — Google giảm crawl |
| `5xx` | Lỗi server | Google giảm crawl, có thể bỏ URL khỏi index nếu kéo dài |

**Soft 404:** trả `200` nhưng nội dung là "Không tìm thấy". Google coi là soft 404 và vẫn loại khỏi index, nhưng **lãng phí crawl budget**. Trong App Router:

```tsx
import { notFound } from 'next/navigation'

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const data = await getBySlug(slug)
  if (!data) notFound()          // render app/not-found.tsx với status 404
  return <Article data={data} />
}
```

Redirect vĩnh viễn trong App Router (dùng `permanentRedirect` cho 308, `redirect` cho 307):

```tsx
import { permanentRedirect } from 'next/navigation'
permanentRedirect('/url-moi')   // 308
```

Và ở cấp cấu hình (được khuyến nghị cho số lượng lớn, không tốn render):

```ts
// next.config.ts
async redirects() {
  return [
    { source: '/blog/:slug', destination: '/bai-viet/:slug', permanent: true },
    { source: '/:path*', has: [{ type: 'host', value: 'www.example.com' }],
      destination: 'https://example.com/:path*', permanent: true },
  ]
}
```

> **Không** dùng redirect để xử lý `www` ở tầng application nếu có thể làm ở CDN/edge — rẻ hơn và nhanh hơn.

---

## 1.6. Index không đồng nghĩa xếp hạng

Ba trạng thái khác nhau, thường bị gộp:

1. **Discovered – not indexed**: Google biết URL nhưng chưa crawl (thường do crawl budget hoặc chất lượng).
2. **Crawled – not indexed**: đã đọc nhưng chưa thấy đáng index (nội dung mỏng, trùng lặp, không giá trị).
3. **Indexed**: đã vào index, có thể xếp hạng.

`Crawled – not indexed` là dấu hiệu **chất lượng nội dung**, không phải lỗi kỹ thuật. Sửa bằng nội dung, không bằng thẻ meta.

---

## 1.7. Checklist tầng nền tảng

- [ ] `robots.txt` cho phép crawl `/_next/static/`, JS và CSS
- [ ] Không có `Disallow: /` sót lại từ staging
- [ ] Mọi URL quan trọng đều có ít nhất 1 internal link dạng `<a href>`
- [ ] `sitemap.xml` tồn tại, khai báo trong `robots.txt`, chỉ chứa URL canonical và trả 200
- [ ] Trang không tồn tại trả `404`/`410`, không trả `200` rỗng
- [ ] Không có redirect chain > 1 bước
- [ ] `noindex` chỉ đặt ở nơi cần, không đặt trên layout gốc
- [ ] Staging/preview có `noindex` hoặc `X-Robots-Tag: noindex`
- [ ] HTTP → HTTPS, non-www → www (hoặc ngược lại) đã chốt một hướng duy nhất
- [ ] `app/robots.ts` và `public/robots.txt` không tồn tại đồng thời
- [ ] `dynamicParams = false` ở các route `[slug]` có không gian URL hữu hạn
- [ ] Trang search nội bộ, giỏ hàng, trang tài khoản đã `noindex`
