#!/usr/bin/env node
/**
 * check-seo.mjs — kiểm tra HTML đã build của một dự án Next.js.
 *
 * Dùng:
 *   node check-seo.mjs [thư_mục...] [--site=URL] [--src=DIR] [--all] [--allow-empty]
 *
 * Thư mục HTML theo loại dự án:
 *   App Router     → .next/server/app
 *   Pages Router   → .next/server/pages
 *   Static export  → out
 *   HYBRID (app/ + pages/) → truyền CẢ HAI:
 *       .next/server/app .next/server/pages
 *
 * Truyền nhiều thư mục sẽ gộp vào một báo cáo, nhờ đó phát hiện được title
 * trùng GIỮA hai router — chạy riêng từng thư mục sẽ bỏ sót.
 *
 * --src=src/app   So số route trong source với số trang prerender được.
 *                 Đây là cách phát hiện "toàn bộ site là dynamic".
 * --all           Kiểm tra cả trang nội bộ của framework.
 * --allow-empty   Cho phép build không có trang công khai nào (mặc định: lỗi).
 *
 * Exit code:
 *   0 = không có lỗi chặn deploy
 *   1 = có lỗi chặn deploy
 *   2 = không đọc được input
 *   3 = KHÔNG CÓ TRANG CÔNG KHAI NÀO ĐỂ KIỂM TRA (gate không xác minh được gì)
 *
 * Mức độ:
 *   ❌ CHẶN  — phá vỡ việc index hoặc tính đúng đắn của SEO
 *   ⚠️  CẢNH BÁO — vấn đề thật, nên sửa, nhưng không chặn deploy
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, relative, basename, dirname } from 'node:path'

const args = process.argv.slice(2)
const flag = (name) => args.find((a) => a.startsWith(`--${name}=`))?.split('=').slice(1).join('=')
const SITE = flag('site')
const SRC = flag('src')
const INCLUDE_INTERNAL = args.includes('--all')
const ALLOW_EMPTY = args.includes('--allow-empty')
const DIRS = args.filter((a) => !a.startsWith('--'))
if (DIRS.length === 0) DIRS.push('.next/server/app')

// Trang do framework sinh ra, luôn thiếu metadata. Không phải lỗi của bạn.
const FRAMEWORK_INTERNAL = new Set([
  '_not-found', '_global-error', '_error', '404', '500',
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
const notes = []

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
const redirects = []
let totalHtml = 0

/**
 * Next sinh trang redirect tĩnh cho permanentRedirect(): HTML chỉ là shell của
 * layout (không canonical, không <h1>, dùng title mặc định), nên nếu đem ra
 * audit sẽ tạo ra loạt lỗi "chặn deploy" giả.
 * Dấu hiệu tin cậy: payload RSC có NEXT_REDIRECT.
 * Phát hiện thật: /vi và /en của moai.profyai.vn (308 → /{lang}/movies) bị báo
 * thiếu canonical + trùng title, dù chúng chỉ là redirect.
 */
function isRedirectRoute(file) {
  const rsc = file.replace(/\.html$/, '.rsc')
  if (!existsSync(rsc)) return false
  try {
    return readFileSync(rsc, 'utf8').includes('NEXT_REDIRECT')
  } catch {
    return false
  }
}

for (const dir of DIRS) {
  const html = walk(dir).filter((f) => f.endsWith('.html'))
  totalHtml += html.length
  for (const file of html) {
    const route = '/' + relative(dir, file).replace(/\.html$/, '').replace(/(^|\/)index$/, '')
    if (!INCLUDE_INTERNAL && isInternal(route)) { skipped.add(route); continue }
    if (!INCLUDE_INTERNAL && isRedirectRoute(file)) { redirects.push(route); continue }
    entries.push({ file, route, dir })
  }
}

/* ── Phát hiện build không có gì để audit ────────────────────────────────
 * Đây là false-pass nguy hiểm nhất: trước đây script in "Đã kiểm tra 0 trang"
 * rồi vẫn báo "✅ Không có lỗi" và exit 0. Với CI gate, điều đó nghĩa là một
 * site hoàn toàn dynamic — không cache được, mọi trang render lại mỗi request
 * — vẫn được duyệt xanh.
 * Phát hiện thật: moai.profyai.vn build ra 0 trang public, script báo PASS.
 * --------------------------------------------------------------------- */
