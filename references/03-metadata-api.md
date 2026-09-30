# 03 — Metadata API: toàn bộ field và cách dùng đúng

Metadata API là "xương sống" SEO của App Router. Nắm hết file này là nắm 60% công việc.

---

## 3.1. Hai cách khai báo

```tsx
// 1) Static — object export. Nhanh nhất, dùng khi metadata không phụ thuộc dữ liệu.
import type { Metadata } from 'next'
export const metadata: Metadata = {
  title: 'Trang chủ',
  description: '...',
}

// 2) Dynamic — async function. Dùng khi metadata phụ thuộc params/dữ liệu.
export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> },
): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  return { title: post.title, description: post.excerpt }
}
```

**Quy tắc:**
- Chỉ tồn tại **một** trong hai ở mỗi segment. Không export cả hai.
- **Không thể** dùng trong Client Component (`'use client'`). Metadata phải nằm ở Server Component.
- `metadata`/`generateMetadata` chỉ có hiệu lực trong `layout.tsx` và `page.tsx` (không phải mọi file).

---

## 3.2. `metadataBase` — bắt buộc ở layout gốc

Không có `metadataBase`, mọi URL tương đối trong `openGraph.images`, `alternates.canonical`, `twitter.images` sẽ không resolve đúng → OG image hỏng, canonical sai.

```tsx
// app/layout.tsx
import type { Metadata } from 'next'

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  // ...
}
```

> Không hard-code domain ở nhiều nơi. Dùng biến môi trường và một hằng số dùng chung. Preview deployment sẽ vô tình sinh canonical trỏ về domain thật nếu bạn dùng hằng số cứng.

---

## 3.3. Title

```tsx
// app/layout.tsx — template áp cho MỌI segment con
export const metadata: Metadata = {
  title: {
    default: 'Tên thương hiệu — Giá trị cốt lõi',
    template: '%s | Tên thương hiệu',
  },
}

// app/bai-viet/[slug]/page.tsx
return { title: 'Tiêu đề bài viết' }   // render: "Tiêu đề bài viết | Tên thương hiệu"
```

Bỏ template cho một trang cụ thể:

```tsx
return { title: { absolute: 'Tiêu đề đầy đủ, không ghép thương hiệu' } }
```

**Hướng dẫn viết title:**
| Quy tắc | Giá trị |
| --- | --- |
| Độ dài hiển thị | ~50–60 ký tự (khoảng 580px) |
| Từ khoá chính | Đặt gần đầu |
| Thương hiệu | Ở cuối, sau dấu phân cách |
| Trùng lặp | Mỗi trang phải khác nhau — kiểm tra bằng script |
| Nhồi nhét | Không lặp từ khoá; không "mua ngay rẻ nhất tốt nhất" |
| Clickbait | Không dùng tiêu đề không khớp nội dung |

Google **có thể viết lại** title hiển thị. Để giảm khả năng đó: title ngắn, khớp nội dung, khớp với `<h1>`.

---

## 3.4. Description

```tsx
description: 'Mô tả 140–160 ký tự, nêu lợi ích cụ thể, có chủ thể rõ ràng.'
```

- **Không phải** yếu tố xếp hạng trực tiếp; là yếu tố quyết định CTR.
- Không dùng lại một description cho nhiều trang.
- Google có thể thay bằng đoạn trích từ nội dung.
- Nếu không có description hữu ích, đôi khi tốt hơn là bỏ trống để Google tự trích.

---

## 3.5. Canonical & alternates

```tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const { slug, locale } = await params
  return {
    alternates: {
      canonical: `/san-pham/${slug}`,          // resolve qua metadataBase
      languages: {
        'vi-VN': `/vi/san-pham/${slug}`,
        'en-US': `/en/products/${slug}`,
        'x-default': `/san-pham/${slug}`,       // bắt buộc với đa ngôn ngữ
      },
    },
  }
}
```

| Trường | Ý nghĩa | Lưu ý |
| --- | --- | --- |
| `canonical` | URL chuẩn của trang | Luôn là URL tuyệt đối sau resolve |
| `languages` | Sinh `hreflang` | Phải **đối xứng** giữa các phiên bản |
| `x-default` | Bản mặc định cho người dùng không khớp ngôn ngữ | Nên có khi đa ngôn ngữ |
| `types` | `rel="alternate"` cho RSS | `{ 'application/rss+xml': '/feed.xml' }` |
| `media` | `rel` cho thiết bị | Ít dùng, chỉ cho mobile riêng biệt |

**Bẫy canonical phổ biến:**
- Canonical trỏ về chính nó nhưng URL lại có query param → Google thấy mâu thuẫn.
- Canonical các trang phân trang đều trỏ về trang 1 → Google bỏ luôn các trang sau.
- Canonical trỏ về domain `http://` hoặc `www` khác với domain đang chạy.
- Không có canonical trên trang chi tiết → Google tự chọn bản trùng lặp.

---

## 3.6. Robots (meta robots)

