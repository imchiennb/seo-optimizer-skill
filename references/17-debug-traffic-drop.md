# 17 — Debug khi traffic tụt

File 10 là catalog lỗi. File này là **quy trình chẩn đoán** khi bạn chỉ biết "traffic đang giảm".

---

## 17.1. Nguyên tắc đầu tiên: tìm cái gì đã thay đổi

Trước khi đổ lỗi cho thuật toán, trả lời: **có gì thay đổi trong khoảng thời gian đó không?**

| Câu hỏi | Cách kiểm tra |
| --- | --- |
| Có deploy không? | `git log --since="2 weeks ago" --oneline` |
| Deploy đó có đổi route/metadata/config? | `git diff` giữa hai tag |
| Có đổi DNS / CDN / hosting? | Lịch sử thay đổi hạ tầng |
| Có đổi `robots.txt` không? | So sánh với bản lưu |
| Có ai sửa `next.config` không? | `git log -p next.config.*` |
| Có cập nhật Next.js không? | `git log -p package.json` |
| CMS có đổi cấu trúc URL không? | So sánh sitemap hiện tại với bản lưu |
| Có sự kiện bên ngoài? (dịch bệnh, mùa vụ, tin tức) | Kiểm tra Google Trends |
| Có đối thủ mới nổi? | Kiểm tra SERP thủ công cho 10 từ khoá chính |

**Trong ~70% trường hợp, nguyên nhân là một thay đổi của chính bạn.** Thuật toán là giả thuyết cuối cùng, không phải đầu tiên.

---

## 17.2. Cây quyết định theo thời gian

### Tụt trong vài giờ

```
Site có truy cập được không?
├── Không → 5xx / DNS / hosting / SSL hết hạn
└── Có
    ├── curl thấy noindex? → rò rỉ robots/meta từ deploy gần nhất
    ├── robots.txt đổi? → Disallow nhầm
    ├── Trang trắng / nội dung thiếu? → lỗi build hoặc client-only render
    └── Redirect loop? → cấu hình redirect
```

**Đây gần như luôn là lỗi kỹ thuật, không phải thuật toán.** Thuật toán không tác động trong vài giờ.

### Tụt trong 1–3 ngày

```
├── GSC có Manual action / Security issue? → xử lý ngay
├── Deploy có đổi URL/canonical? → kiểm tra snapshot diff
├── Sitemap còn hợp lệ? → kiểm tra trong GSC
├── Số URL index giảm? → kiểm tra Pages report
└── Chỉ một số URL? → kiểm tra riêng nhóm đó
```

### Tụt trong 1–2 tuần

```
├── Có core update / spam update không? → kiểm tra lịch sử update của Google
├── Tất cả site cùng ngành đều tụt? → yếu tố thị trường/thuật toán
├── Chỉ site bạn tụt? → vấn đề của bạn
├── Mất rich result / featured snippet? → kiểm tra SERP thủ công
└── Xuất hiện AI Overview cho truy vấn? → traffic giảm là hệ quả cấu trúc SERP, không phải lỗi
```

### Tụt dần trong 1–3 tháng

```
├── Nội dung lỗi thời so với đối thủ? → cập nhật
├── Cannibalization tích luỹ (nhiều trang mới cùng chủ đề)? → gộp/chuẩn hoá
├── Mất backlink dần? → kiểm tra backlink profile
├── CWV xấu đi? → kiểm tra CWV report
├── Thêm nhiều third-party script? → kiểm tra INP
└── Site mỏng dần (nhiều trang mới chất lượng thấp)? → dọn dẹp
```

---

## 17.3. Phân biệt bốn kiểu "tụt"

Đây là bước chẩn đoán quan trọng nhất và hay bị bỏ qua. Dùng báo cáo Performance trong GSC, chế độ so sánh hai kỳ.

| Impressions | Position | Clicks/CTR | Chẩn đoán | Hướng xử lý |
| --- | --- | --- | --- | --- |
| ↓ giảm | ↓ tụt | ↓ giảm | Mất xếp hạng thật | Nội dung, backlink, E-E-A-T |
| ↓ giảm | — | ↓ giảm | Mất coverage/index | Index, canonical, chất lượng trang |
| — giữ | — giữ | ↓ giảm | **SERP thay đổi** (AI Overview, nhiều ads, rich result mất) | Không phải lỗi của bạn — điều chỉnh kỳ vọng/chiến lược |
| ↑ tăng | ↓ tụt | ↓ giảm | Đang rank cho nhiều truy vấn không liên quan | Kiểm tra intent, có thể bị "broad match" sai chủ đề |
| — giữ | ↑ tốt hơn | ↓ giảm | Lên top nhưng snippet kém | Viết lại title/description |

> **Trường hợp 3 là phổ biến nhất hiện nay** và nhiều người chẩn đoán sai. Nếu impression và position không đổi mà click giảm, vấn đề nằm ở **giao diện SERP**, không phải website của bạn. Xem 17.6.

