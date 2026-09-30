# 16 — Thương mại điện tử

Site bán hàng có những vấn đề SEO riêng mà site nội dung không gặp.

---

## 16.1. Biến thể sản phẩm — quyết định khó nhất

Một sản phẩm có thể có nhiều biến thể: màu, size, dung tích, phiên bản.

### Ma trận quyết định

| Loại biến thể | Có volume tìm kiếm? | URL | Canonical |
| --- | --- | --- | --- |
| Màu sắc | Thường không | Một URL, chọn màu bằng JS | Tự thân |
| Kích thước | Thường không | Một URL | Tự thân |
| Dung tích / công suất | **Có** (`máy lạnh 1.5HP`, `tủ lạnh 300 lít`) | URL riêng | Tự thân |
| Phiên bản / đời máy | **Có** (`iPhone 15 Pro Max 256GB`) | URL riêng | Tự thân |
| Màu đặc biệt có fan | Đôi khi | URL riêng **chỉ khi** có volume thật | Tự thân |

**Quy tắc:** nếu người dùng thật sự gõ nó vào Google → trang riêng. Nếu chỉ là lựa chọn trong UI → không.

### Không được làm

```
❌ /ao-thun?mau=do&size=m&chat-lieu=cotton&giao-hang=hn
   → mọi tổ hợp là một URL → hàng nghìn URL rác

✅ /ao-thun/nam-cotton-trang
   → một URL, biến thể chọn bằng JS, cập nhật state không đổi URL
```

Nếu cần đổi URL khi chọn biến thể (để chia sẻ link), dùng `history.replaceState` với **param đã được whitelist** và canonical luôn trỏ về URL chính.

### ProductGroup schema cho biến thể

```tsx
const productGroupLd = {
  '@context': 'https://schema.org',
  '@type': 'ProductGroup',
  name: 'Áo thun nam cotton',
  productGroupID: 'ATN-COTTON',
  variesBy: ['https://schema.org/color', 'https://schema.org/size'],
  hasVariant: variants.map((v) => ({
    '@type': 'Product',
    sku: v.sku,
    color: v.color,
    size: v.size,
    offers: {
      '@type': 'Offer',
      price: v.price,
      priceCurrency: 'VND',
      availability: v.stock > 0
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
    },
  })),
}
```

---

## 16.2. Sản phẩm hết hàng — đừng xoá URL

Đây là lỗi tốn kém nhất của site thương mại.

| Tình huống | Hành động | Lý do |
| --- | --- | --- |
| Hết hàng **tạm thời** | Giữ `200`, `availability: OutOfStock`, giữ URL | Giữ backlink, lịch sử, xếp hạng; sẽ có hàng lại |
| Hết hàng **vĩnh viễn**, có sản phẩm thay thế | `301` tới sản phẩm thay thế gần nhất | Chuyển tín hiệu |
| Hết hàng **vĩnh viễn**, cùng dòng còn sản phẩm khác | `301` tới trang danh mục dòng đó | Giữ người dùng trong phễu |
| Ngừng kinh doanh hoàn toàn | `410` | Loại khỏi index nhanh |
| Hết hàng theo mùa | Giữ `200`, `OutOfStock` | Sẽ về mùa sau |

**Tuyệt đối không:**
- Xoá URL khi hết hàng (mất backlink vĩnh viễn)
- Trả `404` cho sản phẩm hết hàng
- `noindex` sản phẩm hết hàng tạm thời
- Redirect tất cả sản phẩm hết hàng về trang chủ

**Xử lý UI khi hết hàng:** hiện thông báo rõ, gợi ý sản phẩm tương tự, cho đăng ký nhận thông báo — nhưng giữ nguyên URL và nội dung.

---

## 16.3. Trang danh mục và phân trang

### Vấn đề "xem tất cả"

| Cách làm | Đánh giá |
| --- | --- |
| `?view=all` hiện tất cả sản phẩm | ⚠️ Trang rất nặng, chậm; nếu index có thể lấn át các trang phân trang |
| Phân trang chuẩn `?page=2` | ✅ |
| Infinite scroll | ⚠️ Phải có link phân trang thật trong HTML |
| Load more bằng JS | ⚠️ Nội dung mới không có URL → không index được |

**Khuyến nghị:** phân trang thật, mỗi trang có URL riêng và canonical tự thân (xem file 06). Nếu muốn "xem tất cả", đặt `noindex, follow` và `rel="canonical"` về trang 1 — nhưng cẩn thận vì trang sẽ rất nặng.