```tsx
export const metadata: Metadata = {
  robots: {
    index: true,
    follow: true,
    nocache: false,
    googleBot: {
      index: true,
      follow: true,
      'max-image-preview': 'large',   // cho phép ảnh lớn trong kết quả
      'max-snippet': -1,              // không giới hạn độ dài snippet
      'max-video-preview': -1,
    },
  },
}
```

**Các directive thường dùng:**

| Directive | Ý nghĩa |
| --- | --- |
| `noindex` | Không đưa vào index (nhưng vẫn crawl) |
| `nofollow` | Không theo link trên trang (Google coi là gợi ý) |
| `noarchive` | Không lưu bản cache |
| `nosnippet` | Không hiện snippet |
| `noimageindex` | Không index ảnh của trang |
| `max-snippet:[n]` | Giới hạn độ dài snippet |
| `max-image-preview:[none/standard/large]` | Kích thước ảnh xem trước — **nên đặt `large`** |
| `unavailable_after:[date]` | Hết hạn sau ngày |

**Bẫy chí mạng:** đặt `robots: { index: false }` ở `app/layout.tsx` để chặn staging ⇒ **cả production bị noindex**. Cách đúng: tách bằng biến môi trường và kiểm tra sau deploy.

```tsx
const isProd = process.env.VERCEL_ENV === 'production'
export const metadata: Metadata = {
  robots: isProd ? undefined : { index: false, follow: false },
}
```

---

## 3.7. Open Graph

```tsx
export const metadata: Metadata = {
  openGraph: {
    type: 'article',
    url: 'https://example.com/bai-viet/abc',
    title: 'Tiêu đề chia sẻ',
    description: 'Mô tả chia sẻ',
    siteName: 'Tên thương hiệu',
    locale: 'vi_VN',
    images: [
      {
        url: '/og/abc.png',        // resolve qua metadataBase
        width: 1200,
        height: 630,
        alt: 'Mô tả ảnh',
        type: 'image/png',
      },
    ],
    publishedTime: '2026-01-01T00:00:00.000Z',
    modifiedTime: '2026-02-01T00:00:00.000Z',
    authors: ['https://example.com/tac-gia/nguyen-van-a'],
    tags: ['seo', 'nextjs'],
  },
}
```

| `type` | Dùng cho |
| --- | --- |
| `website` | Trang chủ, landing |
| `article` | Bài viết (dùng kèm `publishedTime`, `authors`, `tags`) |
| `profile` | Trang tác giả |
| `product` (một số nền tảng) | Sản phẩm |

**Bẫy merge:** metadata của Next được merge **nông** (shallow). Nếu page khai báo `openGraph` mà không có `images`, **ảnh OG của layout gốc bị mất hoàn toàn**. Phải lặp lại `images` ở mọi trang hoặc dùng helper:

```ts
// lib/seo.ts
import type { Metadata } from 'next'

export function buildOgImage(title: string, slug: string) {
  return [{ url: `/api/og?title=${encodeURIComponent(title)}&slug=${slug}`,
            width: 1200, height: 630, alt: title }]
}
```

---

## 3.8. Twitter / X Card

```tsx
twitter: {
  card: 'summary_large_image',
  site: '@thuonghieu',
  creator: '@tacgia',
  title: '...',
  description: '...',
  images: ['/og/abc.png'],
}
```

`card: 'summary_large_image'` cho ảnh lớn — nên dùng mặc định.

---

## 3.9. Icons, manifest, verification, khác

```tsx
export const metadata: Metadata = {
  applicationName: 'Tên app',
  authors: [{ name: 'Nguyễn Văn A', url: 'https://example.com/tac-gia/a' }],
  creator: 'Tên thương hiệu',
  publisher: 'Tên công ty',
  category: 'technology',
  keywords: ['seo', 'next.js'],   // Google bỏ qua; chỉ dùng cho search nội bộ
  referrer: 'origin-when-cross-origin',
  formatDetection: { telephone: false, email: false, address: false },
  verification: {
    google: 'google-site-verification-token',
    other: { 'facebook-domain-verification': ['...'] },
  },
  appleWebApp: { capable: true, title: 'Tên app', statusBarStyle: 'black-translucent' },
  manifest: '/manifest.webmanifest',
  icons: {
    icon: [{ url: '/favicon.ico' }, { url: '/icon.png', type: 'image/png', sizes: '32x32' }],
    apple: [{ url: '/apple-icon.png', sizes: '180x180' }],
    shortcut: ['/shortcut-icon.png'],
  },
}
```

> `keywords`: **không có giá trị SEO** với Google từ lâu. Chỉ giữ nếu có hệ thống tìm kiếm nội bộ dùng đến.

---

## 3.10. Viewport — tách khỏi metadata `[14]`+

`viewport` và `themeColor` **không** còn nằm trong `metadata`:

```tsx
// app/layout.tsx
import type { Viewport } from 'next'

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,          // đừng đặt user-scalable=no — hại a11y
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0a0a0a' },
  ],
  colorScheme: 'light dark',
}
```

