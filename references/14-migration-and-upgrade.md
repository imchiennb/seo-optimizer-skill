# 14 — Migration, nâng cấp, đổi domain

Đây là nhóm thao tác **rủi ro cao nhất** cho SEO. Một migration làm sai có thể xoá sạch nhiều năm tích luỹ trong vài ngày.

---

## 14.1. Đính chính một thông tin sai phổ biến

> ❌ "Next.js 16 đã xoá Pages Router, buộc phải migrate sang App Router."
>
> ✅ **Sai.** Pages Router **vẫn được hỗ trợ đầy đủ** trong Next.js 16.x. Docs chính thức vẫn có nhánh riêng `/docs/pages` với đầy đủ tài liệu cho `getStaticProps`, `getServerSideProps`, `_app`, `_document`, API Routes.
>
> **Sự thật:** mọi **tính năng mới** (Cache Components, `proxy.ts`, streaming metadata…) chỉ có ở App Router. Pages Router ở chế độ bảo trì — vẫn hoạt động, nhưng không nhận tính năng mới.

**Hệ quả thực tế:** migration Pages → App Router là **lựa chọn chiến lược**, không phải bắt buộc kỹ thuật. Và từ góc độ SEO thuần, migration **không mang lại lợi ích xếp hạng trực tiếp** — nó mang lại khả năng dùng các tính năng mới. Đừng migration chỉ vì "nghe nói phải làm".

---

## 14.2. Bảng ánh xạ Pages Router → App Router

| Pages Router | App Router | Ghi chú SEO |
| --- | --- | --- |
| `next/head` + `<Head>` | `export const metadata` / `generateMetadata` | Bỏ được thư viện `next-seo` |
| `<NextSeo title=... />` | `metadata` object | `next-seo` không cần nữa |
| `pages/_app.tsx` | `app/layout.tsx` | Metadata mặc định đặt ở đây |
| `pages/_document.tsx` | `app/layout.tsx` (thẻ `<html>`, `<body>`) | `lang` đặt ở đây |
| `getStaticProps` | `async` Server Component + fetch | Mặc định static |
| `getStaticPaths` | `generateStaticParams` | |
| `getStaticProps` + `revalidate` | `export const revalidate = N` | ISR |
| `getServerSideProps` | `async` Server Component + `export const dynamic = 'force-dynamic'` | Cân nhắc có thật cần không |
| `router.query` | `params` (**await**) + `searchParams` (**await**) | Breaking change `[15]` |
| `pages/404.tsx` | `app/not-found.tsx` | |
| `pages/_error.tsx` | `app/error.tsx` + `app/global-error.tsx` | |
| `pages/api/*` | `app/api/*/route.ts` | Route Handler |
| `next-sitemap` (thư viện) | `app/sitemap.ts` | Bỏ dependency |
| `public/robots.txt` | `app/robots.ts` (tuỳ chọn) | Không dùng cả hai |
| `next.config.js` → `i18n: { locales }` | `app/[locale]/` + `proxy.ts` | **`i18n` config không hoạt động ở App Router** |
| `next.config.js` → `redirects`/`rewrites`/`headers` | Giữ nguyên | Không đổi |
| `next/image` | Giữ nguyên | `[16]` một số mặc định đổi |
| `next/font` | Giữ nguyên | |
| `next/script` | Giữ nguyên | |

### Ví dụ chuyển đổi metadata

```tsx
// TRƯỚC — Pages Router
import Head from 'next/head'
export default function Post({ post }) {
  return (
    <>
      <Head>
        <title>{post.title} | Thương hiệu</title>
        <meta name="description" content={post.excerpt} />
        <link rel="canonical" href={`https://example.com/bai-viet/${post.slug}`} />
        <meta property="og:title" content={post.title} />
        <meta property="og:image" content={`https://example.com${post.cover}`} />
      </Head>
      <article>{/* ... */}</article>
    </>
  )
}

export async function getStaticProps({ params }) {
  const post = await getPost(params.slug)
  return { props: { post }, revalidate: 3600 }
}
export async function getStaticPaths() {
  const posts = await getAllPosts()
  return { paths: posts.map((p) => ({ params: { slug: p.slug } })), fallback: false }
}
```

```tsx
// SAU — App Router
import type { Metadata } from 'next'
import { permanentRedirect } from 'next/navigation'

export const revalidate = 3600
export const dynamicParams = false           // thay cho fallback: false