### Số sản phẩm mỗi trang

| Số lượng | Đánh giá |
| --- | --- |
| 12–24 | Cân bằng tốt — đủ nội dung, tải nhanh |
| < 8 | Quá ít, nhiều trang phân trang, loãng |
| > 60 | Trang nặng, LCP kém |

### Nội dung trên trang danh mục

Trang danh mục **chỉ liệt kê sản phẩm** là nội dung mỏng. Cần thêm:
- Mô tả danh mục (150–300 từ) — đặt **dưới** danh sách sản phẩm để không đẩy sản phẩm xuống
- Bộ lọc liên quan
- FAQ ngắn về danh mục
- Internal link tới danh mục con và danh mục liên quan

---

## 16.4. Facet navigation

| Loại facet | Xử lý |
| --- | --- |
| **Thương hiệu** (`/dien-thoai/apple`) | ⭐ Trang tĩnh riêng — volume cao, intent rõ |
| **Thuộc tính chính** (`/quat-dieu-hoa/treo-tuong`) | ⭐ Trang tĩnh riêng nếu có volume |
| **Khoảng giá** | `noindex, follow` hoặc canonical về danh mục |
| **Đánh giá sao** | `noindex, follow` |
| **Tình trạng** (còn hàng) | Canonical về danh mục |
| **Tổ hợp 2+ facet** | `noindex, follow` |
| **Sắp xếp** (giá tăng/giảm) | Canonical về URL không sort |

**Chiến lược thực dụng:**
1. Xuất danh sách facet có traffic từ GSC.
2. Chuyển các facet này thành route tĩnh có nội dung riêng (mô tả, FAQ, internal link).
3. Phần còn lại: `noindex, follow` + canonical về danh mục cha.
4. Chặn không cho Googlebot sinh tổ hợp vô hạn (giới hạn số facet áp dụng đồng thời).

---

## 16.5. Giá và tiền tệ

```tsx
offers: {
  '@type': 'Offer',
  priceCurrency: 'VND',
  price: 1299000,              // số nguyên, không phân cách nghìn, không "1.299.000đ"
  priceValidUntil: '2026-12-31',
  availability: 'https://schema.org/InStock',
  url: `https://example.com/san-pham/${slug}`,
}
```

| Lỗi | Hệ quả |
| --- | --- |
| `price: "1.299.000đ"` | Schema không parse được |
| `price: "1,299,000"` (dấu phẩy) | Sai định dạng |
| Thiếu `priceCurrency` | Không đủ điều kiện rich result |
| `priceValidUntil` trong quá khứ | Cảnh báo trong GSC |
| Giá schema khác giá hiển thị | Vi phạm chính sách |

Với giá khuyến mãi, dùng `priceSpecification`:

```tsx
priceSpecification: {
  '@type': 'UnitPriceSpecification',
  price: 990000,
  priceCurrency: 'VND',
  priceType: 'https://schema.org/SalePrice',
}
```

> **Lưu ý tiếng Việt:** dấu chấm là phân cách nghìn trong tiếng Việt (`1.299.000`), dấu phẩy là thập phân. Trong schema **luôn** dùng dấu chấm thập phân và không có phân cách nghìn.

---

## 16.6. Review và rating

| Quy tắc | Chi tiết |
| --- | --- |
| Chỉ dùng review **thật** | Tự sinh `aggregateRating` là vi phạm chính sách, có thể bị manual action |
| `ratingValue` và `reviewCount` phải khớp dữ liệu hiển thị | Sai lệch → mất rich result |
| Review phải hiển thị trên trang | Không đánh dấu review chỉ tồn tại trong DB |
| Thu thập qua form sau khi mua | Cách hợp lệ |
| Sản phẩm 0 review | **Không** khai `aggregateRating` |

```tsx
aggregateRating: product.reviewCount > 0
  ? {
      '@type': 'AggregateRating',
      ratingValue: product.avgRating,
      reviewCount: product.reviewCount,
      bestRating: 5,
      worstRating: 1,
    }
  : undefined,
