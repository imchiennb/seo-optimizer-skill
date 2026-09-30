# 05 — Structured Data (JSON-LD)

Structured data giúp Google hiểu **thực thể** (entity) phía sau trang, mở khoá rich results và tăng khả năng xuất hiện trong AI answers.

---

## 5.1. Nguyên tắc gốc

1. **JSON-LD là định dạng được khuyến nghị** (không phải Microdata / RDFa). Chèn qua `<script type="application/ld+json">`.
2. **Nội dung trong schema phải khớp nội dung hiển thị.** Đánh dấu dữ liệu không có trên trang là vi phạm chính sách.
3. **Không đánh dấu nội dung ẩn** với mục đích lừa crawler.
4. **Một trang có thể có nhiều thực thể** — dùng `@graph` hoặc nhiều `<script>`.
5. **Structured data không phải yếu tố xếp hạng trực tiếp** — nó ảnh hưởng cách hiển thị (rich result) và cách hiểu thực thể.
6. **Không spam schema** cho mọi loại có thể, chỉ dùng loại đúng với trang.

---

## 5.2. Cách chèn đúng trong App Router

Cách chính thức được Next.js khuyến nghị — render trực tiếp trong Server Component:

```tsx
// app/bai-viet/[slug]/page.tsx
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    headline: post.title,
    description: post.excerpt,
    image: [post.cover],
    datePublished: post.publishedAt.toISOString(),
    dateModified: post.updatedAt.toISOString(),
    author: { '@type': 'Person', name: post.author.name, url: post.author.url },
    publisher: {
      '@type': 'Organization',
      name: 'Tên thương hiệu',
      logo: { '@type': 'ImageObject', url: 'https://example.com/logo.png' },
    },
    mainEntityOfPage: { '@type': 'WebPage', '@id': `https://example.com/bai-viet/${post.slug}` },
  }

  return (
    <>
      <script
        type="application/ld+json"
        // Chống XSS: escape ký tự phá vỡ thẻ script
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c') }}
      />
      <article>{/* ... */}</article>
    </>
  )
}
```

> **Bắt buộc escape `<`** khi dữ liệu đến từ người dùng. Không escape ⇒ có thể bị chèn `</script><script>...`.
> Không dùng `JSON.stringify(JSON.stringify(...))` (double-encode) — lỗi rất phổ biến.

### Helper dùng chung

```ts
// lib/jsonld.ts
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, '\\u003c') }}
    />
  )
}
```

---

## 5.3. Schema theo loại trang

| Loại trang | Schema chính | Rich result tiềm năng |
| --- | --- | --- |
| Toàn site (layout gốc) | `Organization`, `WebSite` (+`SearchAction`) | Knowledge panel, sitelinks |
| Trang chủ | `WebSite`, `Organization` | Sitelinks |
| Bài viết/blog | `BlogPosting` / `NewsArticle` | Top stories, Discover |
| Sản phẩm | `Product` + `Offer` + `AggregateRating` | Product snippet, shopping |
| Danh mục | `CollectionPage` + `ItemList` + `BreadcrumbList` | Breadcrumb |
| Trang dịch vụ | `Service` | — |
| FAQ | `FAQPage` | ⚠️ Hạn chế (xem 5.6) |
| Hướng dẫn từng bước | `HowTo` | ⚠️ Đã ngừng hỗ trợ |
| Doanh nghiệp địa phương | `LocalBusiness` (+`PostalAddress`, `GeoCoordinates`, `OpeningHoursSpecification`) | Local pack |
| Sự kiện | `Event` | Event rich result |
| Video | `VideoObject` | Video rich result |
| Công thức | `Recipe` | Recipe rich result |
| Khóa học | `Course` | Course rich result |
| Việc làm | `JobPosting` | Job rich result |
| Tác giả | `Person` | Knowledge panel |
| Breadcrumb mọi trang | `BreadcrumbList` | Breadcrumb trong SERP |
| Trang Q&A | `QAPage` | Hạn chế |

---

## 5.4. Mẫu `@graph` cho toàn site

Đặt ở layout gốc, dùng `@id` để liên kết thực thể:

```tsx
// app/layout.tsx
const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

