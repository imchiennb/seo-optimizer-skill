# 10 — Catalog lỗi thường gặp (đặc thù Next.js)

Danh mục này để **grep codebase** và tra cứu khi site không index hoặc tụt hạng.
Mỗi mục: Triệu chứng → Nguyên nhân → Cách sửa → Cách phát hiện.

---

## 10.1. `'use client'` đặt sai chỗ

| | |
| --- | --- |
| **Triệu chứng** | Bundle JS lớn, INP kém; `metadata` không hoạt động; nội dung chậm xuất hiện |
| **Nguyên nhân** | `'use client'` ở `app/layout.tsx`, `app/page.tsx` hoặc component bao ngoài |
| **Sửa** | Đẩy `'use client'` xuống component lá; giữ page/layout là Server Component |
| **Phát hiện** | `grep -rl "'use client'" app/ \| grep -E 'layout\|page'` |

```bash
# Tìm client component ở cấp page/layout
grep -rl "^'use client'" app --include="page.tsx" --include="layout.tsx"
```

---

## 10.2. `metadata` bị export trong Client Component

| | |
| --- | --- |
| **Triệu chứng** | Build warning/error; title dùng mặc định của layout |
| **Nguyên nhân** | File có `'use client'` lại export `metadata` |
| **Sửa** | Tách metadata ra Server Component cha (thường `layout.tsx` hoặc `page.tsx` không có `'use client'`) |
| **Phát hiện** | `grep -rl "'use client'" app \| xargs grep -l "export const metadata"` |

---

## 10.3. Export đồng thời `metadata` và `generateMetadata`

| | |
| --- | --- |
| **Triệu chứng** | Build error hoặc một trong hai bị bỏ qua |
| **Sửa** | Chỉ giữ một. Nếu cần động, dùng `generateMetadata` và trả về object tĩnh khi không có dữ liệu |

---

## 10.4. Quên `await params` / `searchParams` `[15]`+

| | |
| --- | --- |
| **Triệu chứng** | Metadata rỗng, `[object Promise]` trong title, 404 sai, type error |
| **Nguyên nhân** | `params` là Promise từ Next 15 |
| **Sửa** | `const { slug } = await params` — cả trong `page`, `layout`, `generateMetadata`, `generateViewport`, Route Handler |

```bash
# Tìm chỗ dùng params không await
grep -rn "params\." app --include="*.tsx" | grep -v "await"
grep -rn "params: {" app --include="*.tsx" | grep -v "Promise<"
```

---

## 10.5. `metadataBase` bị thiếu

| | |
| --- | --- |
| **Triệu chứng** | `og:image` là URL tương đối hoặc sai host; canonical trỏ sai domain; cảnh báo build |
| **Sửa** | Đặt `metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL)` trong `app/layout.tsx` |
| **Phát hiện** | `curl -sL URL \| grep og:image` — phải là URL tuyệt đối |

---

## 10.6. Bẫy merge nông của metadata

| | |
| --- | --- |
| **Triệu chứng** | og:image mất ở một số trang dù layout gốc có khai báo |
| **Nguyên nhân** | Metadata merge **nông**: page khai `openGraph` mà không có `images` ⇒ mất ảnh của layout |
| **Sửa** | Luôn khai đủ `images` trong mỗi `openGraph`, hoặc dùng helper dùng chung |
| **Phát hiện** | Script kiểm tra `og:image` trên tất cả các mẫu trang |

---

## 10.7. `noindex` rò rỉ vào production

| | |
| --- | --- |
| **Triệu chứng** | Toàn bộ site biến mất khỏi kết quả tìm kiếm |
| **Nguyên nhân** | `robots: { index: false }` đặt ở `app/layout.tsx` cho staging, không tách theo môi trường; hoặc biến env sai |
| **Sửa** | Điều kiện hoá theo `process.env.VERCEL_ENV`/`NODE_ENV`; thêm kiểm tra post-deploy |
| **Phát hiện** | `curl -sI https://example.com \| grep -i x-robots-tag` và `curl -s https://example.com \| grep 'name="robots"'` |