export async function generateStaticParams() {
  const posts = await getAllPosts()
  return posts.map((p) => ({ slug: p.slug }))
}

export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> },
): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  if (!post) return {}
  return {
    title: post.title,                       // template ở layout tự ghép thương hiệu
    description: post.excerpt,
    alternates: { canonical: `/bai-viet/${post.slug}` },
    openGraph: {
      type: 'article',
      title: post.title,
      images: [{ url: post.cover, width: 1200, height: 630, alt: post.title }],
    },
  }
}

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  if (!post) permanentRedirect('/bai-viet')   // hoặc notFound()
  return <article>{/* ... */}</article>
}
```

### Điểm dễ làm mất SEO khi chuyển

| Bẫy | Hậu quả |
| --- | --- |
| `fallback: false` → quên `dynamicParams = false` | Sinh URL không tồn tại thay vì 404 |
| Quên `await params` | Metadata rỗng, title `[object Promise]` |
| `getServerSideProps` → chuyển hết thành dynamic | Mất static, TTFB tăng |
| Metadata chỉ đặt ở `page.tsx` mà quên `metadataBase` ở layout | OG image tương đối, canonical sai |
| Bỏ `_document.tsx` mà quên chuyển `lang` | `<html>` thiếu `lang` |
| `next.config` `i18n` để nguyên | Locale không hoạt động, URL sai |
| Đổi URL trong lúc migration | Mất traffic — **không bao giờ đổi URL cùng lúc với migration** |

---

## 14.3. Nguyên tắc vàng của migration

> **Đổi một thứ tại một thời điểm.**

Nếu bạn vừa đổi framework, vừa đổi URL, vừa đổi nội dung, vừa đổi design — và traffic tụt — bạn không thể biết nguyên nhân nào. Tách thành các lần deploy riêng biệt:

| Lần | Việc làm | Kỳ vọng |
| --- | --- | --- |
| 1 | Migration kỹ thuật, **giữ nguyên URL và nội dung 100%** | Không có biến động |
| 2 | Cải thiện hiệu năng (sau khi lần 1 ổn định ≥ 2 tuần) | CWV tốt lên |
| 3 | Đổi design/UX | Theo dõi engagement |
| 4 | Thay đổi cấu trúc URL (nếu cần) | Có redirect map đầy đủ |

**Checklist "giữ nguyên" cho migration:**

- [ ] URL giống hệt từng ký tự (bao gồm trailing slash)
- [ ] Title, description, H1 giống hệt
- [ ] Canonical giống hệt
- [ ] Sitemap chứa **đúng** tập URL như trước
- [ ] `robots.txt` không đổi hành vi
- [ ] Internal link trỏ tới cùng URL
- [ ] JSON-LD tương đương hoặc tốt hơn

---

## 14.4. Quy trình migration an toàn theo 7 bước

### Bước 1 — Lập bản đồ URL inventory trước migration

```bash
# Crawl site hiện tại và lưu danh sách URL + status + title
mkdir -p migration
cat > migration/urls.txt <<'EOF'
https://example.com/
https://example.com/bang-gia
https://example.com/san-pham/abc
EOF

while read -r url; do
  code=$(curl -sL -o /dev/null -w "%{http_code}" "$url")
  title=$(curl -sL "$url" | grep -o '<title>[^<]*' | sed 's/<title>//')
  echo -e "${code}\t${url}\t${title}"
done < migration/urls.txt > migration/before.tsv
```

Với site lớn, dùng Screaming Frog (bật chế độ render JS) để crawl toàn bộ và export.

### Bước 2 — Snapshot metadata quan trọng

Lưu lại: title, description, canonical, robots, h1, JSON-LD `@type`, số internal link, og:image của **toàn bộ** URL.

```bash
cat > migration/snapshot.sh <<'SH'
#!/usr/bin/env bash
# $1 = file danh sách URL, $2 = file output
while read -r url; do
  body=$(curl -sL "$url")
  echo "=== $url"
  echo "STATUS: $(curl -sL -o /dev/null -w '%{http_code}' "$url")"
  echo "$body" | grep -oE '<title>[^<]*</title>'
  echo "$body" | grep -oE '<link rel="canonical"[^>]*>'
  echo "$body" | grep -oE '<meta name="robots"[^>]*>'
  echo "$body" | grep -oE '<h1[^>]*>[^<]*'
  echo "$body" | grep -oE '<meta property="og:image"[^>]*>'
  echo "$body" | grep -oE '"@type"\s*:\s*"[^"]*"'
