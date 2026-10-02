# 07 — Hiệu năng & Core Web Vitals

Next.js cho sẵn công cụ tốt, nhưng mặc định vẫn có thể chậm nếu dùng sai.

---

## 7.1. Ngưỡng Core Web Vitals

| Chỉ số | Tốt | Cần cải thiện | Kém | Đo ở |
| --- | --- | --- | --- | --- |
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | 2.5–4.0s | > 4.0s | Phân vị 75, cả mobile & desktop |
| **INP** (Interaction to Next Paint) | ≤ 200ms | 200–500ms | > 500ms | Phân vị 75 |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | 0.1–0.25 | > 0.25 | Phân vị 75 |

Bổ sung: **TTFB** ≤ 0.8s (khuyến nghị), **FCP** ≤ 1.8s.

> INP đã thay FID từ tháng 3/2024. Đừng tối ưu FID nữa.

**Lưu ý:** CWV là tín hiệu xếp hạng **yếu**. Nội dung và intent quan trọng hơn. Nhưng CWV kém ảnh hưởng trực tiếp đến tỷ lệ thoát và chuyển đổi — đó mới là lý do thật để tối ưu.

---

## 7.2. Ảnh — nguồn gây LCP và CLS lớn nhất

### `next/image` — dùng đúng

```tsx
import Image from 'next/image'

// Ảnh LCP (hero, ảnh sản phẩm đầu tiên) — CHỈ MỘT ảnh priority mỗi trang
<Image
  src="/hero.webp"
  alt="Mô tả cụ thể"
  width={1600}
  height={900}
  priority
  sizes="100vw"
  quality={80}
/>

// Ảnh trong grid — luôn khai báo sizes
<Image
  src={product.image}
  alt={product.name}
  width={600}
  height={600}
  sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"
/>

// Ảnh fill trong container có tỷ lệ xác định
<div className="relative aspect-[16/9]">
  <Image src="/cover.jpg" alt="" fill sizes="(max-width: 768px) 100vw, 50vw" className="object-cover" />
</div>
```

### Quy tắc

| Quy tắc | Lý do |
| --- | --- |
| Luôn khai báo `width`/`height` hoặc `fill` trong container có tỷ lệ | Chống CLS |
| `priority` cho **đúng một** ảnh LCP | Nhiều `priority` làm nghẽn network |
| `sizes` cho mọi ảnh responsive | Không có `sizes` ⇒ tải ảnh full-width |
| `quality` 70–85 | Trên 85 gần như không khác biệt về mắt |
| `loading="lazy"` mặc định cho ảnh dưới màn hình | Không lazy ảnh LCP |
| Dùng AVIF/WebP | Giảm 25–50% dung lượng |
| `alt` mô tả thật | A11y + image SEO |
| `placeholder="blur"` với `blurDataURL` | Cải thiện cảm nhận, giảm CLS cảm tính |
| Không dùng `<img>` thô cho ảnh nội dung | Mất tối ưu |

### Cấu hình

```ts
// next.config.ts
const nextConfig = {
  images: {
    formats: ['image/avif', 'image/webp'],
    remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com' }],
    minimumCacheTTL: 2592000,
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  },
}
```

> `[16]` một số mặc định của `next/image` đã thay đổi (chất lượng, kích thước, TTL). Đọc release note khi nâng cấp để tránh thay đổi ngoài ý muốn.

---

## 7.3. Font

Font là nguyên nhân phổ biến của CLS và chậm render.

```tsx
// app/layout.tsx
import { Inter, Be_Vietnam_Pro } from 'next/font/google'

const inter = Inter({
  subsets: ['latin', 'vietnamese'],   // BẮT BUỘC có 'vietnamese' cho tiếng Việt
  display: 'swap',
  variable: '--font-inter',
  preload: true,
})

export default function RootLayout({ children }) {
  return (
    <html lang="vi" className={inter.variable}>
      <body>{children}</body>
    </html>
  )
}
```

| Quy tắc | Lý do |
| --- | --- |
| Dùng `next/font` (self-host, không request tới Google) | Loại bỏ DNS/TLS tới fonts.googleapis.com |
| `subsets` gồm `vietnamese` | Thiếu ⇒ font fallback, CLS, chữ lỗi |
| `display: 'swap'` | Chữ hiện ngay bằng font hệ thống |
| Tối đa 2 họ font, 3–4 weight | Mỗi weight là một file |
| Không dùng `@import` trong CSS | Chặn render |
| Cân nhắc `adjustFontFallback` (mặc định bật) | Giảm CLS khi swap |

Với font local:

```tsx
import localFont from 'next/font/local'
const brand = localFont({
  src: [{ path: './fonts/Brand.woff2', weight: '400', style: 'normal' }],
  display: 'swap',
  variable: '--font-brand',
})
```

---

### ⚠️ Đừng mặc định rằng thiếu subset `vietnamese` là lỗi

