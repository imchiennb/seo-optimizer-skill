# seo-optimizer

> An agent skill for auditing and optimizing technical SEO on **any** Next.js project — App Router, Pages Router, or hybrid; any version from 13 to 16.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Next.js](https://img.shields.io/badge/Next.js-13%20%E2%86%92%2016-black)](https://nextjs.org)
[![Format](https://img.shields.io/badge/format-Agent%20Skill-blue)](#install)
[![validate](https://github.com/imchiennb/seo-optimizer-skill/actions/workflows/validate.yml/badge.svg)](https://github.com/imchiennb/seo-optimizer-skill/actions/workflows/validate.yml)

**Guiding principle: the server's raw HTML is the source of truth.** Every conclusion must be backed by `curl` output, a script result, or a real metric — never by reading code and guessing.

📖 [Bản tiếng Việt](README.vi.md)

---

## Why this exists

Most SEO advice was written for the WordPress era — server-rendered sites with static HTML. Next.js breaks those assumptions in specific, well-documented ways, and generic checklists miss all of them.

**What makes this different:**

- **Evidence-first.** The skill is forbidden from claiming a fix worked without pasting output that proves it. "Verified" means verified.
- **Version-aware.** `[14]` split `viewport` out of `metadata`. `[15]` made `params` a Promise. `[16]` renamed `middleware.ts` → `proxy.ts` and replaced `experimental.ppr` with `cacheComponents`. The skill knows which rules apply to your project.
- **Router-aware.** It detects App Router / Pages Router / hybrid before doing anything, and **does not** push a Pages Router project to migrate. Migration is a strategy decision, not a fix.
- **Executable, not just prose.** Four scripts do the checking; the reference docs explain the reasoning.
- **Corrects popular misinformation.** See [below](#a-correction-worth-stating).

---

## Install

Plain Markdown plus shell/Node scripts — no build step, no dependencies.

```bash
git clone git@github.com:imchiennb/seo-optimizer-skill.git ~/.dsh/skills/seo-optimizer
```

Adjust the target path for your agent host:

| Host | Skill directory |
| --- | --- |
| DSH | `~/.dsh/skills/` |
| Claude Code | `~/.claude/skills/` |
| Other | wherever your agent loads skills from |

Verify the install:

```bash
bash ~/.dsh/skills/seo-optimizer/scripts/self-test.sh
```

Because everything is Markdown, you can also use it with any LLM that can read files — feed it `SKILL.md`, then whichever `references/*.md` files are relevant.

---

## Usage

### With an agent

Ask about SEO on a Next.js project and the skill is selected automatically:

> "Audit the technical SEO of this Next.js app."
> "Our organic traffic dropped 30% last week — diagnose it."
> "Why isn't Google indexing our product pages?"

The agent runs discovery, audits in priority order, and reports findings with evidence.

### Manually

```bash
SKILL=~/.dsh/skills/seo-optimizer

# 1. What kind of Next.js project is this?
bash $SKILL/scripts/detect-project.sh /path/to/project

# 2. Scan the codebase for SEO risk signals
bash $SKILL/scripts/grep-antipatterns.sh /path/to/project/app

# 3. Check the built HTML (run after `npm run build`)
node $SKILL/scripts/check-seo.mjs .next/server/app --site=https://example.com

# 4. Check production's raw HTML — what Googlebot actually receives
bash $SKILL/scripts/audit-url.sh https://example.com / /pricing /contact
```

`check-seo.mjs` exits `1` when it finds a deploy-blocking error, so it drops straight into CI.

Point it at the output directory for your router:

| Project | Directory |
| --- | --- |
| App Router | `.next/server/app` |
| Pages Router | `.next/server/pages` |
| Static export (`output: 'export'`) | `out` |
| **Hybrid** (`app/` + `pages/`) | **both**, in one run |

Hybrid projects need both directories in a single invocation:

```bash
node $SKILL/scripts/check-seo.mjs .next/server/app .next/server/pages
```

Running only one silently misses the other router's routes — and misses duplicate titles *between* the two routers, which is precisely the kind of problem a hybrid project has. When only `.next/server/app` is passed and a sibling `.next/server/pages` exists, the script now says so.

It also **skips static redirect routes** — Next emits a layout shell for `permanentRedirect()` that has no canonical and no `<h1>`, which would otherwise be reported as deploy-blocking errors. Detection is via the `NEXT_REDIRECT` marker in the RSC payload.

Duplicate titles across **hreflang alternates** (the same term in several locales) are reported as a warning rather than a blocker, since that is an intentional locale variant — localising it is still recommended.

It automatically skips framework-generated pages, which always lack metadata and are not yours to fix: `_not-found` and `_global-error` (App Router), `404` and `500` (Pages Router and static export). Pass `--all` to audit those too.

**It refuses to pass a build it never inspected.** If a build produces no public pages at all — every route dynamic, nothing prerendered — the script exits **3** with a loud diagnostic instead of reporting success. This was a real false pass: a production project with 5 routes and 0 prerendered pages was being green-lit. For genuinely all-dynamic apps (dashboards, authenticated tools), pass `--allow-empty`.

| Exit code | Meaning |
| --- | --- |
| `0` | No deploy-blocking errors |
| `1` | Deploy-blocking SEO errors found |
| `2` | Input unreadable (wrong directory, forgot `npm run build`) |
| `3` | Nothing to inspect — no public pages were prerendered |

Useful flags:

```bash
# Compare source routes against prerendered pages — exposes "the whole site is dynamic"
node $SKILL/scripts/check-seo.mjs .next/server/app --src=src/app

# Allow a build with zero public pages (all-dynamic app)
node $SKILL/scripts/check-seo.mjs .next/server/app --allow-empty
```

**Severity model.** Only three things fail the build:

1. A missing `<title>` on an indexable page.
2. A missing, relative, or `http://` canonical on an indexable page.
3. The same title on more than one indexable page.

Everything else — missing description, missing OG tags, no JSON-LD, missing `lang`, heading count, images without `alt`, over-long titles — is reported as a **warning**. Those are real problems worth fixing, but they do not break indexing, and treating them as blocking is how an SEO gate ends up permanently red and ignored.

```yaml
# .github/workflows/seo.yml
- run: npm ci && npm run build
- run: node ${{ vars.SKILL_DIR }}/scripts/check-seo.mjs .next/server/app --site=${{ vars.SITE_URL }}
```

---

## What's inside

### References — 18 documents

| # | Document | Covers |
| --- | --- | --- |
| 00 | [Index & routing](references/00-index.md) | **Read first** — routing table and the five-layer model |
| 01 | [Crawl & index](references/01-crawl-and-index.md) | Googlebot, robots.txt vs meta robots, crawl budget, status codes, soft 404 |
| 02 | [Rendering & caching](references/02-rendering-and-caching.md) | SSG/ISR/SSR/CSR, PPR, Cache Components, server vs client components |
| 03 | [Metadata API](references/03-metadata-api.md) | title templates, canonical, Open Graph, Twitter, viewport, per-page patterns |
| 04 | [File conventions](references/04-file-conventions.md) | `sitemap.ts`, `robots.ts`, `manifest.ts`, `opengraph-image`, RSS, 404 |
| 05 | [Structured data](references/05-structured-data.md) | JSON-LD per page type, `@graph`, breadcrumbs, deprecated types |
| 06 | [URL, canonical, i18n](references/06-url-canonical-i18n.md) | slugs, redirects, trailing slash, hreflang, pagination, faceted nav |
| 07 | [Performance & CWV](references/07-performance-cwv.md) | `next/image`, `next/font`, `next/script`, bundle, LCP/INP/CLS, TTFB |
| 08 | [On-page, content, a11y](references/08-onpage-content-a11y.md) | semantics, headings, internal links, alt text, E-E-A-T |
| 09 | [Measurement & QA](references/09-measurement-qa.md) | GSC, GA4, PSI, Lighthouse CI, log analysis, alerting |
| 10 | [Antipatterns](references/10-antipatterns.md) | 27 Next.js-specific failures: symptom → cause → fix → detection |
| 11 | [Launch checklist](references/11-launch-checklist.md) | pre-launch, post-launch and recurring gates |
| 13 | [Vietnamese & VN market](references/13-vietnamese-and-vn-market.md) | diacritics, NFC/NFD, pixel-based title length, local SEO, market share |
| 14 | [Migration & upgrade](references/14-migration-and-upgrade.md) | Pages → App Router mapping, version upgrades, domain changes |
| 15 | [Multi-site](references/15-multi-site.md) | cross-domain cannibalization, merging sites, shared tooling |
| 16 | [E-commerce](references/16-ecommerce.md) | variants, out-of-stock, facets, pricing schema, product feeds |
| 17 | [Debug traffic drops](references/17-debug-traffic-drop.md) | decision tree by timeline, four distinct kinds of "drop" |
| 18 | [Team process](references/18-team-process.md) | tickets, PR review, CI guardrails, working cadence |

### Templates

| File | Purpose |
| --- | --- |
| [`templates/site-config.md`](templates/site-config.md) | Fill in **per site** — single source of truth for a property |
| [`templates/audit-report.md`](templates/audit-report.md) | Consistent audit report with a measurable baseline |

### Scripts

| File | Purpose |
| --- | --- |
| [`scripts/detect-project.sh`](scripts/detect-project.sh) | Detect router, Next.js version, config flags, route count, SEO infrastructure |
| [`scripts/grep-antipatterns.sh`](scripts/grep-antipatterns.sh) | Scan 20 SEO risk signals in a codebase |
| [`scripts/check-seo.mjs`](scripts/check-seo.mjs) | Validate built HTML; exit 1 on deploy-blocking errors |
| [`scripts/audit-url.sh`](scripts/audit-url.sh) | Inspect production raw HTML, headers, redirect chain |
| [`scripts/self-test.sh`](scripts/self-test.sh) | Validate this repository's own integrity |

---

## The five-layer model

Every fix is ordered by this priority. Optimizing layer 5 while layer 1 is broken is wasted effort.

| Layer | Question | References |
| --- | --- | --- |
| **1** | Can Google index it? | 01 |
| **2** | Can Google read the content? | 02 |
| **3** | Does Google understand what the page is? | 03, 04, 05, 06 |
| **4** | Does the page deserve to rank? | 08 |
| **5** | Is the experience good? | 07 |

---

## What the skill refuses to recommend

meta keywords · `rel=next/prev` · `noindex` on paginated pages · canonical on page 2 pointing to page 1 · `priority` on every image · `force-dynamic` site-wide · `'use client'` on a whole page · piling on schemas to farm rich results · `FAQPage`/`HowTo` for rich-result farming · deleting out-of-stock product URLs · cross-domain canonical without stating the trade-off · claiming a fix without verification.

---

## A correction worth stating

A widely repeated claim says *"Next.js 16 removed the Pages Router."* **This is false.** Pages Router is fully supported in Next.js 16.x — the official docs still maintain a complete `/docs/pages` section.

The practical consequence: migrating Pages → App Router brings **no direct ranking benefit**. It unlocks new framework features, and nothing more. Don't sell it as an SEO fix.

---

## Language

- Top-level docs (this README, `CONTRIBUTING.md`, `SKILL.md`) are in **English**.
- The 18 reference documents are in **Vietnamese**.

[`13-vietnamese-and-vn-market.md`](references/13-vietnamese-and-vn-market.md) is deliberately language-specific and covers material with no English equivalent: `đ` not decomposing under Unicode NFD, NFC/NFD string mismatches silently breaking slugs, and measuring title length in pixels rather than characters.

Translations are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Requirements

| Component | Requirement |
| --- | --- |
| Shell scripts | Bash 4+, `curl` |
| `check-seo.mjs` | Node.js 18+ (no npm dependencies) |
| `detect-project.sh` | Node.js for reading `package.json` |
| Agent host | Any host that loads Markdown skills |

No third-party packages. Nothing is installed into your project.

---

## Verified against

The scripts were validated by building real projects and running them on the actual output — not on hand-written fixtures. Reproduce any row yourself:

| Configuration | Version | Result |
| --- | --- | --- |
| App Router | `next@13.5.6` | ✅ build, `check-seo` exit 0 |
| App Router | `next@14.2.15` | ✅ build, `check-seo` exit 0 |
| App Router | `next@15.1.6` | ✅ build, `check-seo` exit 0 |
| App Router | `next@16.3.7` (Turbopack) | ✅ build, `check-seo` exit 0 |
| Pages Router | `next@13.5.6` | ✅ build, `check-seo` exit 0 |
| Pages Router | `next@15` | ✅ build, `check-seo` exit 0 |
| Hybrid `app/` + `pages/` | `next@15.1.6` | ✅ both output dirs merged in one run |
| Static export | `next@15.1.6` | ✅ `out/` audited |
| Monorepo (`apps/web/app`) | `next@15.1.6` | ✅ project root resolved correctly |
| JavaScript projects (`.js`/`.jsx`) | — | ✅ detected |
| Live production site | — | ✅ `audit-url.sh` on a real property |

The framework-internal page list (`_not-found`, `_global-error`, `404`, `500`) was derived from these real builds, so it holds across versions: Next 13 emits no `_global-error.html`, Next 16 does, and both are handled.

**Not yet covered:** Windows (the scripts are Bash-only) and automated Core Web Vitals measurement — the skill tells you how to measure CWV, it does not measure them for you.

### A gotcha found by this validation

`output: 'export'` plus `app/sitemap.ts` **fails the build** unless you add `export const dynamic = 'force-static'`. The error message does not mention sitemaps. Documented in [`references/04-file-conventions.md`](references/04-file-conventions.md).

---

## Accuracy

Content was cross-checked against the official Next.js documentation (16.x branch) and Google Search Central. SEO material online has a very high rate of stale or incorrect claims, so where a blog post contradicts official docs, the docs win — and this repo says so out loud.

Found something wrong? Open an issue linking the official source. That's the fastest path to a merge.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: every claim needs an official source or reproducible command output, and `scripts/self-test.sh` must pass.

---

## License

[MIT](LICENSE) © 2026 imchiennb

Not affiliated with, endorsed by, or sponsored by Vercel or Google. Next.js is a trademark of Vercel, Inc.