**Mobile-first indexing:** Google index bản mobile. Thiếu viewport meta ⇒ Google coi là trang không thân thiện mobile ⇒ ảnh hưởng xếp hạng.

---

## 3.11. Metadata theo loại trang — mẫu tham chiếu

### Trang chủ

```tsx
export const metadata: Metadata = {
  title: { default: 'Thương hiệu — Sản phẩm X cho đối tượng Y', template: '%s | Thương hiệu' },
  description: '...',
  alternates: { canonical: '/' },
  openGraph: { type: 'website', url: '/', images: [{ url: '/og/home.png', width: 1200, height: 630 }] },
}
```

### Chi tiết sản phẩm

```tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const { slug } = await params
  const p = await getProduct(slug)
  if (!p) return {}
  return {
    title: `${p.name} — ${p.brand}`,
    description: truncate(p.shortDescription, 155),
    alternates: { canonical: `/san-pham/${p.slug}` },
    openGraph: {
      type: 'website',
      title: p.name,
      description: truncate(p.shortDescription, 155),
      images: [{ url: p.ogImage ?? '/og/default.png', width: 1200, height: 630, alt: p.name }],
    },
    robots: p.stock === 0 ? { index: false, follow: true } : undefined,
  }
}
```

### Bài viết

```tsx
return {
  title: post.title,
  description: truncate(post.excerpt, 155),
  alternates: { canonical: `/bai-viet/${post.slug}` },
  openGraph: {
    type: 'article',
    publishedTime: post.publishedAt.toISOString(),
    modifiedTime: post.updatedAt.toISOString(),
    authors: [post.author.url],
    images: [{ url: post.cover, width: 1200, height: 630, alt: post.title }],
  },
  twitter: { card: 'summary_large_image', images: [post.cover] },
}
```

### Trang phân trang

```tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const { page } = await params
  return {
    title: page === '1' ? 'Danh mục X' : `Danh mục X — Trang ${page}`,
    description: `...`,
    alternates: { canonical: `/danh-muc?page=${page}` },   // tự canonical, KHÔNG về trang 1
  }
}
```

### Trang cần chặn index

```tsx
export const metadata: Metadata = {
  robots: { index: false, follow: true },   // noindex nhưng vẫn theo link
  title: 'Tìm kiếm',
}
```

---

## 3.12. Metadata động cho OG image

```tsx
// app/api/og/route.tsx
import { ImageResponse } from 'next/og'
import type { NextRequest } from 'next/server'

export const runtime = 'edge'   // hoặc 'nodejs' nếu cần font hệ thống

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const title = (searchParams.get('title') ?? 'Thương hiệu').slice(0, 120)

  return new ImageResponse(
    (
      <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
                    width: '100%', height: '100%', padding: 64, background: '#0a0a0a', color: '#fff' }}>
        <div style={{ fontSize: 64, lineHeight: 1.1 }}>{title}</div>
        <div style={{ fontSize: 28, opacity: 0.7 }}>example.com</div>
      </div>
    ),
    { width: 1200, height: 630 },
  )
}
```

Hoặc dùng file convention `opengraph-image.tsx` (xem file 04) để Next tự sinh thẻ `og:image` — ít lỗi hơn.

---

## 3.13. Kiểm tra metadata sau khi build

```bash
# Chạy production build cục bộ rồi kiểm tra HTML thô
npm run build && npm run start &
sleep 5
for url in / /san-pham/abc /bai-viet/xyz; do
  echo "=== $url"
  curl -s "http://localhost:3000$url" | grep -Eo '<title>[^<]*</title>'
  curl -s "http://localhost:3000$url" | grep -Eo '<link rel="canonical"[^>]*>'
  curl -s "http://localhost:3000$url" | grep -Eo '<meta property="og:image"[^>]*>'
done
```

---

## 3.14. Checklist metadata

- [ ] `metadataBase` đặt ở `app/layout.tsx`, đọc từ env
- [ ] `title.template` + `title.default` đã cấu hình ở layout gốc
- [ ] Mọi trang có title riêng, không trùng (kiểm tra bằng script)
- [ ] Mọi trang có description riêng, 140–160 ký tự
- [ ] Canonical có mặt trên **mọi** trang index được, đúng domain/HTTPS
- [ ] `openGraph.images` có ở mọi trang (nhớ bẫy merge nông)
- [ ] OG image đúng 1200×630, có `alt`
- [ ] `twitter.card = 'summary_large_image'`
- [ ] `viewport` export riêng, không đặt trong `metadata`
- [ ] `robots.googleBot['max-image-preview'] = 'large'`
- [ ] Không có `robots: noindex` rò rỉ vào production
- [ ] `alternates.languages` đối xứng nếu đa ngôn ngữ
- [ ] `verification.google` đã đặt (hoặc xác minh qua DNS)
- [ ] Không dùng `metadata` trong Client Component
- [ ] Không export đồng thời `metadata` và `generateMetadata`
- [ ] `params`/`searchParams` được `await` trong `generateMetadata`
