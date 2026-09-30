# 06 — URL, Canonical, i18n, Trùng lặp nội dung

Trùng lặp nội dung là nguyên nhân âm thầm phổ biến nhất làm site "không lên". File này là bộ công cụ chống nó.

---

## 6.1. Thiết kế URL

| Quy tắc | Ví dụ đúng | Ví dụ sai |
| --- | --- | --- |
| Chữ thường | `/san-pham/bat-tam` | `/San-Pham/Bat-Tam` |
| Dùng `-` phân tách | `/bai-viet/seo-nextjs` | `/bai-viet/seo_nextjs` |
| Không dấu tiếng Việt | `/san-pham/den-led` | `/san-pham/đèn-led` (punicode) |
| Ngắn, có nghĩa | `/bang-gia` | `/page?id=42&cat=7` |
| Không tham số khi không cần | `/danh-muc/ao-thun` | `/danh-muc?type=ao-thun` |
| Không đổi sau khi publish | — | đổi slug không redirect |
| Không lồng quá sâu | `/danh-muc/ao-thun/nam` | `/a/b/c/d/e/f/x` |
| Không nhồi từ khoá | `/ao-thun-nam-dep-re` | `/ao-thun/ao-thun-nam/ao-thun-nam-dep` |

**Độ sâu:** Google không giới hạn số cấp, nhưng URL sâu thường ít được crawl hơn và khó hiểu hơn. Giữ tối đa 3–4 cấp.

**Từ khoá trong URL:** là tín hiệu yếu nhưng có giá trị với người dùng và khi được chia sẻ. Dùng slug mô tả, không dùng ID trần.

```ts
// Giữ slug cũ khi đổi tên sản phẩm — quan trọng
export function slugify(input: string) {
  return input
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')   // bỏ dấu tiếng Việt
    .replace(/[đĐ]/g, 'd')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}
```

> Tiếng Việt cần xử lý riêng `đ/Đ` vì `normalize('NFD')` **không** tách được ký tự này.

---

## 6.2. Trailing slash

`trailingSlash` mặc định là `false`. Nếu không chốt, `/san-pham` và `/san-pham/` là hai URL khác nhau:

- Một số host/CDN tự thêm `/` → sinh redirect 308 hàng loạt → chậm, lãng phí crawl.
- Canonical khai báo một kiểu, link nội bộ dùng kiểu khác → mâu thuẫn tín hiệu.

**Cách xử lý:** chốt một giá trị trong `next.config.ts`, dùng nhất quán trong `Link`, canonical, sitemap.

```ts
const nextConfig = { trailingSlash: false }
```

Hệ quả cần chú ý khi `trailingSlash: true`: `next/link` sẽ thêm `/`, và cần cấu hình host tương ứng (đặc biệt với static export).

---

## 6.3. Phân cấp canonical — bảng quyết định

| Tình huống | Canonical đúng |
| --- | --- |
| Trang duy nhất | Trỏ về chính nó |
| Có `?utm_source=...`, `?ref=...` | Trỏ về URL không có tracking param |
| Có `?sort=price`, `?view=grid` (không đổi nội dung) | Trỏ về URL gốc không param |
| Có `?color=do` (tạo tập kết quả khác, có giá trị SEO) | **Tự canonical** + nội dung riêng + có internal link |
| Trang phân trang `?page=3` | **Tự canonical** (`?page=3`), không trỏ về trang 1 |
| Phiên bản in / AMP / mobile riêng | Trỏ về bản chính |
| HTTP vs HTTPS | Bản HTTPS |
| `www` vs non-`www` | Bản đã chốt |
| Bài viết có nhiều phiên bản ngôn ngữ | Tự canonical + `hreflang` đối xứng |
| Nội dung tổng hợp từ nguồn khác | Cân nhắc bỏ hoặc viết lại; **không** canonical về nguồn khác |

**Nguyên tắc:** canonical là **gợi ý** với Google, nhưng gợi ý mâu thuẫn (canonical + sitemap + internal link + redirect khác nhau) sẽ bị bỏ qua.

### Trong Next.js

```tsx
// Cách 1: metadata (khuyến nghị)
export const metadata: Metadata = { alternates: { canonical: '/san-pham/abc' } }

// Cách 2: chỉ set khi cần logic động (query param)
export async function generateMetadata({ params, searchParams }): Promise<Metadata> {
  const { slug } = await params
  const { page } = await searchParams
  return {
    alternates: { canonical: page && page !== '1' ? `/danh-muc/${slug}?page=${page}` : `/danh-muc/${slug}` },
  }
}
```

---

## 6.4. Tham số URL — xử lý theo mục đích

| Loại param | Xử lý |
| --- | --- |
| `utm_*`, `fbclid`, `gclid` | Canonical về URL sạch; **không** `Disallow` (nếu chặn, mất luôn khả năng đo) |
| `sort`, `view`, `layout` | Canonical về URL gốc |
| `filter` có giá trị SEO (thương hiệu, kích cỡ) | Trang riêng, path tĩnh, canonical tự thân |
| `filter` tổ hợp vô hạn | `Disallow` hoặc `noindex, follow` |
| `page` (phân trang) | Cho index, canonical tự thân, title riêng |
| `sessionid`, `cart` | `Disallow` + `noindex` |
| Search nội bộ `?q=` | `noindex, follow` + có kiểm soát crawl |

