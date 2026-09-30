# 13 — Đặc thù tiếng Việt & thị trường Việt Nam

Chủ điểm bị bỏ qua nhiều nhất. Phần lớn hướng dẫn SEO trên internet viết cho tiếng Anh, và một số ngưỡng **không chuyển thẳng** được sang tiếng Việt.

---

## 13.1. Độ dài title: đo bằng pixel, không bằng ký tự

Google cắt title theo **chiều rộng hiển thị** (khoảng 600px trên desktop), không theo số ký tự. Vì vậy con số "60 ký tự" lưu truyền là một xấp xỉ cho tiếng Anh.

Tiếng Việt diễn đạt cùng một khái niệm bằng **nhiều ký tự hơn**:

| Tiếng Anh | Ký tự | Tiếng Việt | Ký tự |
| --- | --- | --- | --- |
| SEO service pricing | 20 | Bảng giá dịch vụ SEO | 21 |
| Air conditioner installation | 29 | Lắp đặt máy điều hòa | 21 |
| Industrial steel structure | 27 | Kết cấu thép công nghiệp | 25 |
| Buy cheap laptops online | 25 | Mua laptop giá rẻ online | 24 |

Thực tế gần nhau hơn tôi tưởng, nhưng **dấu tiếng Việt và tổ hợp phụ âm làm chiều rộng ký tự không đồng đều** — không thể suy ra pixel từ số ký tự.

**Hướng dẫn thực dụng cho tiếng Việt:**

| Trường | Ngưỡng an toàn | Ghi chú |
| --- | --- | --- |
| Title | 50–58 ký tự | Kiểm tra bằng công cụ đo pixel, không đếm ký tự |
| Description | 140–155 ký tự | Tiếng Việt thường bị cắt sớm hơn tiếng Anh |
| H1 | Không giới hạn cứng | Ưu tiên rõ nghĩa hơn ngắn |

**Cách kiểm tra thật:** dùng tính năng xem trước SERP của SEO tool, hoặc kiểm tra trên Google thật sau khi index. Đừng tin ngưỡng ký tự.

> Script `check-seo.mjs` cảnh báo title > 65 ký tự. Đây là **ngưỡng chặn lỗi rõ ràng**, không phải ngưỡng tối ưu. Với tiếng Việt, hãy xem cảnh báo ở mức 58 ký tự.

---

## 13.2. Dấu tiếng Việt — 6 cái bẫy kỹ thuật

### Bẫy 1: `đ` không tách được bằng NFD

```ts
// ❌ 'đ' giữ nguyên, slug thành "đen-led"
'dèn led đỏ'.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
// → "đen led đo"

// ✅ Phải xử lý 'đ' riêng
export function slugify(input: string) {
  return input
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[đĐ]/g, 'd')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}
```

### Bẫy 2: Unicode NFC vs NFD

Cùng một chữ có thể được lưu ở hai dạng khác nhau:

```ts
'ế'.normalize('NFC').length   // 1
'ế'.normalize('NFD').length   // 3
'ế'.normalize('NFC') === 'ế'.normalize('NFD')   // false!
```

**Hậu quả:** hai chuỗi "giống hệt" khi nhìn nhưng so sánh `===` trả `false` → slug trùng, cache key khác nhau, tìm kiếm không khớp, dữ liệu trùng trong DB.

**Quy tắc:** chuẩn hoá về **NFC** ở tầng lưu trữ và ở mọi chỗ so sánh/khởi tạo slug.

```ts
export const normalizeVi = (s: string) => s.normalize('NFC').trim()
```

### Bẫy 3: Font thiếu subset tiếng Việt

```tsx
// ❌ Chữ có dấu bị fallback, lệch dòng, CLS
const inter = Inter({ subsets: ['latin'] })

// ✅
const inter = Inter({ subsets: ['latin', 'vietnamese'] })
```

### Bẫy 4: OG image lỗi dấu

`ImageResponse` mặc định không phải font nào cũng có đủ glyph tiếng Việt → ảnh OG hiện ô vuông. Phải nạp font tường minh (xem file 04, mục 4.5).

### Bẫy 5: `hreflang` sai mã

| Sai | Đúng | Vì |
| --- | --- | --- |
| `vn` | `vi` hoặc `vi-VN` | `vn` là mã **quốc gia**, không phải mã **ngôn ngữ** |
| `vi_VN` (dấu gạch dưới) trong `hreflang` | `vi-VN` | `hreflang` dùng gạch ngang; gạch dưới chỉ dùng trong `og:locale` |
| `vietnamese` | `vi` | Phải là mã ISO 639-1 |

> Lưu ý phân biệt: `hreflang="vi-VN"` (gạch ngang) nhưng `openGraph.locale = "vi_VN"` (gạch dưới). Đây là hai chuẩn khác nhau, không phải lỗi đánh máy.

### Bẫy 6: So sánh/khớp chuỗi trong tìm kiếm nội bộ