if (entries.length === 0) {
  console.error(`\n❌ KHÔNG CÓ TRANG CÔNG KHAI NÀO ĐỂ KIỂM TRA`)
  console.error(`   Thư mục: ${DIRS.join(', ')}`)
  console.error(`   Tìm thấy ${totalHtml} file HTML, nhưng tất cả đều là trang nội bộ`)
  console.error(`   của framework (${[...skipped].join(', ') || 'không có'}) hoặc trang redirect`)
  console.error(`   (${redirects.join(', ') || 'không có'}) nên bị bỏ qua.`)

  if (SRC && existsSync(SRC)) {
    const srcRoutes = walk(SRC).filter((f) => /^page\.(tsx|ts|jsx|js)$/.test(basename(f)))
    if (srcRoutes.length) {
      console.error(`\n   ${srcRoutes.length} route tồn tại trong ${SRC} nhưng 0 trang được prerender.`)
    }
  }

  console.error(`\n   Nghĩa là: mọi route đang render động tại request time.`)
  console.error(`   Hệ quả thường gặp:`)
  console.error(`     • cache-control: private, no-store  → CDN không cache được gì`)
  console.error(`     • TTFB cao, mỗi lần Googlebot crawl là một lần render đầy đủ`)
  console.error(`\n   Nguyên nhân phổ biến nhất — kiểm tra theo thứ tự:`)
  console.error(`     1. cookies() / headers() / draftMode() trong layout.tsx hoặc page.tsx`)
  console.error(`        (một lời gọi trong layout gốc kéo TOÀN BỘ cây thành dynamic)`)
  console.error(`     2. export const dynamic = 'force-dynamic'`)
  console.error(`     3. searchParams được đọc ở trang không cần thiết`)
  console.error(`\n   Chạy \`bash <SKILL_DIR>/scripts/grep-antipatterns.sh <app-dir>\` để tìm.`)
  console.error(`\n   Nếu dự án CỐ Ý toàn dynamic (dashboard, app sau đăng nhập),`)
  console.error(`   thêm --allow-empty để bỏ qua kiểm tra này.\n`)
  if (!ALLOW_EMPTY) process.exit(3)
  notes.push('Build không có trang công khai nào (đã cho phép qua --allow-empty)')
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
  const ogImage = pick(html, /<meta\s+property="og:image"\s+content="([^"]*)"/i)
  const ogWidth = pick(html, /<meta\s+property="og:image:width"\s+content="([^"]*)"/i)
  const ogHeight = pick(html, /<meta\s+property="og:image:height"\s+content="([^"]*)"/i)
  const ogTitle = /<meta\s+property="og:title"/i.test(html)
  const noindex = /<meta\s+name="robots"[^>]*content="[^"]*noindex/i.test(html)
  const h1Count = (html.match(/<h1[\s>]/gi) ?? []).length
  const jsonLd = (html.match(/application\/ld\+json/gi) ?? []).length
  const imgNoAlt = (html.match(/<img(?![^>]*\balt=)[^>]*>/gi) ?? []).length
  const lang = pick(html, /<html[^>]*\blang="([^"]*)"/i)
  const viewport = /<meta\s+name="viewport"/i.test(html)
  const hrefLang = (html.match(/<link[^>]*hrefLang=["']([^"']*)["'][^>]*>/gi) ?? []).map((t) => (t.match(/href=["']([^"']*)["']/i) ?? [])[1]).filter(Boolean)

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
  if (!viewport) warnings.push(`${label}: thiếu <meta name="viewport"> (mobile-first indexing cần)`)
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

  // og:image khai kích thước — kiểm tra tính hợp lý.
  // Phát hiện thật: một helper metadata (normalizeImage) mặc định 1200×630 cho
  // MỌI ảnh, nên trang phim khai 1200×630 cho thumbnail YouTube 480×360 →
  // khai man kích thước, scraper xã hội cắt ảnh sai.
  if (ogImage && ogWidth && ogHeight) {
    const w = Number(ogWidth), h = Number(ogHeight)
    if (!Number.isFinite(w) || !Number.isFinite(h)) {
      warnings.push(`${label}: og:image:width/height không phải số (${ogWidth}×${ogHeight})`)
    } else {
      if (w < 1200 || h < 630) {
        warnings.push(`${label}: og:image khai ${w}×${h}, nhỏ hơn khuyến nghị 1200×630`)
      }
      const yt = ogImage.match(/\/(hq|mq|sd|maxres)default\./)
      if (yt && yt[1] !== 'maxres') {
        const REAL = { hq: '480×360', mq: '320×180', sd: '640×480' }
        warnings.push(
          `${label}: og:image là thumbnail YouTube ${yt[1]}default.jpg (${REAL[yt[1]]}) — ` +
          `dùng maxresdefault (1280×720) hoặc ảnh tự sinh`,
        )
        if (w >= 1200) {
          warnings.push(
            `${label}: og:image:width/height khai ${w}×${h} nhưng ảnh thật chỉ ${REAL[yt[1]]} ` +
            `— kích thước khai man, scraper sẽ cắt ảnh sai`,
          )
        }
      }
    }
  }

  // Chỉ trang index được mới tính vào trùng lặp title/description
  if (!noindex) {
    if (title) titles.set(title, [...(titles.get(title) ?? []), { label, hrefLang, canonical }])
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
for (const [t, group] of titles) {
  if (group.length <= 1) continue
  const names = group.map((g) => g.label)
  const list = `${names.slice(0, 4).join(', ')}${names.length > 4 ? '…' : ''}`
  // Nếu mọi trang trong nhóm đều là alternate hreflang của nhau thì đây là biến
  // thể locale, không phải trùng lặp ngoài ý muốn → cảnh báo, không chặn.
  const allLinked =
    group.every((g) => g.hrefLang.length > 0) &&
    group.every((g) => group.every((o) => o === g || g.hrefLang.some((h) => h === o.canonical)))
  if (allLinked) {
    warnings.push(`Title giống nhau giữa các locale (biến thể hreflang): "${t}" → ${list} — nên bản địa hoá`)
  } else {
    errors.push(`Title trùng ở ${group.length} trang: "${t}" → ${list}`)
  }
}
for (const [, routes] of descs) {
  if (routes.length > 1) {
    warnings.push(`Description trùng: ${routes.slice(0, 4).join(', ')}${routes.length > 4 ? '…' : ''}`)
  }
}

/* ── Gợi ý hybrid CHỈ khi thư mục pages thực sự có route của Pages Router ──
 * Next LUÔN sinh .next/server/pages/404.html và 500.html kể cả với dự án
 * App Router thuần, nên kiểm tra `existsSync` đơn thuần bắn cảnh báo sai trên
 * gần như MỌI dự án → người dùng sẽ học cách bỏ qua nó.
 * Phát hiện thật: moai.profyai.vn là App Router thuần (không có pages/ trong
 * source) nhưng vẫn bị gợi ý "dự án hybrid?".
 * --------------------------------------------------------------------- */
for (const dir of DIRS) {
  if (basename(dir) !== 'app') continue
  const sibling = join(dirname(dir), 'pages')
  if (!existsSync(sibling)) continue
  if (DIRS.some((d) => basename(d) === 'pages')) continue
  let realPagesRoutes = 0
  try {
    realPagesRoutes = walk(sibling)
      .filter((f) => f.endsWith('.html'))
      .map((f) => '/' + relative(sibling, f).replace(/\.html$/, '').replace(/(^|\/)index$/, ''))
      .filter((r) => !isInternal(r)).length
  } catch { /* ignore */ }
  if (realPagesRoutes > 0) {
    notes.push(
      `'${sibling}' có ${realPagesRoutes} route Pages Router chưa được kiểm tra — dự án hybrid? ` +
      `Chạy lại với: ${DIRS.join(' ')} ${sibling}`,
    )
  }
}

// ── Báo cáo ────────────────────────────────────────────────────────────
console.log(`\nĐã kiểm tra ${entries.length} trang HTML`)
console.log(`Thư mục: ${DIRS.join(', ')}`)
if (redirects.length) {
  console.log(`Bỏ qua ${redirects.length} trang redirect (308/307 — không phải trang nội dung): ${redirects.join(', ')}`)
}
const skippedList = [...skipped]
if (skippedList.length) {
  console.log(`Bỏ qua ${skippedList.length} trang nội bộ của framework: ${skippedList.join(', ')}`)
  console.log(`(dùng --all để kiểm tra cả chúng)`)
}
if (notes.length) {
  console.log()
  notes.forEach((n) => console.log(`⚠️  ${n}`))
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
