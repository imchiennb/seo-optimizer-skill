# 02 — Rendering & Caching: chọn chiến lược theo loại trang

Đây là chủ điểm **đặc thù Next.js nhất** và cũng là nơi quyết định SEO nhiều nhất.

---

## 2.1. Bốn chiến lược cơ bản

| Chiến lược | HTML sinh khi nào | TTFB | Độ tươi dữ liệu | SEO |
| --- | --- | --- | --- | --- |
| **SSG** (Static) | Build time | Rất thấp (CDN) | Cũ đến lần build sau | ⭐⭐⭐⭐⭐ |
| **ISR** (Incremental Static Regeneration) | Build + revalidate nền | Rất thấp (CDN) | Cấu hình được | ⭐⭐⭐⭐⭐ |
| **SSR** (Dynamic) | Mỗi request | Phụ thuộc backend | Tức thời | ⭐⭐⭐⭐ |
| **CSR** (Client-only) | Trong trình duyệt | Thấp nhưng nội dung trễ | Tức thời | ⭐ (rủi ro cao) |
| **PPR / Cache Components** `[16]` | Shell tĩnh + phần động stream | Rất thấp | Hỗn hợp | ⭐⭐⭐⭐⭐ |

**Nguyên tắc chọn:** mặc định nghiêng về static. Chỉ chuyển sang dynamic khi thực sự cần dữ liệu theo request (giỏ hàng, tài khoản, giá realtime, A/B test).

---

## 2.2. Bảng quyết định theo loại trang

| Loại trang | Khuyến nghị | Lý do |
| --- | --- | --- |
| Trang chủ | SSG + ISR (`revalidate` 1h) | Ít đổi, cần nhanh |
| Landing page marketing | SSG | Tốc độ tối đa |
| Danh mục sản phẩm | SSG + ISR ngắn (5–15 phút) | Đổi thường xuyên nhưng chấp nhận trễ |
| Chi tiết sản phẩm | SSG + ISR + on-demand revalidate khi admin sửa | Vừa nhanh vừa tươi |
| Bài blog | SSG | Nội dung gần như bất biến |
| Trang giá | SSG + revalidate theo webhook | |
| Kết quả tìm kiếm | Dynamic + `noindex` | Không có giá trị index |
| Trang tài khoản / giỏ hàng | Dynamic + `noindex` | Riêng tư |
| Dashboard realtime | Dynamic + `noindex` | |
| Trang `[...slug]` CMS | SSG + ISR | |
| Trang i18n | SSG theo locale (`generateStaticParams`) | |

---

## 2.3. Cú pháp route segment config

```tsx
// app/bai-viet/[slug]/page.tsx

// Bắt buộc static; fetch động sẽ gây lỗi build → phát hiện sớm
export const dynamic = 'force-static'

// ISR: tái tạo nền sau 3600s
export const revalidate = 3600

// Không cho param lạ sinh trang mới
export const dynamicParams = false

// Hoặc ép động hoàn toàn (chỉ dùng khi thực sự cần)
// export const dynamic = 'force-dynamic'

// Chỉ định rõ chế độ cache của fetch trong segment
// export const fetchCache = 'default-cache'
```

`generateStaticParams` để prerender toàn bộ URL hợp lệ:

```tsx
export async function generateStaticParams() {
  const posts = await getAllPosts()
  return posts.map((p) => ({ slug: p.slug }))
}
```

> **Lưu ý `[15]`+:** `params` và `searchParams` trong `page`/`layout`/`generateMetadata` là **Promise**, phải `await`. Quên `await` là lỗi phổ biến nhất khi nâng cấp và có thể làm metadata rỗng.

---

## 2.4. Cache Components & PPR `[16]`

Next.js 16 thay mô hình cache ngầm bằng cơ chế **opt-in**:

```ts
// next.config.ts
const nextConfig = {
  cacheComponents: true,   // bật Cache Components (bao gồm PPR)
}
export default nextConfig
```

```tsx
// app/san-pham/[slug]/page.tsx
import { Suspense } from 'react'
import { cacheLife, cacheTag } from 'next/cache'

async function ProductInfo({ slug }: { slug: string }) {
  'use cache'
  cacheLife('hours')
  cacheTag(`product-${slug}`)
  const product = await getProduct(slug)
  return <Detail product={product} />
}

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  return (
    <main>
      {/* Shell tĩnh, prerender tại build */}
      <Hero />
      {/* Phần động stream vào sau */}
      <Suspense fallback={<Skeleton />}>
        <ProductInfo slug={slug} />
      </Suspense>
    </main>
  )
}
```