Người dùng gõ không dấu, dữ liệu lưu có dấu. Tìm kiếm nội bộ sẽ không khớp nếu so sánh thô. Cần chuẩn hoá cả hai phía (bỏ dấu + NFC) trước khi so khớp.

---

## 13.3. Người Việt gõ không dấu

Một phần đáng kể truy vấn tiếng Việt được gõ **không dấu** (`bang gia seo`, `may lanh daikin`). Google xử lý được, nhưng điều này ảnh hưởng đến công việc của bạn:

| Việc | Hành động |
| --- | --- |
| Nghiên cứu từ khoá | Thu thập **cả** biến thể có dấu và không dấu |
| Slug | Không dấu (đã chuẩn) |
| Tạo trang riêng cho biến thể không dấu | ❌ **Không** — sẽ tạo trùng lặp nội dung |
| Nội dung | Viết có dấu đúng chính tả; Google khớp cả hai |
| Thẻ meta | Có dấu, đúng ngữ pháp |
| Volume | Biến thể không dấu thường có volume riêng — cộng dồn khi đánh giá tiềm năng |

**Sai lầm cần tránh:** tạo `/bang-gia-seo` và `/bang-gia-seo-khong-dau` cho hai biến thể. Đây là tự tạo trùng lặp.

---

## 13.4. Từ đồng nghĩa và cách gọi khác nhau

Tiếng Việt có nhiều cách gọi cùng một thứ, và Google **không stemming tốt** như với tiếng Anh:

| Khái niệm | Các cách gọi |
| --- | --- |
| Điều hoà | máy lạnh, máy điều hòa, điều hòa nhiệt độ |
| Điện thoại | dế, phone, smartphone, mobile |
| Xe máy | xe gắn máy, moto, xe hai bánh |
| Bất động sản | nhà đất, địa ốc, BĐS |
| Thép | sắt thép, kết cấu thép, thép xây dựng |

**Hệ quả:** exact match quan trọng hơn tiếng Anh. Cần:
- Bảng đồng nghĩa cho ngành của bạn (lưu trong `site-config`).
- Dùng biến thể trong H2/H3 và nội dung, không nhồi vào title.
- Cân nhắc trang riêng **chỉ khi** biến thể có volume đáng kể và intent khác — nếu không, gộp vào một trang.

---

## 13.5. Từ tiếng Anh xen kẽ

Người Việt dùng nhiều từ tiếng Anh trong truy vấn: `seo`, `marketing online`, `app`, `shop`, `review`, `giá`, `uy tín`.

Title tự nhiên thường **trộn** hai ngôn ngữ:
```
"Dịch vụ SEO tổng thể cho website bán hàng"     ← tự nhiên
"Dịch vụ tối ưu hóa công cụ tìm kiếm website"   ← cứng, ít ai gõ
```

Ưu tiên cách nói mà khách hàng thật sự dùng, không phải bản dịch thuần Việt.

---

## 13.6. Địa danh và local SEO

### Biến thể tên địa danh

| Chuẩn | Biến thể phổ biến |
| --- | --- |
| Thành phố Hồ Chí Minh | TP.HCM, HCM, Sài Gòn, TPHCM |
| Hà Nội | HN, Hà Nội |
| Đà Nẵng | ĐN |

Với local SEO, dùng **một** dạng chuẩn trong title/heading và các biến thể trong nội dung.

### Cảnh báo về sáp nhập hành chính

Việt Nam đã và đang thực hiện sáp nhập đơn vị hành chính cấp tỉnh. Tên tỉnh/thành, mã bưu chính và địa giới có thể **thay đổi**.

**Hệ quả:** đừng hard-code danh sách tỉnh/thành trong code. Lưu trong dữ liệu, có ngày hiệu lực, và kiểm tra danh mục hiện hành trước khi làm local SEO. Trang local cũ có thể cần redirect nếu địa danh không còn tồn tại.

### Google Business Profile quan trọng hơn schema

Với local SEO, yếu tố quyết định là **Google Business Profile**: xác minh, danh mục ngành đúng, ảnh thật, giờ mở cửa, bài đăng, review. `LocalBusiness` schema là bổ trợ, không thay thế.

**NAP nhất quán** (Name–Address–Phone) giữa: website, GBP, Facebook, các danh bạ. Sai lệch NAP làm loãng tín hiệu.

---

## 13.7. Thị trường tìm kiếm Việt Nam

Thị phần công cụ tìm kiếm tại Việt Nam (Statcounter, tháng 8/2026, mẫu khảo sát):

| Công cụ | Thị phần |
| --- | --- |
| Google | **94,72%** |
| CocCoc | 4,44% |
| Bing | 0,47% |
| Yahoo! | 0,27% |
| DuckDuckGo | 0,04% |
| Yandex | 0,02% |