```

---

## 16.7. Product feed và Merchant Center

Nếu chạy Google Shopping / Performance Max, có **hai nguồn dữ liệu song song**:

| Nguồn | Dùng cho |
| --- | --- |
| `Product` schema trên trang | Rich result, organic |
| Product feed (XML/CSV → Merchant Center) | Shopping, PMax |

**Chúng phải khớp nhau.** Sai lệch thường gặp:

| Sai lệch | Hệ quả |
| --- | --- |
| Giá trong feed khác giá trên trang | Feed bị disapprove |
| Tồn kho feed khác trang | Disapprove |
| Title feed khác title trang | Ít nghiêm trọng nhưng nên khớp |
| Ảnh feed không có trên trang | Disapprove |
| URL feed trả 404 hoặc redirect | Disapprove |

**Nên sinh feed từ cùng một nguồn dữ liệu:**

```ts
// app/feed/products.xml/route.ts
export async function GET() {
  const products = await getSellableProducts()
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">
<channel>
<title>Product feed</title>
<link>https://example.com</link>
${products.map((p) => `<item>
  <g:id>${p.sku}</g:id>
  <g:title><![CDATA[${p.name}]]></g:title>
  <g:description><![CDATA[${p.shortDescription}]]></g:description>
  <g:link>https://example.com/san-pham/${p.slug}</g:link>
  <g:image_link>${p.images[0]}</g:image_link>
  <g:price>${p.price} VND</g:price>
  <g:availability>${p.stock > 0 ? 'in_stock' : 'out_of_stock'}</g:availability>
  <g:condition>new</g:condition>
  <g:brand><![CDATA[${p.brand}]]></g:brand>
  <g:gtin>${p.gtin ?? ''}</g:gtin>
</item>`).join('\n')}
</channel></rss>`
  return new Response(xml, { headers: { 'Content-Type': 'application/xml' } })
}
```

---

## 16.8. Sitemap cho thương mại điện tử

```ts
// app/sitemap.ts
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await getSellableProducts()   // chỉ sản phẩm còn bán hoặc hết tạm
  const categories = await getActiveCategories()

  return [
    { url: `${base}/`, lastModified: new Date(), priority: 1 },
    ...categories.map((c) => ({
      url: `${base}/danh-muc/${c.slug}`,
      lastModified: c.updatedAt,
      priority: 0.8,
    })),
    ...products.map((p) => ({
      url: `${base}/san-pham/${p.slug}`,
      lastModified: p.updatedAt,
      priority: 0.7,
      images: p.images.slice(0, 5).map((i) => `${base}${i}`),
    })),
  ]
}
```

| Quy tắc | Chi tiết |
| --- | --- |
| Chỉ đưa sản phẩm **có thể index** | Không đưa sản phẩm `noindex` (hàng cấm, khu vực hạn chế) |
| Bao gồm sản phẩm hết hàng tạm | Vì trang vẫn là 200 |
| **Không** đưa sản phẩm đã 301/410 | Sẽ là lỗi trong GSC |
| `lastModified` phải là ngày sửa thật | Không dùng `new Date()` cho mọi URL |
| Chia nhỏ với `generateSitemaps` nếu > 50.000 | Bắt buộc |

**Với cửa hàng lớn:** dùng `generateSitemaps` tách theo danh mục để debug dễ và build nhanh.

---

## 16.9. Hiệu năng đặc thù thương mại điện tử

| Vấn đề | Nguyên nhân | Cách sửa |
| --- | --- | --- |
| LCP kém trên trang sản phẩm | Gallery ảnh lớn, ảnh chính không `priority` | Ảnh chính `priority` + `sizes` đúng; thumbnail lazy |
| CLS khi chọn biến thể | Ảnh/giá đổi làm layout nhảy | Đặt khung tỷ lệ cố định cho ảnh; giá có `min-width` |
| CLS do banner khuyến mãi | Banner chèn sau | Slot có `min-height` |
| INP kém khi lọc/sắp xếp | Re-render cả danh sách trên client | Lọc phía server bằng URL param, hoặc `useDeferredValue` |
| INP kém khi thêm giỏ | Nhiều third-party (chat, tracking) | Rà soát script; dùng Server Action |
| Trang danh mục nặng | Tải toàn bộ sản phẩm | Phân trang, lazy load ảnh dưới màn hình |
| TTFB cao | Truy vấn DB không index | Index DB, cache danh mục bằng `use cache` + tag |

---

## 16.10. Các loại trang khác trong site thương mại

| Trang | Index? | Ghi chú |
| --- | --- | --- |
| Trang chủ | ✅ | |
| Danh mục | ✅ | Có mô tả riêng |
| Chi tiết sản phẩm | ✅ | |
| Trang thương hiệu | ✅ | Nếu có volume |
| Bộ sưu tập / bộ sản phẩm | ✅ | Nếu có nội dung riêng |
| Blog / cẩm nang | ✅ | Hỗ trợ topical authority |
| Tìm kiếm nội bộ | ❌ `noindex, follow` | |
| Giỏ hàng | ❌ | |
| Thanh toán | ❌ | |
| Tài khoản | ❌ | |
| Đăng nhập/đăng ký | ❌ | |
| Cảm ơn / thành công | ❌ | |
| So sánh sản phẩm | ⚠️ | Chỉ index nếu có nội dung riêng |
| Ưu đãi / khuyến mãi | ⚠️ | Nên có trang riêng, cập nhật thật |

```tsx
// Trang search nội bộ
export const metadata: Metadata = {
  robots: { index: false, follow: true },
}
```

---

## 16.11. Structured data đầy đủ cho trang sản phẩm

```tsx
const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: product.name,
  description: product.shortDescription,
  sku: product.sku,
  gtin13: product.gtin,
  mpn: product.mpn,
  brand: { '@type': 'Brand', name: product.brand },
  image: product.images.slice(0, 5).map((i) => new URL(i, base).toString()),
  offers: {
    '@type': 'Offer',
    url: `${base}/san-pham/${product.slug}`,
    priceCurrency: 'VND',
    price: product.price,
    priceValidUntil: product.priceValidUntil,
    availability: product.stock > 0
      ? 'https://schema.org/InStock'
      : 'https://schema.org/OutOfStock',
    itemCondition: 'https://schema.org/NewCondition',
    seller: { '@type': 'Organization', name: 'Tên shop' },
    hasMerchantReturnPolicy: {
      '@type': 'MerchantReturnPolicy',
      applicableCountry: 'VN',
      returnPolicyCategory: 'https://schema.org/MerchantReturnFiniteReturnWindow',
      merchantReturnDays: 7,
      returnMethod: 'https://schema.org/ReturnByMail',
      returnFees: 'https://schema.org/FreeReturn',
    },
    shippingDetails: [{
      '@type': 'OfferShippingDetails',
      shippingRate: { '@type': 'MonetaryAmount', value: 30000, currency: 'VND' },
      shippingDestination: { '@type': 'DefinedRegion', addressCountry: 'VN' },
      deliveryTime: {
        '@type': 'ShippingDeliveryTime',
        handlingTime: { '@type': 'QuantitativeValue', minValue: 0, maxValue: 1, unitCode: 'DAY' },
        transitTime: { '@type': 'QuantitativeValue', minValue: 1, maxValue: 3, unitCode: 'DAY' },
      },
    }],
  },
  aggregateRating: product.reviewCount > 0 ? {
    '@type': 'AggregateRating',
    ratingValue: product.avgRating,
    reviewCount: product.reviewCount,
  } : undefined,
}
```

---

## 16.12. Checklist thương mại điện tử

- [ ] Biến thể: chỉ tạo URL riêng khi có volume thật
- [ ] Không có URL sinh theo tổ hợp thuộc tính
- [ ] Sản phẩm hết hàng tạm: giữ `200` + `OutOfStock`, **không** xoá URL
- [ ] Sản phẩm hết hàng vĩnh viễn: `301` hoặc `410`, có ánh xạ rõ
- [ ] Trang phân trang canonical tự thân, có title riêng
- [ ] Facet có volume đã tách route tĩnh; facet còn lại `noindex, follow`
- [ ] Trang danh mục có mô tả riêng (không chỉ list sản phẩm)
- [ ] Giá trong schema là số nguyên + `priceCurrency`
- [ ] `AggregateRating` chỉ khi có review thật
- [ ] Product feed khớp schema (giá, tồn kho, URL, ảnh)
- [ ] Sitemap chỉ chứa sản phẩm index được, `lastModified` thật
- [ ] Trang search nội bộ, giỏ, thanh toán, tài khoản đều `noindex`
- [ ] Ảnh chính có `priority`, gallery lazy load, khung tỷ lệ cố định
- [ ] Banner khuyến mãi có `min-height` chống CLS
- [ ] Bộ lọc/sắp xếp xử lý phía server bằng URL param
- [ ] Đã chạy Rich Results Test cho 3 mẫu sản phẩm (còn hàng, hết hàng, có review)
- [ ] Đã kiểm tra Merchant Center không có disapprove