Nhiều font đã bao gồm glyph tiếng Việt trong subset `latin` — đặc biệt các font
làm riêng cho tiếng Việt như **Be Vietnam Pro**. Cảnh báo "thiếu subset
vietnamese" của `detect-project.sh` chỉ là **gợi ý**, không phải kết luận.

Kiểm chứng bằng thực nghiệm, đừng suy đoán:

```bash
# 1. Đếm file font TRƯỚC
find .next/static/media -name '*.woff2' | wc -l
du -sb .next/static/media

# 2. Thêm 'vietnamese' vào subsets rồi build lại
# 3. Đếm LẠI — nếu số file và dung lượng không đổi thì subset đó là thừa
```

Ca thật: một site tiếng Việt dùng Be Vietnam Pro với `subsets: ['latin']` bị
gắn cờ. Sau khi thêm `'vietnamese'`, số file woff2 và dung lượng **không đổi
một byte** (12 file, 99,0 KB) → kết luận: cảnh báo là **false positive**, và
thay đổi đó đã được revert thay vì ship kèm một lời giải thích sai.

> Bài học chung: một heuristic trong script có thể sai. Khi nó buộc tội, hãy
> kiểm chứng trước khi sửa — và nếu heuristic sai thì sửa **heuristic**, không
> phải sửa code cho vừa lòng nó.

## 7.4. Script bên thứ ba

```tsx
import Script from 'next/script'

// Analytics — afterInteractive (mặc định), không chặn
<Script src="https://www.googletagmanager.com/gtag/js?id=G-XXXX" strategy="afterInteractive" />

// Script không cần sớm — lazyOnload
<Script src="https://widget.example.com/chat.js" strategy="lazyOnload" />

// Script phải chạy trước hydration (hiếm) — beforeInteractive, đặt trong layout gốc
<Script src="/critical.js" strategy="beforeInteractive" />
```

| `strategy` | Khi chạy | Dùng cho |
| --- | --- | --- |
| `beforeInteractive` | Trước hydration | Polyfill, consent manager (hạn chế tối đa) |
| `afterInteractive` | Sau hydration | Analytics, tag manager |
| `lazyOnload` | Lúc idle | Chat widget, social embed, heatmap |

**Kiểm soát bên thứ ba:**
- Mỗi script bên thứ ba là một rủi ro INP. Đo tác động trước khi thêm (Lighthouse "Reduce the impact of third-party code").
- Dùng `@next/third-parties` cho GA/GTM/YouTube — tối ưu sẵn:

```tsx
import { GoogleAnalytics, GoogleTagManager, YouTubeEmbed } from '@next/third-parties/google'
<GoogleAnalytics gaId="G-XXXX" />
<YouTubeEmbed videoid="..." params="controls=0" />
```

- Facade cho embed nặng: hiện ảnh thumbnail, chỉ nạp iframe khi click.

---

## 7.5. Bundle JavaScript

```bash
# Đo bundle
ANALYZE=true npm run build     # với @next/bundle-analyzer

# Kiểm tra dung lượng tải thực tế
npx lighthouse https://example.com --preset=desktop --view
```

| Kỹ thuật | Cách làm |
| --- | --- |
| Đẩy `'use client'` xuống lá | Giảm JS gửi xuống |
| `next/dynamic` cho component nặng | `dynamic(() => import('./Heavy'), { ssr: false })` |
| Import có chọn lọc | `import { map } from 'lodash-es'` thay vì `import _ from 'lodash'` |
| `optimizePackageImports` | Tự động tree-shake thư viện UI lớn |
| Load chart/editor khi cần | Chỉ import trong route cần |
| Tránh polyfill không cần | Cấu hình `browserslist` hợp lý |
| Kiểm tra dependency phình | `npx depcheck`, soát `package.json` định kỳ |

```ts
// next.config.ts
const nextConfig = {
  experimental: {
    optimizePackageImports: ['lucide-react', '@heroicons/react', 'date-fns', 'recharts'],
  },
}
```

**Ngân sách đề xuất:** JS tải lần đầu ≤ 150KB gzip cho trang nội dung; ≤ 350KB cho app tương tác.

---

## 7.6. TTFB, caching, hosting

TTFB ảnh hưởng trực tiếp LCP. Các yếu tố:

| Yếu tố | Hành động |
| --- | --- |
| Server gần người dùng | CDN edge, chọn region phù hợp |
| Truy vấn DB chậm | Index DB, tránh N+1, dùng `cache()` để dedupe |
| Render động toàn bộ | Chuyển sang static/ISR |
| Không có cache header | Cấu hình `Cache-Control` (xem file 02) |
| Cold start serverless | Giảm bundle, dùng runtime phù hợp |
| Font/script chặn render | Xem 7.3, 7.4 |

**Chẩn đoán nhanh:**

```bash
# TTFB từ nhiều vị trí
curl -o /dev/null -s -w "TTFB: %{time_starttransfer}s | Total: %{time_total}s\n" https://example.com

# Kiểm tra cache header
curl -sI https://example.com | grep -i -E 'cache-control|age|x-vercel-cache|cf-cache-status'
```

---

## 7.7. Chống CLS theo từng nguyên nhân