```bash
# Kiểm tra nhanh 10 URL chính
for u in / /san-pham /bai-viet /lien-he; do
  echo -n "$u -> "; curl -s "https://example.com$u" | grep -o '<meta name="robots"[^>]*>' || echo "(không có)"
done
```

---

## 10.8. Chặn JS/CSS trong `robots.txt`

| | |
| --- | --- |
| **Triệu chứng** | Google render trang trắng; `Crawled – currently not indexed` hàng loạt |
| **Nguyên nhân** | `Disallow: /_next/` hoặc `Disallow: /*.js` |
| **Sửa** | Cho phép `/_next/static/`, `/_next/image`, mọi `.js`/`.css` |
| **Phát hiện** | `curl -s https://example.com/robots.txt \| grep -i disallow` |

---

## 10.9. Nội dung chính render client-side

| | |
| --- | --- |
| **Triệu chứng** | `curl` thấy HTML gần rỗng; Google index trang trắng hoặc nội dung "Loading..." |
| **Nguyên nhân** | Fetch trong `useEffect`, `ssr: false`, hoặc toàn bộ nội dung trong Client Component |
| **Sửa** | Fetch trong Server Component; nếu buộc phải client, dùng SSR với dữ liệu truyền từ server |
| **Phát hiện** | So sánh `curl \| wc -c` với kích thước HTML sau render trong DevTools |

```bash
# Nội dung chính có trong HTML thô không?
curl -sL https://example.com/san-pham/abc | grep -c "tên sản phẩm"
```

---

## 10.10. Không gian URL vô hạn

| | |
| --- | --- |
| **Triệu chứng** | Hàng nghìn URL rác trong GSC; crawl budget cạn; `Discovered – not indexed` tăng |
| **Nguyên nhân** | Route `[slug]` không `dynamicParams = false`; search nội bộ index được; facet tổ hợp; phân trang vô hạn |
| **Sửa** | `dynamicParams = false`, `noindex` cho search/facet rác, validate param, `404` cho param sai |
| **Phát hiện** | `grep -rn "\[.*\]" app --include="page.tsx"` rồi kiểm tra từng route |

---

## 10.11. Soft 404

| | |
| --- | --- |
| **Triệu chứng** | GSC báo "Soft 404"; trang rỗng vẫn `200` |
| **Nguyên nhân** | Không gọi `notFound()` khi dữ liệu không tồn tại; hoặc catch lỗi rồi render trang trống |
| **Sửa** | `if (!data) notFound()`; không redirect 404 về trang chủ |

```bash
# Trang không tồn tại phải trả 404
curl -sI https://example.com/san-pham/khong-ton-tai-xyz | head -1
```

---

## 10.12. `force-dynamic` tràn lan

| | |
| --- | --- |
| **Triệu chứng** | TTFB cao, CDN không cache được, chi phí server tăng |
| **Nguyên nhân** | Copy `export const dynamic = 'force-dynamic'` để "cho chắc" |
| **Sửa** | Bỏ đi; dùng static + ISR + on-demand revalidate |
| **Phát hiện** | `grep -rn "force-dynamic" app/` |

---

## 10.13. Prerender quá nhiều URL

| | |
| --- | --- |
| **Triệu chứng** | Build lâu, hết bộ nhớ, deploy timeout |
| **Nguyên nhân** | `generateStaticParams` trả hàng trăm nghìn URL; truy vấn N+1 |
| **Sửa** | Prerender subset "hot", phần còn lại ISR on-demand (`dynamicParams = true` nhưng có validate); chia sitemap bằng `generateSitemaps` |

---

## 10.14. Canonical sai trên trang phân trang / facet

| | |
| --- | --- |
| **Triệu chứng** | Các trang 2,3,4 biến mất khỏi index; nội dung sâu không được crawl |
| **Nguyên nhân** | Canonical tất cả về trang 1 |
| **Sửa** | Canonical tự thân cho mỗi trang phân trang; title riêng |

---

## 10.15. `trailingSlash` không nhất quán