**Ý nghĩa SEO:** shell tĩnh giữ TTFB và LCP thấp; phần động vẫn tươi. Với Googlebot, nội dung trong Suspense vẫn nằm trong HTML stream (trừ khi chỉ render client).

> `[16]` `experimental.ppr` đã bị loại bỏ, thay bằng `cacheComponents`. Đừng copy cấu hình PPR cũ từ blog.

### Invalidation

```ts
import { revalidateTag, revalidatePath, updateTag } from 'next/cache'

revalidateTag('product-123')      // theo tag
revalidatePath('/san-pham/123')   // theo path
updateTag('product-123')          // [16] cập nhật tức thời cho read-your-own-writes
```

Gọi từ Route Handler làm webhook cho CMS:

```ts
// app/api/revalidate/route.ts
import { revalidateTag } from 'next/cache'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const secret = req.headers.get('x-revalidate-secret')
  if (secret !== process.env.REVALIDATE_SECRET) {
    return NextResponse.json({ ok: false }, { status: 401 })
  }
  const { tag } = await req.json()
  revalidateTag(tag)
  return NextResponse.json({ ok: true, revalidated: tag })
}
```

**Đây là mô hình đúng cho site thương mại:** static + on-demand revalidate. Không cần `force-dynamic` để có dữ liệu tươi.

---

## 2.5. Server Component vs Client Component

Đây là quyết định ảnh hưởng trực tiếp đến lượng JS gửi xuống và do đó đến INP/LCP.

| Tiêu chí | Server Component (mặc định) | Client Component (`'use client'`) |
| --- | --- | --- |
| Trong HTML thô | ✅ Có | ✅ Có (nhưng cần JS để tương tác) |
| Gửi JS xuống client | Không (chỉ RSC payload) | Có |
| Dùng `useState`, `useEffect`, event handler | ❌ | ✅ |
| Dùng `async/await` trực tiếp | ✅ | ❌ |
| Truy cập DB/secret | ✅ | ❌ |
| Xuất `metadata` / `generateMetadata` | ✅ | ❌ **Không được** |

**Quy tắc vàng:** đẩy `'use client'` xuống **lá** của cây component, không đặt ở `layout.tsx` hay ở component bao ngoài trang.

```tsx
// ❌ Sai: biến cả trang thành client, mất metadata, tăng bundle
'use client'
export default function Page() { /* ... */ }

// ✅ Đúng: chỉ phần tương tác là client
import LikeButton from './LikeButton'   // file này có 'use client'
export default async function Page() {
  const data = await getData()
  return <article>{data.body}<LikeButton id={data.id} /></article>
}
```

**Bao bọc client component bằng `dynamic()` khi không cần thiết ở lần paint đầu:**

```tsx
import dynamic from 'next/dynamic'
const ChatWidget = dynamic(() => import('@/components/ChatWidget'), { ssr: false })
```

---

## 2.6. Streaming, Suspense, `loading.tsx` và metadata

- `loading.tsx` tạo một Suspense boundary ở cấp segment → phần trên stream ngay, phần dưới bù sau.
- **Metadata streaming** `[15.2+]`: `generateMetadata` chạy song song với render trang thay vì chặn. Với bot không thực thi JS, Next.js sẽ chờ metadata xong mới gửi HTML (hành vi có thể tinh chỉnh qua `htmlLimitedBots`).
- **Rủi ro:** nếu metadata phụ thuộc một fetch chậm, TTFB của bot bị đẩy lên dù người dùng thấy nhanh. Giữ `generateMetadata` **nhẹ**: chỉ gọi những gì cần cho title/description/OG.
- Dùng `cache()` của React để dedupe fetch giữa `generateMetadata` và `page`:

```tsx
import { cache } from 'react'

const getPost = cache(async (slug: string) => {
  return await db.post.findUnique({ where: { slug } })
})

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  return { title: post.title, description: post.excerpt }
}

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)   // không fetch lần hai
  return <Article post={post} />
}
```

---

## 2.7. Static export (`output: 'export'`)

Chỉ dùng khi host không hỗ trợ Node (S3, GitHub Pages…). Đánh đổi:

| Mất | Ảnh hưởng SEO |
| --- | --- |
| ISR / on-demand revalidate | Nội dung chỉ tươi khi build lại |
| Route Handler động, `ImageResponse` runtime | Không sinh OG image động |
| `next/image` optimizer mặc định | Phải `images.unoptimized: true` → mất tối ưu ảnh |
| Middleware/proxy redirect | Phải xử lý redirect ở host |
| Header tuỳ biến | Không set được `X-Robots-Tag`, cache header |
| Sitemap/robots dạng route handler | Build **thất bại** nếu thiếu `export const dynamic = 'force-static'` — xem [04-file-conventions.md](04-file-conventions.md) |
| `generateSitemaps` (chia sitemap) | Không dùng được — cần route động |

Nếu chọn static export, phải cấu hình `trailingSlash` phù hợp host và tự lo sitemap/redirect ở tầng CDN.

> Đã kiểm chứng trên Next.js 15.1.6: output static export nằm ở `out/`, và với `trailingSlash: true` mỗi trang thành `<path>/index.html` (ví dụ `san-pham/abc/index.html`). Trang 404 sinh ra **cả** `404.html` **và** `404/index.html`.

```ts
const nextConfig = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
}
```

---

## 2.8. Self-host: cache header & CDN

Khi không deploy trên Vercel, phải tự đặt cache header đúng, nếu không TTFB sẽ phá mọi nỗ lực khác.

```ts
// next.config.ts
async headers() {
  return [
    {
      // Asset có hash: cache vĩnh viễn
      source: '/_next/static/:path*',
      headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
    },
    {
      // Ảnh đã tối ưu
      source: '/_next/image:path*',
      headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
    },
    {
      // HTML: để CDN cache ngắn + stale-while-revalidate
      source: '/:path*',
      headers: [{ key: 'Cache-Control', value: 'public, max-age=0, s-maxage=3600, stale-while-revalidate=86400' }],
    },
  ]
}
```

> **Bẫy:** cache HTML ở CDN quá lâu mà không có cơ chế purge ⇒ nội dung cũ. Với ISR, ưu tiên để Next quản lý; chỉ tự đặt header khi thật sự hiểu tác động.

---

## 2.9. Anti-pattern rendering

| Anti-pattern | Hậu quả | Cách sửa |
| --- | --- | --- |
| `force-dynamic` trên toàn site | TTFB cao, mất lợi thế CDN | Static + ISR + revalidate theo webhook |
| `'use client'` ở `app/layout.tsx` hoặc `page.tsx` | Mất `metadata`, bundle phình | Đẩy xuống component lá |
| Fetch dữ liệu chính trong `useEffect` | Googlebot đợt 1 thấy trang rỗng | Fetch trong Server Component |
| `ssr: false` cho component chứa nội dung | Nội dung không có trong HTML | Chỉ dùng cho widget phụ |
| `dynamicParams` mặc định ở route `[slug]` | Không gian URL vô hạn | `dynamicParams = false` |
| Suspense boundary bao trùm toàn trang | Mất LCP, layout shift | Đặt boundary hẹp quanh phần động |
| `loading.tsx` trả skeleton thay cả nội dung SEO | Bot đọc được skeleton | Chỉ skeleton phần động |
| Không `await params` `[15]`+ | Metadata rỗng, 404 sai | `const { slug } = await params` |
| Prerender hàng trăm nghìn URL | Build timeout | `generateSitemaps` chia nhỏ, hoặc ISR on-demand |
| Gọi `revalidatePath` trong vòng lặp lớn | Nghẽn server | Dùng `revalidateTag` theo entity |

---

## 2.10. Checklist rendering

- [ ] Mỗi loại trang đã được gán chiến lược render có chủ đích (ghi trong tài liệu dự án)
- [ ] Trang nội dung công khai **không** dùng `force-dynamic`
- [ ] `params`/`searchParams` đều được `await`
- [ ] `generateMetadata` không thực hiện fetch nặng; đã dùng `cache()` để dedupe
- [ ] `'use client'` chỉ nằm ở component lá
- [ ] Mọi nội dung quan trọng có trong HTML thô (`curl` kiểm chứng)
- [ ] Có webhook revalidate nối từ CMS/admin
- [ ] `dynamicParams = false` ở các dynamic route hữu hạn
- [ ] Cache header đúng cho `/_next/static`, `/_next/image`, HTML
- [ ] Nếu static export: đã chấp nhận đánh đổi và tự lo redirect/header