const organizationLd = {
  '@type': 'Organization',
  '@id': `${baseUrl}/#organization`,
  name: 'Tên thương hiệu',
  url: baseUrl,
  logo: { '@type': 'ImageObject', '@id': `${baseUrl}/#logo`, url: `${baseUrl}/logo.png`, width: 512, height: 512 },
  sameAs: [
    'https://www.facebook.com/thuonghieu',
    'https://www.linkedin.com/company/thuonghieu',
    'https://github.com/thuonghieu',
  ],
  contactPoint: [{
    '@type': 'ContactPoint',
    telephone: '+84-...',
    contactType: 'customer service',
    areaServed: 'VN',
    availableLanguage: ['vi', 'en'],
  }],
}

const websiteLd = {
  '@type': 'WebSite',
  '@id': `${baseUrl}/#website`,
  url: baseUrl,
  name: 'Tên thương hiệu',
  inLanguage: 'vi-VN',
  publisher: { '@id': `${baseUrl}/#organization` },
  potentialAction: {
    '@type': 'SearchAction',
    target: { '@type': 'EntryPoint', urlTemplate: `${baseUrl}/tim-kiem?q={search_term_string}` },
    'query-input': 'required name=search_term_string',
  },
}

const graph = { '@context': 'https://schema.org', '@graph': [organizationLd, websiteLd] }
```

> ⚠️ `SearchAction` (sitelinks search box) **đã bị Google ngừng hỗ trợ** (2024). Vẫn có thể giữ để các engine/AI khác đọc, nhưng đừng kỳ vọng hiển thị. Đừng dành thời gian tối ưu nó.

---

## 5.5. Breadcrumb

```tsx
const breadcrumbLd = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: 'Trang chủ', item: baseUrl },
    { '@type': 'ListItem', position: 2, name: 'Sản phẩm', item: `${baseUrl}/san-pham` },
    { '@type': 'ListItem', position: 3, name: product.name, item: `${baseUrl}/san-pham/${product.slug}` },
  ],
}
```

**Bắt buộc:** breadcrumb trong schema phải khớp breadcrumb hiển thị trên trang. Nên render từ **cùng một nguồn dữ liệu**.

```tsx
// lib/breadcrumb.ts
export function buildBreadcrumb(trail: { name: string; href: string }[]) {
  return {
    ui: trail,                           // dùng để render <nav>
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: trail.map((t, i) => ({
        '@type': 'ListItem', position: i + 1, name: t.name, item: new URL(t.href, baseUrl).toString(),
      })),
    },
  }
}
```

---

## 5.6. Cảnh báo về các loại schema đã bị thu hẹp

| Schema | Trạng thái | Ghi chú |
| --- | --- | --- |
| `FAQPage` | Chỉ hiển thị rich result cho site **y tế & chính phủ uy tín** | Vẫn nên dùng để AI/engine khác hiểu nội dung; đừng kỳ vọng hiển thị rộng |
| `HowTo` | Rich result **đã ngừng** trên desktop/mobile | Có thể giữ như tín hiệu ngữ nghĩa |
| `SpecialAnnouncement` | Đã ngừng | Bỏ |
| `Course info`, `Estimated salary`, `Learning video`, `Vehicle listing`, `Practice problems` | Đã ngừng | Bỏ |
| Sitelinks search box | Đã ngừng | Bỏ kỳ vọng |
| `Product` + `AggregateRating` | Còn, nhưng **bắt buộc có review thật** | Tự sinh rating giả = vi phạm, có thể bị manual action |

**Kết luận:** dùng schema để **mô tả đúng thực thể**, không phải để săn rich result. Đây là tư duy đúng và bền vững.

---

## 5.7. Product schema mẫu

```tsx
const productLd = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: product.name,
  description: product.shortDescription,
  sku: product.sku,
  gtin13: product.gtin,
  brand: { '@type': 'Brand', name: product.brand },
  image: product.images.map((i) => new URL(i, baseUrl).toString()),
  offers: {
    '@type': 'Offer',
    url: `${baseUrl}/san-pham/${product.slug}`,
    priceCurrency: 'VND',
    price: product.price,
    priceValidUntil: product.priceValidUntil,
    availability: product.stock > 0
      ? 'https://schema.org/InStock'
      : 'https://schema.org/OutOfStock',
    itemCondition: 'https://schema.org/NewCondition',
    seller: { '@type': 'Organization', name: 'Tên thương hiệu' },
    hasMerchantReturnPolicy: {
      '@type': 'MerchantReturnPolicy',
      applicableCountry: 'VN',
      returnPolicyCategory: 'https://schema.org/MerchantReturnFiniteReturnWindow',
      merchantReturnDays: 30,
    },
    shippingDetails: {
      '@type': 'OfferShippingDetails',
      shippingRate: { '@type': 'MonetaryAmount', value: 0, currency: 'VND' },
      shippingDestination: { '@type': 'DefinedRegion', addressCountry: 'VN' },
    },
  },
  aggregateRating: product.reviewCount > 0 ? {
    '@type': 'AggregateRating',
    ratingValue: product.avgRating,      // phải là dữ liệu thật
    reviewCount: product.reviewCount,
  } : undefined,
}
```

---

## 5.8. Article schema — các trường bắt buộc

| Trường | Bắt buộc | Ghi chú |
| --- | --- | --- |
| `headline` | ✅ | ≤ 110 ký tự |
| `image` | ✅ | ≥ 3 ảnh, ≥ 1200px ngang |
| `datePublished` | ✅ | ISO 8601 |
| `dateModified` | Nên | Phải khớp ngày hiển thị |
| `author` | ✅ | `Person` với `url` tới trang tác giả |
| `publisher` | ✅ | `Organization` + `logo` |
| `mainEntityOfPage` | Nên | Trỏ về URL chuẩn |

---

## 5.9. Kiểm thử

| Công cụ | Dùng để |
| --- | --- |
| [Rich Results Test](https://search.google.com/test/rich-results) | Loại schema nào đang được Google hỗ trợ |
| [Schema Markup Validator](https://validator.schema.org/) | Cú pháp schema.org nói chung |
| Search Console → Enhancements | Lỗi schema trên toàn site |
| `curl \| grep 'application/ld+json'` | Xác nhận JSON-LD có trong HTML thô |

```bash
# Trích JSON-LD từ HTML thô và validate cú pháp
curl -s https://example.com/bai-viet/abc \
  | grep -o '<script type="application/ld+json">.*</script>' \
  | sed 's/<[^>]*>//g' \
  | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{JSON.parse(s);console.log('JSON hợp lệ')})"
