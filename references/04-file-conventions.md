# 04 — File Conventions: sitemap, robots, OG image, feed

App Router cho phép sinh các file SEO bằng code TypeScript thay vì đặt file tĩnh. Lợi ích: dữ liệu luôn đồng bộ với database.

---

## 4.1. Bảng file convention

| File | Sinh ra | Bắt buộc? |
| --- | --- | --- |
| `app/robots.ts` | `/robots.txt` | Nên có |
| `app/sitemap.ts` | `/sitemap.xml` | **Bắt buộc** |
| `app/manifest.ts` | `/manifest.webmanifest` | Nên có (PWA/mobile) |
| `app/icon.png` / `app/icon.tsx` | favicon | Bắt buộc |
| `app/apple-icon.png` | apple-touch-icon | Nên có |
| `app/opengraph-image.tsx` | `og:image` tự động | Rất nên có |
| `app/twitter-image.tsx` | `twitter:image` | Tuỳ |
| `app/not-found.tsx` | Trang 404 | **Bắt buộc** |
| `app/feed.xml/route.ts` | RSS | Nên có nếu có blog |

> **Xung đột:** không được tồn tại đồng thời `app/robots.ts` và `public/robots.txt` (tương tự với sitemap). Next sẽ báo lỗi hoặc một cái bị bỏ qua.

---

## 4.2. `robots.ts`

```ts
// app/robots.ts
import type { MetadataRoute } from 'next'

const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/api/',
          '/admin/',
          '/tai-khoan/',
          '/gio-hang/',
          '/thanh-toan/',
          '/tim-kiem',
          '/*?utm_',
          '/*?sort=',
          '/*?filter=',
        ],
      },
      { userAgent: 'GPTBot', allow: '/' },          // cho AI crawler nếu muốn xuất hiện trong AI answers
      { userAgent: 'CCBot', disallow: '/' },        // chặn crawler dùng để train
      { userAgent: 'AhrefsBot', crawlDelay: 10 },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
    host: baseUrl,
  }
}
```

**Lưu ý:**
- `disallow` hỗ trợ `*` (wildcard) và `$` (kết thúc), **không** hỗ trợ regex.
- `crawlDelay` bị Google **bỏ qua** (chỉ Bing/Yandex dùng).
- **Không** `Disallow` `/api/og` nếu OG image sinh qua route handler cần cho bot mạng xã hội — thực tế nên `Allow`.
- **Không bao giờ** chặn `/_next/static/`, `/_next/image`, `*.js`, `*.css` — Googlebot cần chúng để render.

### robots.txt cho môi trường non-production

```ts
export default function robots(): MetadataRoute.Robots {
  if (process.env.VERCEL_ENV !== 'production') {
    return { rules: [{ userAgent: '*', disallow: '/' }] }
  }
  return { /* ...như trên */ }
}
```

---

## 4.3. `sitemap.ts`

```ts
// app/sitemap.ts
import type { MetadataRoute } from 'next'

const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

export const revalidate = 3600   // tái tạo sitemap mỗi giờ

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [posts, products, categories] = await Promise.all([
    getPosts(), getProducts(), getCategories(),
  ])

  return [
    { url: `${baseUrl}/`, lastModified: new Date(), changeFrequency: 'daily', priority: 1 },
    ...categories.map((c) => ({
      url: `${baseUrl}/danh-muc/${c.slug}`,
      lastModified: c.updatedAt,
      changeFrequency: 'weekly' as const,
      priority: 0.8,
    })),
    ...products.map((p) => ({
      url: `${baseUrl}/san-pham/${p.slug}`,
      lastModified: p.updatedAt,
      changeFrequency: 'daily' as const,
      priority: 0.7,
      images: [ `${baseUrl}${p.image}` ],      // image sitemap
    })),
    ...posts.map((p) => ({
      url: `${baseUrl}/bai-viet/${p.slug}`,
      lastModified: p.updatedAt,
      changeFrequency: 'monthly' as const,
      priority: 0.6,
    })),
  ]
}
```

### Quy tắc sitemap đúng

| Quy tắc | Chi tiết |
| --- | --- |
| Chỉ chứa URL canonical | Không chứa URL `noindex`, không chứa URL redirect |
| Chỉ chứa URL trả 200 | Kiểm tra tự động trước khi publish |
| URL tuyệt đối | `metadataBase` **không** áp dụng cho sitemap — phải tự nối domain |
| `lastModified` phải thật | Đừng đặt `new Date()` cho mọi URL; Google bỏ qua nếu thấy sai |
| `priority` / `changeFrequency` | Google **bỏ qua**; giữ để tương thích công cụ khác, đừng tối ưu theo nó |
| Giới hạn | 50.000 URL và 50MB (chưa nén) mỗi file |
| Không dùng để "nhờ index" | Sitemap là kênh discovery, không phải lệnh index |