| | |
| --- | --- |
| **Triệu chứng** | Hàng loạt 308 redirect; canonical và link nội bộ khác nhau |
| **Nguyên nhân** | Host tự thêm `/`, canonical không có `/` |
| **Sửa** | Chốt `trailingSlash` trong `next.config.ts`, đồng bộ với `Link`, canonical, sitemap |
| **Phát hiện** | `curl -sI https://example.com/san-pham` và so với canonical |

---

## 10.16. Sitemap chứa URL không nên có

| | |
| --- | --- |
| **Triệu chứng** | GSC báo lỗi trong Sitemaps; URL `noindex` hoặc redirect nằm trong sitemap |
| **Nguyên nhân** | Sinh sitemap từ toàn bộ bảng DB, không lọc |
| **Sửa** | Lọc `published === true`, `noindex === false`, `status === 200`; không đưa URL param |
| **Phát hiện** | Script đối chiếu sitemap với meta robots của từng URL |

---

## 10.17. Xung đột `robots.ts` và `public/robots.txt`

| | |
| --- | --- |
| **Triệu chứng** | Nội dung robots.txt không như mong đợi |
| **Sửa** | Chỉ giữ một nguồn duy nhất |
| **Phát hiện** | `ls app/robots.ts public/robots.txt` |

---

## 10.18. Ảnh gây CLS

| | |
| --- | --- |
| **Triệu chứng** | CLS > 0.25 |
| **Nguyên nhân** | Thiếu `width`/`height`; `fill` không có container tỷ lệ; font swap muộn |
| **Sửa** | Khai báo kích thước hoặc `aspect-ratio`; `next/font` với subset đúng |
| **Phát hiện** | Lighthouse "Avoid large layout shifts"; DevTools Performance |

---

## 10.19. Nhiều `priority` trên `next/image`

| | |
| --- | --- |
| **Triệu chứng** | LCP tệ hơn sau khi "tối ưu" |
| **Nguyên nhân** | Đặt `priority` cho mọi ảnh |
| **Sửa** | Chỉ ảnh LCP; còn lại `loading="lazy"` |
| **Phát hiện** | `grep -c "priority" app/**/*.tsx` — mỗi trang chỉ nên có 1 |

---

## 10.20. Font thiếu subset tiếng Việt

| | |
| --- | --- |
| **Triệu chứng** | Chữ tiếng Việt hiển thị sai font, dấu bị lệch, CLS |
| **Nguyên nhân** | `subsets: ['latin']` |
| **Sửa** | `subsets: ['latin', 'vietnamese']` |
| **Phát hiện** | `grep -rn "subsets" app/` |

---

## 10.21. Redirect chain / loop

| | |
| --- | --- |
| **Triệu chứng** | GSC báo "Redirect error"; crawl chậm |
| **Nguyên nhân** | Nhiều lớp redirect (host → www → https → path) |
| **Sửa** | Gộp về một redirect duy nhất; kiểm tra thứ tự `next.config` redirects, CDN, application |
| **Phát hiện** | `curl -sIL URL \| grep -E '^HTTP/\|^location'` |

---

## 10.22. Nội dung trùng do nhiều nguồn render

| | |
| --- | --- |
| **Triệu chứng** | Google chọn canonical khác; hiệu suất phân tán giữa các URL |
| **Nguyên nhân** | `/san-pham/abc` và `/san-pham/abc?ref=home` và `/product/abc` cùng tồn tại |
| **Sửa** | Canonical + redirect 308 về URL chuẩn; nhất quán trong internal link |

---

## 10.23. Popup / interstitial che nội dung

| | |
| --- | --- |
| **Triệu chứng** | Xếp hạng mobile giảm; trải nghiệm kém |
| **Nguyên nhân** | Modal đăng ký/newsletter hiện ngay khi tải |
| **Sửa** | Hiện sau khi người dùng tương tác hoặc đã cuộn; dùng banner không che nội dung |
| **Phát hiện** | Kiểm thử mobile thật |

---

## 10.24. Không có trang tác giả / thông tin tổ chức