```ts
// Ví dụ middleware/proxy [16] chặn tổ hợp param rác
// proxy.ts
import { NextRequest, NextResponse } from 'next/server'

export default function proxy(req: NextRequest) {
  const url = req.nextUrl
  const sp = url.searchParams

  // Giữ tối đa 2 param filter; nhiều hơn → noindex qua header
  const filterCount = [...sp.keys()].filter((k) => k.startsWith('filter')).length
  const res = NextResponse.next()
  if (filterCount > 2) res.headers.set('X-Robots-Tag', 'noindex, follow')
  return res
}
```

> `[16]` `middleware.ts` đã đổi tên thành `proxy.ts` (chạy trên Node.js runtime). `middleware.ts` vẫn dùng được cho Edge nhưng đã deprecated.

---

## 6.5. i18n / đa ngôn ngữ

### Cấu trúc URL

| Mô hình | Ví dụ | Đánh giá |
| --- | --- | --- |
| Thư mục con (khuyến nghị) | `example.com/vi/...`, `example.com/en/...` | Dễ quản lý, gom tín hiệu về một domain |
| Subdomain | `vi.example.com` | Tách tín hiệu, tốn công hơn |
| ccTLD | `example.vn`, `example.com` | Mạnh nhất về tín hiệu địa lý, tốn kém nhất |
| Tham số | `example.com?lang=vi` | ❌ Không khuyến nghị |

### Cấu trúc thư mục App Router

```
app/
  [locale]/
    layout.tsx          # generateStaticParams cho locale
    page.tsx
    san-pham/[slug]/page.tsx
```

```tsx
// app/[locale]/layout.tsx
export async function generateStaticParams() {
  return [{ locale: 'vi' }, { locale: 'en' }]
}

export async function generateMetadata({ params }): Promise<Metadata> {
  const { locale } = await params
  return {
    alternates: {
      canonical: `/${locale}`,
      languages: {
        'vi-VN': '/vi',
        'en-US': '/en',
        'x-default': '/vi',
      },
    },
  }
}
```

### Quy tắc hreflang

1. **Đối xứng bắt buộc:** nếu trang A khai báo B, trang B phải khai báo A. Thiếu đối xứng ⇒ Google bỏ qua toàn bộ cụm.
2. **Mã ngôn ngữ đúng chuẩn:** `vi-VN` hoặc `vi` (ISO 639-1 tùy chọn ISO 3166-1 alpha-2). Không dùng `vn` (sai — `vn` là mã quốc gia, không phải ngôn ngữ).
3. **`x-default`** trỏ về phiên bản cho người dùng không khớp ngôn ngữ nào.
4. **Không trỏ hreflang tới trang `noindex` hoặc redirect.**
5. **Chỉ dùng cho bản dịch thực sự**, không dùng để biến thể từ khoá.
6. **Có thể dùng sitemap** để khai báo hreflang (`xhtml:link`) thay cho thẻ trong `<head>` — nhưng đừng làm cả hai cách khác nhau.

### Nội dung đa ngôn ngữ

- **Không máy dịch toàn bộ** rồi index mà không hiệu đính — chất lượng thấp, Google phát hiện được.
- Mỗi ngôn ngữ phải có **nội dung riêng biệt**, không phải bản dịch word-by-word của cùng một trang mỏng.
- Title/description phải **bản địa hoá**, không dùng lại tiếng Anh cho trang tiếng Việt.
- `lang` attribute trên `<html>` phải khớp locale:

```tsx
// app/[locale]/layout.tsx
export default async function LocaleLayout({ children, params }) {
  const { locale } = await params
  return (
    <html lang={locale}>
      <body>{children}</body>
    </html>
  )
}
```

---

## 6.6. Redirect: chiến lược và lỗi

### Ma trận quyết định

| Tình huống | Hành động |
| --- | --- |
| URL đổi cấu trúc | 301/308 tới URL mới, giữ 1-1 |
| Trang gộp vào trang khác | 301 tới trang đích gần nhất về nội dung |
| Nội dung bị xoá, không có thay thế | 410 (nhanh hơn 404) |
| Sản phẩm hết hàng vĩnh viễn | 301 tới danh mục, **hoặc** giữ trang với `OutOfStock` |
| Sản phẩm hết hàng tạm thời | Giữ 200 + `availability: OutOfStock` |
| Bảo trì ngắn | 503 + `Retry-After` |
| Đổi domain | 301 toàn bộ + cập nhật sitemap + giữ song song ít nhất 6 tháng |

### Lỗi thường gặp