### Tách brand và non-brand

Trong GSC, tạo filter so sánh:
- **Brand query**: chứa tên thương hiệu
- **Non-brand query**: phần còn lại

| Brand ↓ | Non-brand giữ | Vấn đề nhận diện thương hiệu, không phải SEO kỹ thuật |
| Brand giữ | Non-brand ↓ | Vấn đề SEO thật |
| Cả hai ↓ | | Vấn đề kỹ thuật hoặc thuật toán |

---

## 17.4. Bộ lệnh chẩn đoán nhanh

```bash
BASE=https://example.com

echo "=== 1. Trang chủ còn sống? ==="
curl -sI "$BASE" | head -1

echo "=== 2. robots.txt có gì lạ? ==="
curl -s "$BASE/robots.txt"

echo "=== 3. Trang chính có bị noindex? ==="
for p in / /bang-gia /san-pham /lien-he; do
  echo -n "$p -> "
  curl -s "$BASE$p" | grep -o 'name="robots"[^>]*' || echo "(không có robots meta)"
done

echo "=== 4. Canonical có đúng? ==="
curl -s "$BASE/" | grep -o '<link rel="canonical"[^>]*>'

echo "=== 5. Sitemap còn hợp lệ và đủ URL? ==="
curl -s "$BASE/sitemap.xml" | grep -c '<loc>'
curl -sI "$BASE/sitemap.xml" | head -1

echo "=== 6. Trang không tồn tại trả gì? ==="
curl -sI "$BASE/khong-ton-tai-xyz-123" | head -1

echo "=== 7. HTML thô còn nội dung? ==="
curl -s "$BASE/" | sed 's/<[^>]*>//g' | tr -s ' \n' ' ' | wc -c

echo "=== 8. TTFB ==="
curl -o /dev/null -s -w "%{time_starttransfer}s\n" "$BASE"

echo "=== 9. Header lạ ==="
curl -sI "$BASE" | grep -iE 'x-robots|location|cache-control'

echo "=== 10. Redirect chain ==="
curl -sIL "$BASE" | grep -iE '^HTTP/|^location'
```

---

## 17.5. So sánh với bản lưu

Nếu bạn có snapshot (xem file 14, `migration/snapshot.sh`):

```bash
./snapshot.sh urls.txt now-snapshot.txt
diff before-snapshot.txt now-snapshot.txt | head -100
```

Nếu chưa có snapshot, dùng **Wayback Machine** để so sánh HTML cũ:

```bash
# Xem Google cache / Wayback
curl -s "http://archive.org/wayback/available?url=example.com/bang-gia"
```

---

## 17.6. Trường hợp đặc biệt: SERP thay đổi, không phải site hỏng

Ngày càng phổ biến: impression giữ nguyên, position giữ nguyên, nhưng click giảm vì SERP có thêm thứ khác.

| Yếu tố SERP | Tác động |
| --- | --- |
| **AI Overview / AI Mode** | Trả lời trực tiếp, người dùng không click |
| Nhiều quảng cáo hơn | Đẩy kết quả organic xuống dưới màn hình |
| Featured snippet | Google trả lời, ít click |
| People Also Ask mở rộng | Chiếm không gian |
| Shopping / Local pack | Chiếm không gian |
| Video carousel | Chiếm không gian |
| Reddit/forum ưu tiên | Google ưu tiên nội dung thảo luận |

**Cách xác nhận:** tìm thủ công 5–10 từ khoá chính trên Google (chế độ ẩn danh, đúng thiết bị/khu vực) và ghi lại:
- Có AI Overview không?
- Vị trí của bạn có bị đẩy dưới màn hình đầu không?
- Có bao nhiêu đơn vị SERP phía trên bạn?

**Kết luận đúng trong trường hợp này:** đây không phải lỗi cần "sửa". Chiến lược đúng là:
1. Đa dạng hoá kênh (không phụ thuộc một mình organic Google)
2. Tối ưu để **được trích dẫn** trong AI answer (cấu trúc rõ, trả lời trực tiếp, dữ liệu gốc)
3. Tập trung vào truy vấn có intent giao dịch (ít bị AI trả lời thay)
4. Xây brand search

---

## 17.7. Checklist chẩn đoán theo thứ tự

Thực hiện **theo đúng thứ tự**, dừng khi tìm ra nguyên nhân:

- [ ] **1.** Site có truy cập được? (uptime, DNS, SSL)
- [ ] **2.** Có lỗi 5xx không? (log, GSC Crawl Stats)
- [ ] **3.** `robots.txt` có thay đổi không?
- [ ] **4.** Có `noindex` / `X-Robots-Tag` rò rỉ không?
- [ ] **5.** HTML thô còn nội dung không?
- [ ] **6.** Canonical còn đúng không?
- [ ] **7.** Có redirect chain/loop mới không?
- [ ] **8.** Trang không tồn tại trả 404 đúng không?
- [ ] **9.** Sitemap còn hợp lệ và đủ URL không?
- [ ] **10.** Số URL index thay đổi thế nào? (GSC Pages)
- [ ] **11.** Có Manual action / Security issue không?
- [ ] **12.** Tách brand vs non-brand — cái nào giảm?
- [ ] **13.** Tách impressions vs clicks — cái nào giảm?
- [ ] **14.** Có AI Overview / SERP feature mới cho truy vấn chính không?
- [ ] **15.** Có core update trong khoảng thời gian đó không?
- [ ] **16.** Đối thủ trong top 5 có thay đổi không?
- [ ] **17.** Có cannibalization không? (nhiều URL cùng truy vấn)
- [ ] **18.** CWV có xấu đi không?
- [ ] **19.** Backlink có mất không?
- [ ] **20.** Có yếu tố mùa vụ / thị trường không?

---

## 17.8. Bảng tra nhanh: triệu chứng → nguyên nhân hàng đầu

| Triệu chứng | Nghi ngờ đầu tiên |
| --- | --- |
| Toàn site biến mất khỏi index | `noindex` rò rỉ, `robots.txt`, manual action, DNS |
| Một nhóm URL biến mất | Canonical sai, `noindex` theo template, lỗi build |
| Impression giảm, position giữ | Mất coverage (trang bị loại khỏi index) |
| Impression giữ, click giảm | SERP feature / AI Overview / title bị viết lại |
| Position tụt đều toàn site | Core update, mất backlink, vấn đề E-E-A-T |
| Position tụt một số trang | Đối thủ mạnh lên, nội dung lỗi thời, cannibalization |
| Trang mới không được index | Chất lượng nội dung, thiếu internal link, `Discovered – not indexed` |
| Rich result mất | Schema lỗi, hoặc Google bỏ hỗ trợ loại đó |
| CTR tụt mạnh | Title/description bị Google viết lại, mất rich result |
| Traffic mobile tụt riêng | Vấn đề mobile-first, CWV mobile, interstitial |
| Traffic một quốc gia tụt | hreflang sai, geo-targeting, đối thủ địa phương |

---

## 17.9. Khi nào kết luận "không phải vấn đề kỹ thuật"

Dừng tìm lỗi kỹ thuật và chuyển hướng khi:

| Điều kiện | Kết luận |
| --- | --- |
| Index đúng, HTML đúng, canonical đúng, không noindex, CWV tốt, nhưng không lên | Vấn đề **nội dung/thẩm quyền**, không phải kỹ thuật |
| Impressions và position không đổi, chỉ click giảm | **SERP thay đổi**, ngoài tầm kiểm soát |
| Toàn bộ ngành cùng giảm | **Yếu tố thị trường** |
| Truy vấn có AI Overview trả lời đầy đủ | **Thay đổi hành vi tìm kiếm** |
| Đối thủ có backlink từ site lớn, bạn không | Vấn đề **off-page** |
| Nội dung của bạn mỏng hơn top 3 rõ rệt | Vấn đề **chất lượng nội dung** |

Nói thẳng kết luận này còn giá trị hơn việc tiếp tục "tối ưu kỹ thuật" vô ích.

---

## 17.10. Mẫu ghi nhận sự cố

```markdown
## Sự cố: organic traffic giảm 34% — phát hiện 2026-04-12

**Phát hiện:** GSC cho thấy clicks giảm từ 12/04 so với tuần trước.
**Mức độ:** ảnh hưởng toàn site / một nhóm URL (chọn)
**Thời điểm bắt đầu:** 2026-04-10

### Điều tra
| Bước | Kết quả |
| --- | --- |
| Uptime | OK |
| 5xx | 0 |
| robots.txt | không đổi (so với bản lưu 01/04) |
| noindex | không có |
| HTML thô | đầy đủ |
| Canonical | đúng |
| Sitemap | 4.210 URL (trước: 4.208) |
| Index | 3.980 → 3.975 (không đáng kể) |
| Manual action | không |
| Brand vs non-brand | cả hai giảm |
| Impressions | -31% |
| Position trung bình | 14,2 → 19,8 |
| SERP check | có AI Overview cho 7/10 từ khoá chính |
| Deploy gần nhất | 2026-04-08 |

### Kết luận
Deploy 08/04 đổi `revalidate` từ 3600 → 60 và thêm `force-dynamic` cho route danh mục
→ TTFB tăng từ 0,4s lên 1,9s → LCP tụt → mất xếp hạng.

### Hành động
1. Revert `force-dynamic` cho route danh mục (rollback ngay)
2. Giữ `revalidate = 3600`
3. Thêm cảnh báo TTFB p75 > 1s

### Theo dõi
Đo lại ngày 2026-05-12.
```