done < "$1" > "$2"
SH
chmod +x migration/snapshot.sh
./migration/snapshot.sh migration/urls.txt migration/before-snapshot.txt
```

### Bước 3 — Deploy lên môi trường preview có `noindex`

Kiểm tra trước khi lên production:
- `noindex` hoạt động
- `curl` thấy nội dung đầy đủ
- Metadata đúng
- Không có lỗi 5xx

### Bước 4 — So sánh sau deploy (quan trọng nhất)

```bash
./migration/snapshot.sh migration/urls.txt migration/after-snapshot.txt

# So sánh — phải gần như không có khác biệt ở giai đoạn migration thuần
diff migration/before-snapshot.txt migration/after-snapshot.txt | head -80
```

Bất kỳ khác biệt nào về status, canonical, hay `noindex` đều là **lỗi chặn**, không phải "khác biệt nhỏ".

### Bước 5 — Kiểm tra sitemap tương đương

```bash
# Số URL trước và sau phải bằng nhau (giai đoạn migration thuần)
curl -s https://example.com/sitemap.xml | grep -c '<loc>'
```

### Bước 6 — Giữ redirect và theo dõi

- Nếu có đổi URL: giữ redirect **vĩnh viễn**, không xoá sau vài tháng.
- Theo dõi GSC hàng ngày trong 2 tuần đầu: Pages, Sitemaps, Crawl Stats, lỗi 5xx.

### Bước 7 — Rollback plan

Trước khi deploy, trả lời được: **nếu hỏng, rollback trong bao lâu và bằng cách nào?**

| Yếu tố | Yêu cầu |
| --- | --- |
| Bản deploy trước | Còn giữ, deploy lại được trong < 15 phút |
| Dữ liệu | Không có migration DB phá huỷ |
| DNS | Không đổi trong cùng lần deploy |
| Redirect | Đã test ở preview |
| Thông báo | Có người trực trong 2 giờ đầu sau deploy |

---

## 14.5. Nâng cấp version Next.js

### Quy trình

```bash
# 1. Đọc upgrade guide của version đích TRƯỚC khi làm
#    https://nextjs.org/docs/app/guides/upgrading/version-16

# 2. Chạy codemod chính thức
npx @next/codemod@canary upgrade latest

# 3. Cập nhật dependency
npm install next@latest react@latest react-dom@latest

# 4. Build và kiểm tra
npm run build