| Lỗi | Hậu quả |
| --- | --- |
| Redirect chain (A→B→C) | Mất tín hiệu, tăng độ trễ. Luôn trỏ thẳng A→C |
| Redirect loop | Google bỏ URL |
| Redirect 302 cho thay đổi vĩnh viễn | Không chuyển tín hiệu |
| Redirect tất cả 404 về trang chủ | Soft 404, Google phạt |
| Redirect trang đã `noindex` | Vô nghĩa |
| Xoá URL không redirect | Mất backlink, mất traffic |

### Giữ lịch sử redirect

Với site lớn, quản lý redirect bằng dữ liệu thay vì hard-code:

```ts
// next.config.ts
import redirectMap from './data/redirects.json'   // [{ source, destination, permanent }]

const nextConfig = {
  async redirects() {
    return redirectMap
  },
}
```

---

## 6.7. Phân trang

| Cách | Trạng thái |
| --- | --- |
| `rel="next"` / `rel="prev"` | ❌ Google **không** dùng từ 2019 |
| Canonical về trang 1 | ❌ Sai — làm mất các trang sau |
| Canonical tự thân | ✅ Đúng |
| `noindex` các trang sau | ❌ Sai — Google không crawl được để tìm nội dung sâu |
| "Xem thêm" + tải bằng JS | ⚠️ Rủi ro nếu nội dung không có URL riêng |
| Infinite scroll | ⚠️ Phải kèm link phân trang thật trong HTML |

**Cấu hình đúng:**

```tsx
// app/danh-muc/[slug]/page/[page]/page.tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const { slug, page } = await params
  const isFirst = page === '1'
  return {
    title: isFirst ? `${category.name}` : `${category.name} — Trang ${page}`,
    description: isFirst
      ? category.description
      : `Trang ${page} danh mục ${category.name}. ${category.description}`,
    alternates: { canonical: isFirst ? `/danh-muc/${slug}` : `/danh-muc/${slug}/page/${page}` },
  }
}
```

Trang 1 nên có URL sạch `/danh-muc/x` (không phải `/danh-muc/x/page/1`) và redirect 308 từ `/page/1` về URL sạch.

---

## 6.8. Faceted navigation

Đây là nguồn sinh URL vô hạn lớn nhất của site thương mại.

| Loại facet | Xử lý |
| --- | --- |
| Facet có nhu cầu tìm kiếm (thương hiệu, giới tính, chất liệu) | Trang tĩnh riêng: `/ao-thun/nam`, `/ao-thun/uniqlo` |
| Facet tổ hợp tự do (nhiều chiều cùng lúc) | `noindex, follow` hoặc canonical về facet chính |
| Facet sắp xếp/thứ tự hiển thị | Canonical về URL không facet |
| Facet không có kết quả | `noindex` + 404 hoặc thông báo "không có kết quả" có `noindex` |

**Chiến lược thực dụng:** chọn ra **một số facet có giá trị SEO**, chuyển chúng thành route tĩnh với nội dung riêng (mô tả, FAQ, internal link). Phần còn lại `noindex, follow`.

---

## 6.9. Anti-pattern trùng lặp nội dung

| Anti-pattern | Cách phát hiện | Cách sửa |
| --- | --- | --- |
| Nhiều URL cùng nội dung, không canonical | Crawl & so sánh hash nội dung | Thêm canonical + redirect |
| Canonical trỏ về trang khác domain không chủ đích | `curl \| grep canonical` | Sửa `metadataBase` |
| Trang `noindex` nằm trong sitemap | Đối chiếu sitemap với meta robots | Loại khỏi sitemap |
| Trang redirect nằm trong sitemap | Kiểm tra status code | Loại khỏi sitemap |
| Sitemap chứa URL param | Soát sitemap | Chỉ đưa URL canonical |
| Nội dung sản phẩm copy từ nhà cung cấp | So sánh text | Viết lại, thêm dữ liệu riêng |
| Trang tag/archive mỏng | Kiểm tra số bài viết | `noindex` nếu < ngưỡng, hoặc gộp |
| Nhiều bản ngôn ngữ không hreflang | Kiểm tra `<link rel="alternate">` | Thêm hreflang đối xứng |

---

## 6.10. Checklist URL & canonical

- [ ] Slug chữ thường, không dấu, phân tách bằng `-`
- [ ] `trailingSlash` đã chốt và nhất quán ở Link/canonical/sitemap
- [ ] Mọi trang index được có canonical tuyệt đối đúng domain
- [ ] Tracking param không thay đổi canonical
- [ ] Phân trang tự canonical, có title riêng
- [ ] Facet có giá trị SEO đã tách thành route tĩnh
- [ ] Facet còn lại `noindex, follow`
- [ ] Hreflang đối xứng, có `x-default`, mã ngôn ngữ đúng chuẩn
- [ ] `<html lang>` khớp locale
- [ ] Không có redirect chain > 1 bước
- [ ] URL xoá trả 404/410, không redirect về trang chủ
- [ ] Sitemap không chứa URL `noindex`/redirect
- [ ] Redirect cấu hình tập trung, không rải trong component
- [ ] Slug cũ được map sang slug mới khi đổi tên