| Nguyên nhân | Cách sửa |
| --- | --- |
| Ảnh không có kích thước | `width`/`height` hoặc container `aspect-ratio` |
| Font swap muộn | `next/font` + `display: swap` + subset đúng |
| Banner/quảng cáo chèn sau | Đặt `min-height` cho slot |
| Nội dung động chèn phía trên | Render phía server, hoặc đặt chỗ trước |
| Skeleton khác kích thước nội dung thật | Làm skeleton khớp layout cuối |
| `position: sticky/fixed` xuất hiện muộn | Render ngay từ đầu |
| Embed (iframe, video) không có tỷ lệ | Bọc trong container `aspect-video` |
| Toast/cookie banner đẩy layout | Dùng `position: fixed` |

---

## 7.8. Tối ưu INP

| Kỹ thuật | Chi tiết |
| --- | --- |
| Giảm JS trên main thread | Xem 7.5 |
| Tránh re-render lớn | `memo`, tách state, dùng `useDeferredValue`/`useTransition` |
| Tránh work nặng trong event handler | Debounce, chuyển sang `requestIdleCallback` |
| Chunk công việc dài | Tránh task > 50ms |
| Giảm hydration cost | Ít client component hơn |
| Ưu tiên CSS thay JS cho animation | `transform`/`opacity` |
| Tránh third-party đồng bộ | Xem 7.4 |

Trong React 19, `useTransition` và form actions giúp giữ main thread rảnh trong lúc cập nhật.

---

## 7.9. Prefetch & điều hướng

```tsx
import Link from 'next/link'

<Link href="/san-pham" prefetch={true}>Sản phẩm</Link>       // prefetch đầy đủ
<Link href="/nang" prefetch={false}>Trang nặng</Link>        // tắt prefetch
```

| Hành vi | Chi tiết |
| --- | --- |
| Prefetch mặc định | Chỉ khi link vào viewport (production) |
| `prefetch={false}` | Dùng cho trang rất nặng hoặc ít được click |
| Prefetch gây tải CDN | Với site lớn, theo dõi chi phí CDN |

`[16]` Next.js 16 cải thiện prefetching theo kiểu **incremental** và dedupe layout — giảm tải khi nhiều link trỏ cùng segment.

---

## 7.10. Đo lường CWV trong code

```tsx
// app/web-vitals.tsx
'use client'
import { useReportWebVitals } from 'next/web-vitals'

export function WebVitals() {
  useReportWebVitals((metric) => {
    // Gửi tới endpoint nội bộ, đừng gửi mọi metric lên GA
    navigator.sendBeacon('/api/vitals', JSON.stringify({
      name: metric.name, value: metric.value, rating: metric.rating, id: metric.id,
    }))
  })
  return null
}
```

```tsx
// app/layout.tsx
import { WebVitals } from './web-vitals'
// ...
<WebVitals />
```

Đo trong **production** ở phân vị 75; số liệu Lighthouse tại lab không thay thế dữ liệu trường.

---

## 7.11. Anti-pattern hiệu năng

| Anti-pattern | Hậu quả |
| --- | --- |
| `priority` trên nhiều ảnh | Tranh chấp băng thông, LCP tệ hơn |
| Thiếu `sizes` | Tải ảnh lớn gấp nhiều lần cần thiết |
| Dùng `<img>` cho ảnh nội dung | Mất tối ưu, CLS |
| `@import` font trong CSS | Chặn render |
| `next/font` thiếu subset `vietnamese` | Chữ tiếng Việt lỗi, CLS |
| Analytics `beforeInteractive` | Chặn hydration |
| Toàn bộ trang là client component | Bundle lớn, INP kém |
| `force-dynamic` toàn site | TTFB cao |
| Không có `Cache-Control` khi self-host | Mọi request đều render |
| Nhúng nhiều video iframe ngay | LCP rất kém |
| Third-party không kiểm soát | INP tụt không rõ nguyên nhân |

---

## 7.12. Checklist hiệu năng

- [ ] LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 (p75, mobile) đo bằng dữ liệu trường
- [ ] Đúng một ảnh `priority` mỗi trang
- [ ] Mọi ảnh có `sizes` và kích thước/khung tỷ lệ
- [ ] Ảnh phục vụ AVIF/WebP
- [ ] `next/font` với subset `vietnamese`, `display: swap`, ≤ 4 weight
- [ ] Không có request tới fonts.googleapis.com
- [ ] Third-party script dùng `afterInteractive`/`lazyOnload`
- [ ] JS trang nội dung ≤ 150KB gzip
- [ ] `optimizePackageImports` cho thư viện lớn
- [ ] Cache header đúng cho asset và HTML
- [ ] TTFB ≤ 0.8s (p75)
- [ ] Skeleton khớp layout cuối, không gây shift
- [ ] Slot quảng cáo/banner có `min-height`
- [ ] Đã bật thu thập CWV thực tế trong production
- [ ] Đã kiểm tra trên thiết bị mobile thật, mạng 4G chậm
