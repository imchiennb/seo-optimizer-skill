#!/usr/bin/env node
/**
 * check-seo.mjs — kiểm tra HTML đã build của một dự án Next.js.
 *
 * Dùng:
 *   node check-seo.mjs [thư_mục...] [--site=https://example.com] [--all]
 *
 * Thư mục HTML theo loại dự án:
 *   App Router     → .next/server/app
 *   Pages Router   → .next/server/pages
 *   Static export  → out
 *   HYBRID (app/ + pages/) → truyền CẢ HAI thư mục:
 *       .next/server/app .next/server/pages
 *
 * Truyền nhiều thư mục sẽ gộp vào một báo cáo, nhờ đó phát hiện được title
 * trùng GIỮA hai router — chạy riêng từng thư mục sẽ bỏ sót.
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
import { join, relative, basename, dirname } from 'node:path'

const args = process.argv.slice(2)
const siteArg = args.find((a) => a.startsWith('--site='))
const SITE = siteArg ? siteArg.split('=')[1] : null
const INCLUDE_INTERNAL = args.includes('--all')
const DIRS = args.filter((a) => !a.startsWith('--'))
if (DIRS.length === 0) DIRS.push('.next/server/app')

// Trang do framework sinh ra, luôn thiếu metadata. Không phải lỗi của bạn.
// Khớp theo TỪNG SEGMENT của route, đúng cho cả hai router và mọi phiên bản.
const FRAMEWORK_INTERNAL = new Set([
  '_not-found',      // App Router
  '_global-error',   // App Router (Next 16)
  '_error',          // cả hai
  '404',             // Pages Router + static export
  '500',             // Pages Router
])

const missing = DIRS.filter((d) => !existsSync(d))
if (missing.length) {
  console.error(`❌ Không tìm thấy: ${missing.join(', ')}`)
  console.error(`   Chạy \`npm run build\` trước, hoặc truyền đúng thư mục:`)
  console.error(`     App Router      : .next/server/app`)
  console.error(`     Pages Router    : .next/server/pages`)
  console.error(`     Hybrid (cả hai) : .next/server/app .next/server/pages`)
  console.error(`     Static export   : out`)
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

const rootLabel = (dir) => {
  const b = basename(dir)
  return b === 'app' || b === 'pages' ? `${basename(dirname(dir))}/${b}` : b
}
const MULTI = DIRS.length > 1

const entries = []
const skipped = new Set()
let totalHtml = 0

for (const dir of DIRS) {
  const html = walk(dir).filter((f) => f.endsWith('.html'))
  totalHtml += html.length
  for (const file of html) {
    const route = '/' + relative(dir, file).replace(/\.html$/, '').replace(/(^|\/)index$/, '')
    if (!INCLUDE_INTERNAL && isInternal(route)) skipped.add(route)
    else entries.push({ file, route, dir })
  }
}

if (totalHtml === 0) {
  console.error(`❌ Không có file .html nào trong: ${DIRS.join(', ')}`)
  process.exit(2)
}

// Cùng một route ở nhiều thư mục output → cấu hình sai
const routeDirs = new Map()
for (const { route, dir } of entries) {
  routeDirs.set(route, [...(routeDirs.get(route) ?? []), dir])
}

const titles = new Map()
const descs = new Map()

for (const { file, route, dir } of entries) {
  const html = readFileSync(file, 'utf8')
  const label = MULTI ? `[${rootLabel(dir)}] ${route}` : route

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
  if (!title) errors.push(`${label}: thiếu <title>`)
  if (!noindex && !canonical) errors.push(`${label}: thiếu canonical nhưng KHÔNG noindex`)

  if (canonical) {
    if (!/^https?:\/\//i.test(canonical)) {
      errors.push(`${label}: canonical không phải URL tuyệt đối → ${canonical}`)
    } else if (/^http:\/\//i.test(canonical)) {
      errors.push(`${label}: canonical dùng HTTP → ${canonical}`)
    }
    if (noindex) warnings.push(`${label}: vừa noindex vừa có canonical (thường không cần)`)
  }

  // ── ⚠️ CẢNH BÁO ──────────────────────────────────────────────────────
  if (title && title.length > 65) warnings.push(`${label}: title dài ${title.length} ký tự (nên ≤ 60)`)
  if (title && title.length < 15) warnings.push(`${label}: title ngắn ${title.length} ký tự`)
  if (!description) warnings.push(`${label}: thiếu meta description`)
  if (description && (description.length < 50 || description.length > 165)) {
    warnings.push(`${label}: description dài ${description.length} ký tự (nên 140–160)`)
  }
  if (!noindex) {
    if (!ogImage) warnings.push(`${label}: thiếu og:image`)
    if (!ogTitle) warnings.push(`${label}: thiếu og:title`)
    if (h1Count === 0) warnings.push(`${label}: không có <h1>`)
    if (h1Count > 1) warnings.push(`${label}: có ${h1Count} thẻ <h1>`)
    if (jsonLd === 0) warnings.push(`${label}: không có JSON-LD`)
  }
  if (!lang) warnings.push(`${label}: <html> thiếu thuộc tính lang (nên có, ví dụ lang="vi")`)
  if (imgNoAlt > 0) warnings.push(`${label}: ${imgNoAlt} thẻ <img> thiếu alt`)
  if (SITE && canonical && !canonical.startsWith(SITE)) {
    warnings.push(`${label}: canonical khác site (${canonical})`)
  }

  // Chỉ trang index được mới tính vào trùng lặp title/description
  if (!noindex) {
    if (title) titles.set(title, [...(titles.get(title) ?? []), label])
    if (description) descs.set(description, [...(descs.get(description) ?? []), label])
  }
}

for (const [route, dirs] of routeDirs) {
  if (dirs.length > 1) {
    errors.push(
      `route "${route}" tồn tại ở ${dirs.length} thư mục output (${dirs.join(', ')}) — Next chỉ phục vụ một bản, bỏ bản trùng`,
    )
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
console.log(`\nĐã kiểm tra ${entries.length} trang HTML`)
console.log(`Thư mục: ${DIRS.join(', ')}`)
const skippedList = [...skipped]
if (skippedList.length) {
  console.log(`Bỏ qua ${skippedList.length} trang nội bộ của framework: ${skippedList.join(', ')}`)
  console.log(`(dùng --all để kiểm tra cả chúng)`)
}

for (const dir of DIRS) {
  if (basename(dir) !== 'app') continue
  const sibling = join(dirname(dir), 'pages')
  if (existsSync(sibling) && !DIRS.some((d) => basename(d) === 'pages')) {
    console.log(`\n⚠️  Có '${sibling}' nhưng bạn chưa truyền vào — dự án hybrid?`)
    console.log(`   Chạy lại với: ${DIRS.join(' ')} ${sibling}`)
  }
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