Nguồn: [Statcounter — Search Engine Market Share Viet Nam](https://gs.statcounter.com/search-engine-market-share/all/viet-nam)

> Đây là số liệu **mẫu khảo sát website tham gia**, không phải toàn bộ thị trường. Dùng để định hướng phân bổ công sức, không phải số tuyệt đối.

### Kết luận phân bổ công sức

| Kênh | Mức đầu tư | Lý do |
| --- | --- | --- |
| Google | ~95% công sức | Gần như toàn bộ |
| CocCoc | Thấp, chỉ kiểm tra tương thích | 4,4% và đang thu hẹp |
| Bing | Rất thấp — chỉ xác minh + IndexNow | 0,47%, nhưng hiển thị trên Windows/Copilot |
| Khác | Bỏ qua | < 0,3% |

**Việc cần làm với Bing (chi phí gần bằng 0):**
- Xác minh Bing Webmaster Tools
- Bật IndexNow (Bing hỗ trợ; Google **không**)
- Submit sitemap

```ts
// app/api/indexnow/route.ts — gọi sau khi publish nội dung mới
export async function POST(req: Request) {
  const { urls } = await req.json()
  await fetch('https://api.indexnow.org/indexnow', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      host: 'example.com',
      key: process.env.INDEXNOW_KEY,
      keyLocation: `https://example.com/${process.env.INDEXNOW_KEY}.txt`,
      urlList: urls,
    }),
  })
  return Response.json({ ok: true })
}
```

### Kênh ngoài tìm kiếm ảnh hưởng SEO

Ở Việt Nam, các nền tảng sau tạo **brand search** — và brand search là tín hiệu thật:

| Kênh | Tác động |
| --- | --- |
| Zalo (OA, OA Plus) | Kênh liên hệ chính; tăng nhận diện thương hiệu |
| Facebook Page | Traffic + tín hiệu thương hiệu |
| YouTube | Video SEO, nhúng vào trang |
| TikTok | Nhận diện, đặc biệt nhóm trẻ |

Không phải SEO kỹ thuật, nhưng nằm trong bức tranh tổng thể. Ghi nhận trong `site-config` để không bỏ sót `sameAs` trong `Organization` schema.

---

## 13.8. Đo lường và quyền riêng tư

- **GA4 + Search Console** là bộ tối thiểu. GSC có dữ liệu truy vấn tiếng Việt chính xác hơn GA4.
- Việt Nam có **Nghị định 13/2023/NĐ-CP** về bảo vệ dữ liệu cá nhân. Nếu thu thập dữ liệu người dùng (form, analytics có định danh, cookie), cần rà soát với bộ phận pháp chế — đây không phải kết luận pháp lý, chỉ là điểm cần kiểm tra.
- Nếu có người dùng EU: **Consent Mode v2** ảnh hưởng trực tiếp đến lượng dữ liệu đo được. Thiếu consent → dữ liệu GA4 bị thiếu, dẫn đến quyết định SEO sai.

---

## 13.9. Kiểm tra tự động cho tiếng Việt

Thêm vào script kiểm tra:

```js
// Cảnh báo nếu phát hiện slug/kết quả chứa ký tự có dấu
const hasDiacritics = (s) => /[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]/i.test(s)

if (hasDiacritics(route)) {
  errors.push(`${route}: URL chứa ký tự có dấu — slug phải không dấu`)
}
```

Và kiểm tra font subset:

```bash
# Cảnh báo nếu next/font thiếu subset vietnamese
grep -rn "subsets" app/ | grep -v "vietnamese" && echo "⚠ Thiếu subset vietnamese"
```

---

## 13.10. Checklist tiếng Việt

- [ ] Title ≤ 58 ký tự, đã kiểm tra hiển thị thật (không chỉ đếm ký tự)
- [ ] Description ≤ 155 ký tự
- [ ] `slugify` xử lý đúng `đ/Đ`
- [ ] Chuẩn hoá NFC ở tầng lưu trữ và so sánh
- [ ] Mọi `next/font` có subset `vietnamese`
- [ ] `ImageResponse` nạp font có glyph tiếng Việt
- [ ] `hreflang` dùng `vi` hoặc `vi-VN`, không dùng `vn`
- [ ] `og:locale` dùng `vi_VN` (gạch dưới)
- [ ] `<html lang="vi">`
- [ ] Slug không chứa ký tự có dấu
- [ ] Không có trang riêng cho biến thể không dấu
- [ ] Bảng đồng nghĩa ngành đã lưu trong `site-config`
- [ ] Local SEO: dùng một dạng địa danh chuẩn
- [ ] Không hard-code danh sách tỉnh/thành (sáp nhập hành chính)
- [ ] Google Business Profile đã xác minh và NAP nhất quán
- [ ] Bing Webmaster Tools xác minh + IndexNow (chi phí thấp)
- [ ] `sameAs` trong `Organization` liệt kê đủ kênh thật (Zalo, Facebook, YouTube, TikTok)
- [ ] Đã rà soát yêu cầu về dữ liệu cá nhân với pháp chế
- [ ] Nếu có người dùng EU: Consent Mode v2 đã cấu hình
