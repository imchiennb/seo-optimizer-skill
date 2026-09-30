# Contributing

Thanks for considering a contribution. This repo has one unusual rule that shapes everything else: **no claim without evidence.**

---

## What we want

| Welcome | Why |
| --- | --- |
| Corrections backed by official documentation | The whole value of this repo is accuracy |
| New Next.js-specific failure modes, with a reproduction | Antipatterns with real symptoms are the core asset |
| Translations of the reference documents | Only the top-level docs are English right now |
| Script improvements and new checks | The scripts are what make the skill verifiable |
| Bug reports with the exact command and output | Fastest path to a fix |

## What we don't want

- SEO folklore or "everyone knows that" claims with no source
- Advice that violates Google's policies — fake ratings, link schemes, hidden text, doorway pages
- Generic SEO advice that applies equally to WordPress (out of scope)
- Anything that requires an npm dependency

---

## The evidence rule

Every factual claim must satisfy **one** of these:

1. A link to official Next.js docs or Google Search Central, **or**
2. Command output that reproduces the behaviour

If a claim is contested between a blog post and official docs, the docs win and the reference should say so explicitly.

---

## Hard constraints

1. **`SKILL.md` must stay tiny.** Agent hosts reject oversized skill bodies — the observed limit is roughly 1.2 KB of body text. A previous, much better-written version was rejected for being ~4 KB. Routing tables and detail belong in `references/00-index.md`.
2. **Language split.** `README.md`, `README.vi.md`, `CONTRIBUTING.md`, `CHANGELOG.md` and `SKILL.md` are in English. The 18 reference documents are in Vietnamese.
3. **No npm dependencies.** `scripts/*.mjs` use Node built-ins only.
4. **Scripts take paths as arguments.** They must work from any working directory — never assume the caller's cwd is the project root.
5. **Never renumber existing references.** Links across documents depend on the numbers. Append with the next free number.

---

## Adding or changing a reference

1. Create `references/NN-kebab-case-name.md`
2. **Register it** in the routing table in `references/00-index.md`
3. Run `bash scripts/self-test.sh` — it fails if a reference file isn't registered
4. Use the existing structure: tables over prose, a checklist at the end, and an antipattern section where relevant

Step 2 is not optional. `self-test.sh` enforces it, because an unregistered reference is a document no agent will ever load.

---

## Adding a script

- `scripts/*.sh` — Bash 4+, start with `set -uo pipefail`, only `curl` beyond coreutils
- `scripts/*.mjs` — Node 18+, ESM, built-ins only
- Must exit **non-zero** on failure so it can gate CI
- Must not modify anything — audit scripts report, they don't fix
- Add a functional test to `scripts/self-test.sh`

---

## Reporting a bug

Include:

- Next.js version and router (App Router / Pages Router / hybrid) — or just paste `scripts/detect-project.sh` output
- The exact command you ran
- The actual output
- What you expected instead

## Proposing a correction

Open an issue titled `docs: <what is wrong>` and link the official source. Disagreements are resolved by documentation, not by seniority or popularity.

---

## Commit messages

Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`.

## Pull request checklist

- [ ] `bash scripts/self-test.sh` passes
- [ ] Any changed claim links to an official source or shows command output
- [ ] New reference is registered in `references/00-index.md`
- [ ] `SKILL.md` is still under the size limit
- [ ] No new dependencies

---

## Code of conduct

Be accurate, be kind, assume good faith. Being wrong about a technical detail is normal and fixable; being dismissive is not.