| | |
| --- | --- |
| **Triệu chứng** | Yếu E-E-A-T; không có knowledge panel |
| **Sửa** | Trang `/tac-gia/[slug]`, trang `/gioi-thieu`, `Organization` schema với `sameAs`, thông tin liên hệ thật |

---

## 10.25. Lỗi JSON-LD

| Lỗi | Phát hiện | Sửa |
| --- | --- | --- |
| Double-stringify | `grep -rn "JSON.stringify(JSON.stringify"` | Bỏ lớp ngoài |
| Không escape `<` | Review code | `.replace(/</g, '\\u003c')` |
| JSON-LD chỉ render client | `curl \| grep ld+json` trả 0 | Chuyển vào Server Component |
| Trường bắt buộc thiếu | Rich Results Test | Bổ sung theo bảng ở file 05 |
| Schema mô tả nội dung không có trên trang | Review thủ công | Bỏ hoặc thêm nội dung thật |

---

## 10.26. Lỗi i18n

| Lỗi | Hậu quả | Sửa |
| --- | --- | --- |
| Hreflang không đối xứng | Google bỏ qua cả cụm | Sinh hreflang từ một nguồn dữ liệu chung |
| Dùng `vn` thay `vi` | Sai mã | Dùng `vi` hoặc `vi-VN` |
| Thiếu `x-default` | Không rõ bản mặc định | Thêm `x-default` |
| `<html lang>` sai | Tín hiệu ngôn ngữ lệch | Bind theo locale |
| Máy dịch không hiệu đính | Nội dung chất lượng thấp | Hiệu đính hoặc bỏ index |

---

## 10.27. Bảng tra nhanh: triệu chứng → nghi ngờ

| Triệu chứng | Kiểm tra đầu tiên |
| --- | --- |
| **Mọi request trả `no-store`, CDN báo DYNAMIC** | **`next/headers` trong cây import của layout (10.29)** |
| **`check-seo` báo "0 trang công khai"** | **Layout đọc cookie/header → toàn site dynamic (10.29)** |
| **og:image trên social hiển thị sai/cắt xấu** | **Kích thước khai man trong helper metadata (10.30)** |
| **Mọi locale trả cùng một ngôn ngữ, test vẫn pass** | **Computed key từ enum re-export thành `"undefined"` (10.31)** |
| Site biến mất hoàn toàn | `noindex` rò rỉ (10.7), `robots.txt` (10.8), manual action |
| Trang không được index | HTML thô (10.9), canonical (10.14), chất lượng nội dung |
| Xếp hạng tụt không rõ lý do | Core update, cannibalization, mất backlink, CWV |
| CTR tụt dù impression giữ | Title/description bị viết lại, rich result mất |
| TTFB cao | `force-dynamic` (10.12), cache header, truy vấn DB chậm |
| CLS cao | Ảnh (10.18), font (10.20), banner động |
| INP cao | Bundle lớn (10.1), third-party, re-render |
| Google chọn canonical khác | Trùng lặp (10.22), internal link không nhất quán, sitemap sai |
| Số URL index tăng vọt bất thường | URL vô hạn (10.10), facet, search nội bộ |
| Rich result mất | Schema sai (10.25), hoặc Google ngừng hỗ trợ loại đó |

---

## 10.28. Lệnh grep tổng hợp (chạy một lần trên repo)

```bash
# Tất cả dấu hiệu rủi ro SEO trong codebase Next.js
echo "--- 'use client' ở page/layout ---"
grep -rl "^'use client'" app --include="page.tsx" --include="layout.tsx" 2>/dev/null

echo "--- metadata trong client component ---"
grep -rl "^'use client'" app 2>/dev/null | xargs grep -l "export const metadata" 2>/dev/null

echo "--- force-dynamic ---"
grep -rn "force-dynamic" app 2>/dev/null

echo "--- params không await ---"
grep -rn "params\." app --include="*.tsx" 2>/dev/null | grep -v "await"

echo "--- metadataBase ---"
grep -rn "metadataBase" app 2>/dev/null || echo "THIẾU metadataBase"

echo "--- font subsets ---"
grep -rn "subsets" app 2>/dev/null

echo "--- priority trên Image ---"
grep -rn "priority" app --include="*.tsx" 2>/dev/null

echo "--- JSON-LD double stringify ---"
grep -rn "JSON.stringify(JSON.stringify" app 2>/dev/null

echo "--- noindex không điều kiện ---"
grep -rn "index: false" app 2>/dev/null

echo "--- cả robots.ts và robots.txt ---"
ls app/robots.ts public/robots.txt 2>/dev/null

echo "--- dynamicParams ---"
grep -rn "dynamicParams" app 2>/dev/null || echo "Chưa set dynamicParams ở route động nào"

echo "--- canonical ---"
grep -rn "canonical" app 2>/dev/null | head -20
```

