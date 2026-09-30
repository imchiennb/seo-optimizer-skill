#!/usr/bin/env node
/**
 * check-seo.mjs — kiểm tra HTML đã build của một app Next.js App Router.
 *
 * Dùng:
 *   node scripts/check-seo.mjs [thư_mục_HTML] [--site=https://example.com]
 *
 * Mặc định quét `.next/server/app` (HTML đã prerender).
 * Với `output: 'export'`, quét `out`.
 *
 * Exit code 1 nếu có lỗi chặn deploy (thiếu title/canonical/h1, title trùng…).
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, relative } from 'node:path'

const args = process.argv.slice(2)
const siteArg = args.find((a) => a.startsWith('--site='))
const SITE = siteArg ? siteArg.split('=')[1] : null
const ROOT = args.find((a) => !a.startsWith('--')) ?? '.next/server/app'

if (!existsSync(ROOT)) {
  console.error(`❌ Không tìm thấy '${ROOT}'. Chạy \`npm run build\` trước, hoặc truyền đúng thư mục.`)
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

const files = walk(ROOT).filter((f) => f.endsWith('.html'))
if (files.length === 0) {
  console.error(`❌ Không có file .html nào trong '${ROOT}'.`)
  process.exit(2)
}

const titles = new Map()
const descs = new Map()

for (const file of files) {
  const html = readFileSync(file, 'utf8')
  const route = '/' + relative(ROOT, file).replace(/\.html$/, '').replace(/(^|\/)index$/, '')

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

  if (!title) errors.push(`${route}: thiếu <title>`)
  if (title && title.length > 65) warnings.push(`${route}: title dài ${title.length} ký tự (nên ≤ 60)`)
  if (title && title.length < 15) warnings.push(`${route}: title ngắn ${title.length} ký tự`)
  if (!description) warnings.push(`${route}: thiếu meta description`)
  if (description && (description.length < 50 || description.length > 165)) {
    warnings.push(`${route}: description dài ${description.length} ký tự (nên 140–160)`)
  }

  if (!noindex) {
    if (!canonical) errors.push(`${route}: thiếu canonical nhưng KHÔNG noindex`)
    if (!ogImage) warnings.push(`${route}: thiếu og:image`)
    if (!ogTitle) warnings.push(`${route}: thiếu og:title`)
    if (h1Count === 0) errors.push(`${route}: không có <h1>`)
    if (h1Count > 1) errors.push(`${route}: có ${h1Count} thẻ <h1>`)
  } else if (canonical) {
    warnings.push(`${route}: vừa noindex vừa có canonical (thường không cần)`)
  }

  if (canonical) {
    if (!/^https?:\/\//i.test(canonical)) errors.push(`${route}: canonical không phải URL tuyệt đối → ${canonical}`)
    if (/^http:\/\//i.test(canonical)) errors.push(`${route}: canonical dùng HTTP → ${canonical}`)
    if (SITE && !canonical.startsWith(SITE)) warnings.push(`${route}: canonical khác site (${canonical})`)
  }

  if (!lang) errors.push(`${route}: <html> thiếu thuộc tính lang`)
  if (imgNoAlt > 0) warnings.push(`${route}: ${imgNoAlt} thẻ <img> thiếu alt`)
  if (!noindex && jsonLd === 0) warnings.push(`${route}: không có JSON-LD`)

  if (title) titles.set(title, [...(titles.get(title) ?? []), route])
  if (description) descs.set(description, [...(descs.get(description) ?? []), route])
}

for (const [t, routes] of titles) {
  if (routes.length > 1) errors.push(`Title trùng ở ${routes.length} trang: "${t}" → ${routes.slice(0, 4).join(', ')}${routes.length > 4 ? '…' : ''}`)
}
for (const [, routes] of descs) {
  if (routes.length > 1) warnings.push(`Description trùng: ${routes.slice(0, 4).join(', ')}${routes.length > 4 ? '…' : ''}`)
}

console.log(`\nĐã kiểm tra ${files.length} trang HTML trong '${ROOT}'\n`)
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
