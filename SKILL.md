---
name: seo-optimizer
description: "Audit and optimize technical SEO for any Next.js project (App Router, Pages Router or hybrid). Use for metadata, sitemap, robots, JSON-LD, canonical, hreflang, Core Web Vitals, indexing and traffic-drop issues."
---

# SEO Optimizer — Next.js

Audit & tối ưu SEO kỹ thuật cho mọi dự án Next.js (App Router, Pages Router, hybrid).

**Bắt đầu:** đọc `references/00-index.md` (bảng routing 5 tầng), rồi chạy discovery:

```bash
bash <SKILL_DIR>/scripts/detect-project.sh <project-dir>
bash <SKILL_DIR>/scripts/grep-antipatterns.sh <app-dir>
npm run build && node <SKILL_DIR>/scripts/check-seo.mjs .next/server/app --src=src/app --site=<domain>
# Pages Router: .next/server/pages · static export: out · --all gồm cả trang nội bộ framework
# exit 3 = build không có trang công khai nào (toàn site dynamic — tìm next/headers trong layout)
```

**Bất biến:** HTML thô là nguồn sự thật (verify bằng `curl`) · một URL = một canonical · audit trước, sửa sau, verify lại bằng output thật · Pages Router vẫn được hỗ trợ đầy đủ ở Next 16.x.

Cấm: meta keywords · `rel=next/prev` · `noindex` trang phân trang · canonical phân trang → trang 1 · `priority` mọi ảnh · `force-dynamic` toàn site · khẳng định "đã fix" khi chưa verify.
