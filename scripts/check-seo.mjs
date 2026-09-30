#!/usr/bin/env node
/**
 * check-seo.mjs — kiểm tra HTML đã build của một dự án Next.js.
 *
 * Dùng:
 *   node check-seo.mjs [thư_mục_HTML] [--site=https://example.com] [--all]
 *
 * Thư mục HTML theo loại dự án:
 *   App Router     → .next/server/app
 *   Pages Router   → .next/server/pages
 *   Static export  → out
 *
 * Mặc định bỏ qua các trang nội bộ do framework sinh ra (không phải trang
 * thật của bạn, và luôn thiếu metadata):
 *   App Router  : _not-found, _global-error, _error
 *   Pages Router: 404, 500, _error
 * Dùng --all để kiểm tra cả chúng.
 *
 * Exit code:
 *   0 = không có lỗi chặn deploy
 *   1 = có lỗi chặn deploy
 *   2 = không đọc được input
 *
 * Mức độ:
 *   ❌ CHẶN  — phá vỡ việc index hoặc tính đúng đắn của SEO
 *   ⚠️  CẢNH BÁO — vấn đề thật, nên sửa, nhưng không chặn deploy
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, relative } from 'node:path'

const args = process.argv.slice(2)
const siteArg = args.find((a) => a.startsWith('--site='))
const SITE = siteArg ? siteArg.split('=')[1] : null
const INCLUDE_INTERNAL = args.includes('--all')
const ROOT = args.find((a) => !a.startsWith('--')) ?? '.next/server/app'

// Trang do framework sinh ra, luôn thiếu metadata. Không phải lỗi của bạn.
// Khớp theo TỪNG SEGMENT của route, cho cả hai router.
const FRAMEWORK_INTERNAL = new Set([
  '_not-found',      // App Router
  '_global-error',   // App Router (Next 16)
  '_error',          // cả hai
  '404',             // Pages Router
  '500',             // Pages Router
])

if (!existsSync(ROOT)) {
  console.error(`❌ Không tìm thấy '${ROOT}'.`)
  console.error(`   Chạy \`npm run build\` trước, hoặc truyền đúng thư mục:`)
  console.error(`     App Router   : .next/server/app`)
  console.error(`     Pages Router : .next/server/pages`)
  console.error(`     Static export: out`)
  process.exit(2)
}

const errors = []
const warnings = []

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name)
    return statSync(p).isDirectory() ? walk(p) : [p]
  })
}

const pick = (html, re) => html.match(re)?.[1]?.trim()
const isInternal = (route) =>
  route.split('/').filter(Boolean).some((seg) => FRAMEWORK_INTERNAL.has(seg))

const allHtml = walk(ROOT).filter((f) => f.endsWith('.html'))
if (allHtml.length === 0) {
  console.error(`❌ Không có file .html nào trong '${ROOT}'.`)
  process.exit(2)
}

const skipped = []
const files = []
for (const file of allHtml) {
  const route = '/' + relative(ROOT, file).replace(/\.html$/, '').replace(/(^|\/)index$/, '')
  if (!INCLUDE_INTERNAL && isInternal(route)) skipped.push(route)
  else files.push({ file, route })
}

const titles = new Map()
const descs = new Map()

for (const { file, route } of files) {
  const html = readFileSync(file, 'utf8')

  const title = pick(html, /<title[^>]*>([\s\S]*?)<\/title>/i)
  const description = pick(html, /<meta\s+name="description"\s+content="([^"]*)"/i)
  const canonical = pick(html, /<link\s+rel="canonical"\s+href="([^"]*)"/i)
  const ogImage = /<meta\s+property="og:image"/i.test(html)
  const ogTitle = /<meta\s+property="og:title"/i.test(html)
  const noindex = /<meta\s+name="robots"[^>]*content="[^"]*noindex/i.test(html)
  const h1Count = (html.match(/<h1[\s>]/gi) ?? []).length
  const jsonLd = (html.match(/application\/ld\+json/gi) ?? []).length
  const imgNoAlt = (html.match(/<img(?![^>]*\balt=)[^>]*>/gi) ?? []).length
  const lang = pick(html, /<html[^>]*\blang="([^"]*)"/i)

  // ── ❌ CHẶN ──────────────────────────────────────────────────────────
  if (!title) errors.push(`${route}: thiếu <title>`)

  if (!noindex) {
    if (!canonical) errors.push(`${route}: thiếu canonical nhưng KHÔNG noindex`)
  }

  if (canonical) {
    if (!/^https?:\/\//i.test(canonical)) {
      errors.push(`${route}: canonical không phải URL tuyệt đối → ${canonical}`)
    } else if (/^http:\/\//i.test(canonical)) {
      errors.push(`${route}: canonical dùng HTTP → ${canonical}`)
    }
    if (noindex) warnings.push(`${route}: vừa noindex vừa có canonical (thường không cần)`)
  }

  // ── ⚠️ CẢNH BÁO ──────────────────────────────────────────────────────
  if (title && title.length > 65) warnings.push(`${route}: title dài ${title.length} ký tự (nên ≤ 60)`)
  if (title && title.length < 15) warnings.push(`${route}: title ngắn ${title.length} ký tự`)
  if (!description) warnings.push(`${route}: thiếu meta description`)
  if (description && (description.length < 50 || description.length > 165)) {
    warnings.push(`${route}: description dài ${description.length} ký tự (nên 140–160)`)
  }
  if (!noindex) {
    if (!ogImage) warnings.push(`${route}: thiếu og:image`)
    if (!ogTitle) warnings.push(`${route}: thiếu og:title`)
    if (h1Count === 0) warnings.push(`${route}: không có <h1>`)
    if (h1Count > 1) warnings.push(`${route}: có ${h1Count} thẻ <h1>`)
    if (jsonLd === 0) warnings.push(`${route}: không có JSON-LD`)
  }
  if (!lang) warnings.push(`${route}: <html> thiếu thuộc tính lang (nên có, ví dụ lang="vi")`)
  if (imgNoAlt > 0) warnings.push(`${route}: ${imgNoAlt} thẻ <img> thiếu alt`)
  if (SITE && canonical && !canonical.startsWith(SITE)) {
    warnings.push(`${route}: canonical khác site (${canonical})`)
  }

  // Chỉ trang index được mới tính vào trùng lặp title/description
  if (!noindex) {
    if (title) titles.set(title, [...(titles.get(title) ?? []), route])
    if (description) descs.set(description, [...(descs.get(description) ?? []), route])
  }
}

for (const [t, routes] of titles) {
  if (routes.length > 1) {
    errors.push(
      `Title trùng ở ${routes.length} trang: "${t}" → ${routes.slice(0, 4).join(', ')}${routes.length > 4 ? '…' : ''}`,
    )
  }
}
for (const [, routes] of descs) {
  if (routes.length > 1) {
    warnings.push(`Description trùng: ${routes.slice(0, 4).join(', ')}${routes.length > 4 ? '…' : ''}`)
  }
}

// ── Báo cáo ────────────────────────────────────────────────────────────
console.log(`\nĐã kiểm tra ${files.length} trang HTML trong '${ROOT}'`)
if (skipped.length) {
  console.log(`Bỏ qua ${skipped.length} trang nội bộ của framework: ${skipped.join(', ')}`)
  console.log(`(dùng --all để kiểm tra cả chúng)`)
}
console.log()

if (warnings.length) {
  console.log(`⚠️  ${warnings.length} cảnh báo:`)
  warnings.slice(0, 60).forEach((w) => console.log(`   - ${w}`))
  if (warnings.length > 60) console.log(`   … và ${warnings.length - 60} cảnh báo khác`)
  console.log()
}
if (errors.length) {
  console.error(`❌ ${errors.length} lỗi chặn deploy:`)
  errors.forEach((e) => console.error(`   - ${e}`))
  console.error()
  process.exit(1)
}
console.log('✅ Không có lỗi SEO chặn deploy\n')