# 5. Kiểm tra các breaking change bên dưới
```

### Breaking change ảnh hưởng SEO cần kiểm tra

| Thay đổi | Ảnh hưởng SEO | Cách kiểm tra |
| --- | --- | --- |
| `params`/`searchParams` thành Promise `[15]` | Metadata rỗng, 404 sai | `grep -rn "params\." app/ \| grep -v await` |
| `fetch` không cache mặc định `[15]` | Trang thành dynamic, TTFB tăng | Kiểm tra `npm run build` output: route nào dynamic |
| Route Handler GET không cache mặc định `[15]` | Tăng tải | Kiểm tra route handler |
| `viewport`/`themeColor` tách khỏi `metadata` `[14]` | Warning, thiếu viewport | `grep -rn "themeColor" app/` |
| `next/image` đổi mặc định `[16]` | Chất lượng ảnh, LCP | So sánh ảnh trước/sau, kiểm tra `quality` |
| `middleware.ts` → `proxy.ts` `[16]` | Redirect/noindex header có thể ngừng chạy | Kiểm tra file còn tồn tại và export đúng tên |
| `experimental.ppr` bị loại bỏ `[16]` | Build lỗi | Chuyển sang `cacheComponents: true` |
| Turbopack mặc định `[16]` | Plugin webpack không chạy | Kiểm tra build output |
| React 19 bắt buộc `[16]` | Thư viện cũ lỗi | Chạy test suite |

**Sau mỗi lần nâng version, luôn chạy lại:**
```bash
node scripts/check-seo.mjs .next/server/app
bash scripts/grep-antipatterns.sh app
```

---

## 14.6. Đổi domain

Đây là thao tác có ảnh hưởng lớn nhất và cần kế hoạch dài hạn.

### Chuẩn bị (trước ngày D)

- [ ] Domain mới đã cấu hình HTTPS, HSTS
- [ ] Đã test toàn bộ redirect ở staging
- [ ] Đã crawl và lưu inventory URL domain cũ
- [ ] Đã backup cấu hình DNS, CDN, redirect
- [ ] Đã thông báo cho các bên liên quan

### Ngày D

1. **301 toàn bộ** URL cũ → URL mới, ánh xạ 1-1 (không dồn về trang chủ)
2. Cập nhật `metadataBase`, `NEXT_PUBLIC_SITE_URL`
3. Cập nhật sitemap (URL domain mới)
4. Cập nhật `robots.txt` (`host`, `sitemap`)
5. Cập nhật `canonical` toàn site
6. Giữ domain cũ hoạt động với redirect (không được tắt)
7. Cập nhật **internal link tuyệt đối** (nếu hard-code)
8. Cập nhật `sameAs`, social profile, email signature, tài liệu

### Sau ngày D

| Việc | Thời điểm |
| --- | --- |
| Search Console: **Change of Address** cho domain cũ | Ngay sau deploy |
| Xác minh domain mới trong GSC, submit sitemap | Ngay |
| Cập nhật Bing Webmaster Tools | Trong tuần |
| Liên hệ các site có backlink để cập nhật (nếu quan hệ tốt) | Trong tháng |
| **Giữ redirect ít nhất 6–12 tháng** | — |
| Theo dõi GSC hàng ngày 1 tháng đầu | — |

### Sai lầm chết người khi đổi domain

| Sai lầm | Hậu quả |
| --- | --- |
| Tắt domain cũ ngay | Mất toàn bộ backlink và tín hiệu |
| Redirect tất cả về trang chủ domain mới | Soft 404 hàng loạt |
| Không dùng Change of Address | Google chậm chuyển tín hiệu |
| Redirect 302 | Không chuyển tín hiệu |
| Quên cập nhật canonical | Google thấy canonical trỏ domain cũ |
| Quên cập nhật sitemap | Sitemap toàn URL cũ |
| Đổi domain + đổi cấu trúc URL cùng lúc | Không debug được |
| Không giữ redirect đủ lâu | Mất dần tín hiệu |

---

## 14.7. Đổi cấu trúc URL (không đổi domain)

| Bước | Chi tiết |
| --- | --- |
| 1 | Lập bảng ánh xạ cũ → mới cho **từng** URL, không dùng quy tắc chung chung |
| 2 | Kiểm tra ánh xạ có trùng đích không (nhiều URL cũ → 1 URL mới là dấu hiệu cần gộp nội dung) |
| 3 | Cấu hình trong `next.config.ts` (chạy trước render, rẻ nhất) |
| 4 | Deploy cùng lúc: redirect + sitemap + canonical + internal link |
| 5 | Kiểm tra `curl -sIL` cho từng URL cũ: phải là **một** bước nhảy 308 |
| 6 | Chạy `snapshot.sh` so sánh |
| 7 | Giữ redirect vĩnh viễn |

```ts
// next.config.ts
const redirects = [
  { source: '/blog/:slug', destination: '/bai-viet/:slug', permanent: true },
  { source: '/product/:id', destination: '/san-pham/:id', permanent: true },
  // Redirect cụ thể cho các trường hợp không theo quy tắc
  { source: '/old-special-page', destination: '/trang-moi', permanent: true },
]
```

> **Không** dùng `redirects` theo kiểu "catch-all" cho URL không tồn tại — tránh redirect mọi 404 về trang chủ.

---

## 14.8. Checklist migration

### Trước
- [ ] Đã lưu URL inventory + snapshot metadata
- [ ] Đã đọc upgrade guide / migration guide tương ứng
- [ ] Đã xác định rõ: migration này có đổi URL không? (nên: không)
- [ ] Có rollback plan và đã test
- [ ] Preview có `noindex`

### Trong
- [ ] Giữ URL, title, canonical, sitemap y hệt (giai đoạn migration thuần)
- [ ] Chạy `diff` snapshot trước/sau
- [ ] Số URL trong sitemap tương đương
- [ ] Không có 5xx
- [ ] `check-seo.mjs` xanh

### Sau
- [ ] GSC: không có lỗi mới trong Pages
- [ ] CWV không tệ hơn
- [ ] Traffic ổn định sau 2 tuần
- [ ] Nếu đổi domain: đã dùng Change of Address
- [ ] Redirect (nếu có) là 1 bước nhảy, 308
- [ ] Đã ghi changelog: ngày, phạm vi, kết quả
- [ ] Đã xoá code cũ và dependency không dùng (`next-seo`, `next-sitemap`)