---

## 10.29. `cookies()` giấu sau helper trong layout → toàn site dynamic

| | |
| --- | --- |
| **Triệu chứng** | Mọi response trả `cache-control: private, no-store`; `cf-cache-status: DYNAMIC`; TTFB cao; `check-seo.mjs` báo "0 trang công khai"; `next build` cho mọi route là `ƒ Dynamic` |
| **Nguyên nhân** | Một lời gọi `cookies()` / `headers()` / `draftMode()` nằm trong layout gốc, **hoặc trong một module mà layout import**. Next coi cả cây route dưới layout đó là dynamic |
| **Cách sửa** | Cô lập phần đọc cookie vào client component, hoặc bọc trong `<Suspense>` kèm `cacheComponents` (PPR) |
| **Phát hiện** | `bash <SKILL_DIR>/scripts/grep-antipatterns.sh <app-dir>` mục 21 |

### Vì sao grep thường bỏ sót

Đây là điểm quan trọng nhất của mục này. Trong codebase được tổ chức tử tế, layout **không** import `next/headers` trực tiếp:

```ts
// ❌ grep "next/headers" trên layout.tsx KHÔNG thấy gì
// src/app/[lang]/layout.tsx
import { getPrefsFromCookies } from '@/modules/utils/prefs.server';
const hisPrefs = await getPrefsFromCookies();

// ✅ đây mới là chỗ thật
// src/modules/utils/prefs.server.ts
import { cookies } from 'next/headers';
export async function getPrefsFromCookies() {
  const store = await cookies();
  ...
}
```

Phải lần theo import nội bộ một cấp (kể cả alias `@/` → đọc `paths` trong `tsconfig.json`).

### Quy trình chẩn đoán

```bash
# 1. Có trang nào prerender không?
npm run build 2>&1 | grep -E '○|ƒ'          # ○ Static vs ƒ Dynamic
find .next/server/app -name '*.html' | grep -vE '_(not-found|global-error)'

# 2. Nếu 0 trang → tìm next/headers trong cây import của layout
bash <SKILL_DIR>/scripts/grep-antipatterns.sh src/app

# 3. Xác nhận từ ngoài (sau deploy)
bash <SKILL_DIR>/scripts/audit-url.sh https://example.com /
# → tìm "no-store" và "cf-cache-status: DYNAMIC"
```

---

## 10.30. Helper metadata khai man kích thước ảnh OG

| | |
| --- | --- |
| **Triệu chứng** | `og:image:width`/`height` là 1200×630 nhưng ảnh thật nhỏ hơn nhiều; social card hiển thị cắt xấu, mờ, hoặc không render |
| **Nguyên nhân** | Hàm `normalizeImage` / `buildMetadata` mặc định `width: 1200, height: 630` cho **mọi** ảnh, kể cả ảnh không biết kích thước |
| **Cách sửa** | Truyền kích thước thật; **hoặc bỏ hẳn** `og:image:width`/`height` khi không biết (khai man tệ hơn không khai) |
| **Phát hiện** | `node <SKILL_DIR>/scripts/check-seo.mjs <out-dir>` |

### Ca thật

```ts
// Helper mặc định cho MỌI ảnh
function normalizeImage(img) {
  const base = typeof img === 'string' ? { url: img } : img;
  return { width: 1200, height: 630, alt: SITE.name, ...base };  // ← mặc định
}
```

