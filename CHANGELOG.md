# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-09-30

Verified against **real** Next.js builds for the first time — `next@16.3.7` App Router
(Turbopack) and `next@15` Pages Router. That validation found four defects that the
original hand-written fixtures could not, because those fixtures encoded the author's
assumptions rather than the framework's actual output.

### Fixed

- **`check-seo.mjs` failed healthy projects.** Next.js emits framework-internal pages
  (`_not-found`, `_global-error` on App Router; `404`, `500` on Pages Router) that always
  lack metadata. They were audited as real pages, producing deploy-blocking errors, so the
  CI gate was permanently red on any working project. Framework-internal pages are now
  skipped by default and reported; `--all` audits them anyway.
- **`detect-project.sh` only recognised `.ts`/`.tsx`.** A JavaScript project reported
  `sitemap`, `robots`, `not-found`, `manifest`, `opengraph-image`, `apple-icon` and
  `twitter-image` as missing, and under-counted `layout` and `route` files. All four
  extensions (`.ts`, `.tsx`, `.js`, `.jsx`) are now checked everywhere.
- **`grep-antipatterns.sh` resolved paths against the working directory**, not the project.
  Run with an absolute path from another directory, it reported `next.config` as missing and
  checked the wrong `public/`. The project root is now derived from the app directory, with
  `PROJECT_ROOT` as an override.
- **`README.md` carried a permanently-green badge.** `img.shields.io/...self--test-passing`
  is a static image that reads "passing" even when CI is red. Replaced with the real
  GitHub Actions workflow badge.

### Changed

- **`check-seo.mjs` severity model is now explicit.** Only a missing `<title>`, a
  missing/relative/`http://` canonical, and duplicate titles across indexable pages fail the
  build. Missing description, OG tags, JSON-LD, `lang`, heading count and image `alt` are
  warnings. Documented in `README.md` and in the script header.
- Title/description duplication only considers indexable pages (`noindex` excluded).
- `README.md` documents the output directory per router and the `--all` flag.

### Added

- Six regression tests in `scripts/self-test.sh` built from **captured real build output**,
  covering: App Router framework pages, Pages Router `404`/`500`, `.js`/`.jsx` detection,
  and cwd-independent project-root resolution. Verified to fail against the previous scripts
  and pass against the fixed ones.
- A guard test asserting a real page missing `<title>` still fails, so the new suppression
  cannot silently over-suppress.
- `references/00-index.md` notes that reference number `12` is intentionally unused, and
  `CONTRIBUTING.md` states that `templates/` is in Vietnamese.
- Self-test count: 36 → 45 checks.

## [1.0.0] - 2026-09-30

Initial public release.

### Added

**Entry point**
- `SKILL.md` — minimal entry point (deliberately kept small, since agent hosts reject oversized skill bodies): discovery step, audit → fix → verify workflow, non-negotiable rules, and the list of recommendations the skill refuses to make.

**References — 18 documents**
- `00-index.md` — routing table and the five-layer model
- `01-crawl-and-index.md` — Googlebot, robots.txt vs meta robots, crawl budget, status codes, soft 404
- `02-rendering-and-caching.md` — SSG/ISR/SSR/CSR, PPR, Cache Components, server vs client components
- `03-metadata-api.md` — title templates, canonical, Open Graph, Twitter, viewport, per-page patterns
- `04-file-conventions.md` — `sitemap.ts`, `robots.ts`, `manifest.ts`, `opengraph-image`, RSS, 404
- `05-structured-data.md` — JSON-LD per page type, `@graph`, breadcrumbs, deprecated schema types
- `06-url-canonical-i18n.md` — slugs, redirects, trailing slash, hreflang, pagination, faceted navigation
- `07-performance-cwv.md` — `next/image`, `next/font`, `next/script`, bundle size, LCP/INP/CLS, TTFB
- `08-onpage-content-a11y.md` — semantics, headings, internal links, alt text, E-E-A-T, accessibility
- `09-measurement-qa.md` — Search Console, GA4, PSI, Lighthouse CI, log analysis, alerting
- `10-antipatterns.md` — 27 Next.js-specific failure modes with symptom, cause, fix and detection
- `11-launch-checklist.md` — pre-launch, post-launch and recurring gates
- `13-vietnamese-and-vn-market.md` — Vietnamese diacritics, NFC/NFD, pixel-based title length, local SEO, VN search market share
- `14-migration-and-upgrade.md` — Pages → App Router mapping, Next.js version upgrades, domain changes
- `15-multi-site.md` — cross-domain cannibalization, merging and splitting sites, shared tooling
- `16-ecommerce.md` — product variants, out-of-stock handling, facets, pricing schema, product feeds
- `17-debug-traffic-drop.md` — diagnosis decision tree by timeline, four distinct kinds of traffic drop
- `18-team-process.md` — tickets, PR review, CI guardrails, working cadence

**Templates**
- `templates/site-config.md` — per-site source of truth
- `templates/audit-report.md` — consistent audit report with a measurable baseline

**Scripts** (no npm dependencies)
- `scripts/detect-project.sh` — detect router, Next.js version, config flags, route count, SEO infrastructure
- `scripts/grep-antipatterns.sh` — scan 20 SEO risk signals in a codebase
- `scripts/check-seo.mjs` — validate built HTML, exit 1 on deploy-blocking errors
- `scripts/audit-url.sh` — inspect production raw HTML, headers and redirect chain
- `scripts/self-test.sh` — validate this repository's own integrity

**Project**
- MIT license
- English top-level docs with a Vietnamese README
- GitHub Actions workflow running `self-test.sh` on push and pull request
- Issue and pull request templates

### Notes

- Content cross-checked against the official Next.js documentation (16.x branch) and Google Search Central.
- Documents a specific correction: **Pages Router is fully supported in Next.js 16.x.** Claims that Next.js 16 removed it are false, and Pages → App Router migration carries no direct ranking benefit.