### ⚠️ Static export (`output: 'export'`) làm hỏng build nếu thiếu `force-static`

Đã kiểm chứng trên Next.js 15.1.6. Nếu `next.config` có `output: 'export'` và bạn dùng `app/sitemap.js` hoặc `app/robots.js`, build **thất bại** với thông báo rất khó hiểu:

```
Error: export const dynamic = "force-static"/export const revalidate not configured
on route "/sitemap.xml" with "output: export".
```

Lý do: sitemap và robots là **Route Handler**; ở chế độ static export mọi Route Handler phải tĩnh một cách tường minh. Cách sửa — thêm một dòng vào đầu mỗi file:

```ts
// app/sitemap.ts
export const dynamic = 'force-static'   // BẮT BUỘC khi output: 'export'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // ...
}
```

```ts
// app/robots.ts
export const dynamic = 'force-static'   // BẮT BUỘC khi output: 'export'

export default function robots(): MetadataRoute.Robots {
  // ...
}
```

> Nếu không cần sinh động, phương án khác là bỏ hẳn file convention và đặt `public/sitemap.xml` + `public/robots.txt` tĩnh — nhưng khi đó phải tự cập nhật thủ công.
>
> Lưu ý: `output: 'export'` **không** cho phép `generateSitemaps` (chia sitemap) vì cần route động.

### Kiểm tra sau khi build

```bash
# App Router
node <SKILL_DIR>/scripts/check-seo.mjs .next/server/app
# Pages Router
node <SKILL_DIR>/scripts/check-seo.mjs .next/server/pages
# HYBRID (app/ + pages/): truyền CẢ HAI để bắt được title trùng giữa hai router
node <SKILL_DIR>/scripts/check-seo.mjs .next/server/app .next/server/pages
# Static export
node <SKILL_DIR>/scripts/check-seo.mjs out
```

### Chia nhỏ sitemap với `generateSitemaps`

Khi vượt 50k URL:

```ts
// app/sitemap.ts
export async function generateSitemaps() {
  const count = await getProductCount()
  const chunks = Math.ceil(count / 50000)
  return Array.from({ length: chunks }, (_, id) => ({ id }))
}

export default async function sitemap({ id }: { id: number }): Promise<MetadataRoute.Sitemap> {
  const products = await getProductsPage(id, 50000)
  return products.map((p) => ({
    url: `https://example.com/san-pham/${p.slug}`,
    lastModified: p.updatedAt,
  }))
}
```

Next sinh `/sitemap/0.xml`, `/sitemap/1.xml`… và một sitemap index tự động.

### Sitemap chuyên biệt

Có thể đặt ở route handler khi cần kiểm soát XML thô (news, video):

```ts
// app/sitemap-news.xml/route.ts
export async function GET() {
  const articles = await getRecentArticles(48)   // 48h gần nhất
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:news="http://www.google.com/schemas/sitemap-news/0.9">
${articles.map((a) => `  <url>
    <loc>https://example.com/bai-viet/${a.slug}</loc>
    <news:news>
      <news:publication><news:name>Thương hiệu</news:name><news:language>vi</news:language></news:publication>
      <news:publication_date>${a.publishedAt.toISOString()}</news:publication_date>
      <news:title>${escapeXml(a.title)}</news:title>
    </news:news>
  </url>`).join('\n')}
</urlset>`
  return new Response(xml, { headers: { 'Content-Type': 'application/xml' } })
}
```

Nhớ khai báo trong `robots.ts`: `sitemap: [base + '/sitemap.xml', base + '/sitemap-news.xml']`.

---

## 4.4. `manifest.ts` (PWA)

```ts
// app/manifest.ts
import type { MetadataRoute } from 'next'

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Tên đầy đủ',
    short_name: 'Tên ngắn',
    description: '...',
    start_url: '/',
    display: 'standalone',
    background_color: '#0a0a0a',
    theme_color: '#0a0a0a',
    lang: 'vi',
    icons: [
      { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
      { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
      { src: '/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  }
}
```

Manifest không ảnh hưởng xếp hạng trực tiếp nhưng ảnh hưởng khả năng cài đặt và tín hiệu chất lượng mobile.

---

## 4.5. `opengraph-image.tsx`

Next tự sinh `<meta property="og:image">` trỏ tới ảnh này. Cách này ít lỗi hơn route handler thủ công.

```tsx
// app/bai-viet/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'
import { getPost } from '@/lib/posts'

export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'
export const alt = 'Ảnh chia sẻ bài viết'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)

  return new ImageResponse(
    (
      <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
                    width: '100%', height: '100%', padding: 64,
                    background: 'linear-gradient(135deg,#0a0a0a,#1a1a2e)', color: '#fff' }}>
        <div style={{ fontSize: 56, fontWeight: 700, lineHeight: 1.15 }}>{post.title}</div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 26, opacity: 0.75 }}>
          <span>example.com</span>
          <span>{post.author.name}</span>
        </div>
      </div>
    ),
    { ...size },
  )
}
```

Có biến thể `twitter-image.tsx`, `icon.tsx`, `apple-icon.tsx`.

> **Lưu ý font tiếng Việt:** `ImageResponse` mặc định không có đủ glyph tiếng Việt trong một số font. Nếu ảnh OG có dấu tiếng Việt bị lỗi ô vuông, phải nạp font tường minh:
> ```tsx
> const font = await fetch(new URL('@/assets/Inter-SemiBold.ttf', import.meta.url)).then(r => r.arrayBuffer())
> // truyền vào: { ..., fonts: [{ name: 'Inter', data: font, style: 'normal', weight: 600 }] }
> ```

---

## 4.6. `not-found.tsx`

```tsx
// app/not-found.tsx
import Link from 'next/link'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Không tìm thấy trang',
  robots: { index: false, follow: true },
}

export default function NotFound() {
  return (
    <main>
      <h1>Không tìm thấy trang</h1>
      <p>Trang bạn tìm có thể đã được chuyển hoặc không còn tồn tại.</p>
      <nav>
        <Link href="/">Về trang chủ</Link>
        <Link href="/san-pham">Xem sản phẩm</Link>
        <Link href="/bai-viet">Đọc bài viết</Link>
      </nav>
    </main>
  )
}
```

**Nguyên tắc trang 404 tốt:** trả status 404 đúng, `noindex`, có link điều hướng hữu ích, không tự redirect về trang chủ (gây soft 404).

---

## 4.7. RSS feed

```ts
// app/feed.xml/route.ts
import { getPosts } from '@/lib/posts'

const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

export const revalidate = 3600

export async function GET() {
  const posts = await getPosts(50)
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Blog Thương hiệu</title>
    <link>${baseUrl}</link>
    <description>...</description>
    <language>vi</language>
    <atom:link href="${baseUrl}/feed.xml" rel="self" type="application/rss+xml"/>
${posts.map((p) => `    <item>
      <title>${escapeXml(p.title)}</title>
      <link>${baseUrl}/bai-viet/${p.slug}</link>
      <guid isPermaLink="true">${baseUrl}/bai-viet/${p.slug}</guid>
      <pubDate>${p.publishedAt.toUTCString()}</pubDate>
      <description>${escapeXml(p.excerpt)}</description>
    </item>`).join('\n')}
  </channel>
</rss>`
  return new Response(xml, { headers: { 'Content-Type': 'application/rss+xml; charset=utf-8' } })
}
```

Khai báo trong metadata layout để sinh `<link rel="alternate">`:

```ts
alternates: { types: { 'application/rss+xml': `${baseUrl}/feed.xml` } }
```

---

## 4.8. `next.config.ts` — redirects, rewrites, headers

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  poweredByHeader: false,
  trailingSlash: false,          // chốt một hướng duy nhất cho toàn site
  compress: true,
  images: {
    formats: ['image/avif', 'image/webp'],
    remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com' }],
    minimumCacheTTL: 2592000,    // 30 ngày
  },
  async redirects() {
    return [
      { source: '/blog/:slug*', destination: '/bai-viet/:slug*', permanent: true },
      { source: '/:path*', has: [{ type: 'host', value: 'www.example.com' }],
        destination: 'https://example.com/:path*', permanent: true },
    ]
  },
  async headers() { /* xem file 01 và 02 */ },
}

export default nextConfig
```

**Thứ tự ưu tiên redirect:** `next.config` redirects chạy **trước** middleware/proxy và trước khi render → rẻ nhất. Ưu tiên dùng nó cho redirect hàng loạt.

---

## 4.9. Checklist file conventions

- [ ] `app/sitemap.ts` tồn tại, chỉ chứa URL canonical trả 200
- [ ] `app/robots.ts` tồn tại, trỏ tới sitemap, không chặn asset
- [ ] Không tồn tại song song file tĩnh và file convention
- [ ] Non-production trả `Disallow: /` + `noindex`
- [ ] `app/not-found.tsx` có `noindex` và link điều hướng
- [ ] `opengraph-image` đã có ở layout gốc và các mẫu trang chính
- [ ] OG image đúng 1200×630, render đúng tiếng Việt có dấu
- [ ] `app/icon.*` và `apple-icon.*` tồn tại
- [ ] `manifest.ts` có `name`, `icons` (gồm maskable), `start_url`
- [ ] RSS tồn tại nếu có blog, đã khai báo trong `alternates.types`
- [ ] `trailingSlash` đã chốt và nhất quán với canonical
- [ ] `poweredByHeader: false`
- [ ] Redirect cấu hình ở `next.config`, không ở component
- [ ] Sitemap đã submit vào Search Console và Bing Webmaster Tools