```

---

## 5.10. Anti-pattern structured data

| Anti-pattern | Vấn đề |
| --- | --- |
| Đánh dấu `FAQPage` cho nội dung không hiển thị | Vi phạm chính sách |
| `aggregateRating` tự bịa | Manual action |
| `Product` không có `offers` | Không đủ điều kiện rich result |
| Nhiều `@context` lồng nhau trong một `@graph` | Sai cú pháp |
| JSON-LD chỉ chèn sau khi mount (client) | Bot đợt 1 không thấy |
| Double-stringify (`JSON.stringify(JSON.stringify(x))`) | JSON-LD không parse được |
| Không escape `<` | Lỗ hổng XSS |
| Dùng `@id` không tồn tại / URL tương đối | Thực thể không liên kết được |
| Nhồi mọi schema có thể vào một trang | Nhiễu, Google có thể bỏ qua hết |

---

## 5.11. Checklist structured data

- [ ] `Organization` + `WebSite` trong layout gốc, có `@id` và `sameAs`
- [ ] `BreadcrumbList` trên mọi trang sâu, khớp breadcrumb hiển thị
- [ ] `BlogPosting`/`NewsArticle` trên bài viết, có `author` là `Person` có `url`
- [ ] `Product` + `Offer` trên trang sản phẩm, có `availability`, `price`, `priceCurrency`
- [ ] `AggregateRating` chỉ khi có review thật
- [ ] JSON-LD hiện diện trong HTML thô
- [ ] JSON hợp lệ, không double-encode
- [ ] Đã escape `<` ở mọi trường có dữ liệu người dùng
- [ ] Đã kiểm tra bằng Rich Results Test / Schema Validator
- [ ] Không còn kỳ vọng vào FAQ/HowTo/sitelinks search box
- [ ] Không có schema mô tả nội dung không tồn tại trên trang