```tsx
// Trang phim truyền thumbnail từ API, KHÔNG có width/height
images: movie.thumbnailUrl ? [{ url: movie.thumbnailUrl, alt: movie.title }] : undefined,
```

Kết quả trên production — khai 1200×630 cho thumbnail YouTube 480×360:

```html
<meta property="og:image" content="https://i.ytimg.com/vi/xxx/hqdefault.jpg"/>
<meta property="og:image:width" content="1200"/>   <!-- SAI -->
<meta property="og:image:height" content="630"/>   <!-- SAI -->
```

### Bảng kích thước thumbnail YouTube

| Biến thể | Kích thước thật |
| --- | --- |
| `mqdefault.jpg` | 320×180 |
| `hqdefault.jpg` | **480×360** ← mặc định hay dùng |
| `sddefault.jpg` | 640×480 |
| `maxresdefault.jpg` | 1280×720 ✅ đủ chuẩn OG |

Dùng `maxresdefault.jpg` khi có, hoặc tự sinh ảnh OG bằng `ImageResponse`.

> **Bài học tổng quát:** bất kỳ helper nào *điền giá trị mặc định* cho metadata đều có thể đang nói dối. `400` mặc định cho `og:image:width` cũng nguy hiểm như `200` cho một trang không tồn tại.


---

## 10.31. Computed key từ enum re-export → khoá `"undefined"` trong bundle

| | |
| --- | --- |
| **Triệu chứng** | Mọi locale trả về CÙNG một ngôn ngữ (thường là ngôn ngữ mặc định); `Object.keys(map)` chỉ có một phần tử `"undefined"`; **test pass** nhưng production sai |
| **Nguyên nhân** | Bảng tra dùng computed key lấy từ một enum được **re-export qua barrel** |
| **Cách sửa** | Dùng khoá literal; thêm `satisfies Record<...>`; thêm assert lúc module nạp |
| **Phát hiện** | Log `Object.keys(map)` khi build, hoặc assert ngay trong module |

### Ca thật

```ts
// src/modules/i18n/index.ts
import { AppLanguage } from './i18n-context';   // ← re-export từ './i18n-types'
import EN from './languages/en';
import VI from './languages/vi';

export const SupportedLanguages = {
  [AppLanguage.EN?.toString()]: EN,
  [AppLanguage.VI?.toString()]: VI,
} as const;
```

Trong bundle production, `AppLanguage` chưa có mặt lúc module này khởi tạo. Cả hai
computed key đều thành chuỗi `"undefined"`, và **cái sau ghi đè cái trước**:

```
Object.keys(SupportedLanguages)  →  ["undefined"]
```

Kết quả: mọi locale đều rơi vào nhánh dự phòng và trả về tiếng Việt. Hậu quả đo được:
**toàn bộ `/en/*` render title và description tiếng Việt**, trong khi `canonical` và
`og:locale` vẫn đúng — vì chúng tính từ `lang` chứ không từ bảng tra này. Chính sự
"đúng một nửa" đó làm bug khó thấy.

### Vì sao test không bắt được

`jest`/`ts-jest` biên dịch và khởi tạo module theo thứ tự khác bundler. Cùng đoạn code đó
chạy đúng trong test và sai trong bundle. **Đây là lý do phải build thật rồi kiểm tra
output, không chỉ chạy unit test.**

### Cách sửa

```ts
export const SupportedLanguages = {
  vi: VI,
  en: EN,
} as const satisfies Record<Locale, typeof VI>;

// Bảo vệ hồi quy: hỏng thì ném lỗi ngay khi nạp module, thay vì âm thầm sai cả site.
for (const locale of i18nConfig.locales) {
  if (!SupportedLanguages[locale]) {
    throw new Error(`[i18n] SupportedLanguages thiếu locale "${locale}"`);
  }
}
```

### Quy tắc tổng quát

Bất kỳ map nào dùng **computed key lấy từ giá trị import** đều có rủi ro này — đặc biệt
khi giá trị đó đi qua barrel/re-export. Ưu tiên khoá literal, và nếu buộc phải dùng
computed key thì thêm assert để hỏng to và sớm.
