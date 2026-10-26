---
name: php-ecosystem-migrator
description: Plan and execute PHP upgrades across the whole ecosystem — the PHP runtime (7.x/8.0/8.1 → 8.2/8.3/8.4/8.5), deprecated and removed language features, and the framework or CMS on top of it (Laravel, Symfony, WordPress) together with its Composer dependencies, plugins and themes. Use this skill whenever the user mentions upgrading, migrating or modernizing PHP, moving off an end-of-life PHP version, fixing deprecation warnings, "PHP 8 compatibility", bumping a Laravel/Symfony major, upgrading a WordPress site's PHP, Rector, PHPCompatibility, abandoned Composer packages, or wants to know whether an app is affected by a PHP security advisory (e.g. the October 2026 "PHP2Shell" RCEs) — even if they only ask "can we run this on PHP 8.4?" or "why is this breaking after the hosting provider updated PHP?".
---

# PHP Ecosystem Migrator

Upgrading PHP is rarely about PHP. The interpreter bump is the easy part; the
work is in the layers above it: deprecated language features scattered through
legacy code, a framework that requires a newer PHP than you run and a newer PHP
than your packages allow, abandoned Composer packages, and WordPress plugins
nobody has touched since 2019. This skill treats the migration as an ecosystem
problem and walks it in an order that keeps every step small, reversible and
testable.

Two rules shape everything below. Understand *why* they exist so you can apply
them to situations this document doesn't cover:

1. **No code changes before the assessment report.** Teams that start editing
   on day one discover the real blocker (an abandoned package pinning
   `php: ^7.4`, a plugin that calls `create_function()`) on day four, after the
   diff is already huge. Measuring first is cheaper than un-doing.
2. **One rung of the ladder = one pull request.** Framework upgrade guides are
   written from the previous major only. A PHP minor bump or a framework major
   bump is one rung; never combine two rungs, and never jump rungs. A failing
   rung is then a small, bisectable change instead of a two-week rabbit hole.

## Workflow overview

```
1. Assess      → migration report, no edits
2. Patch first → security floor (does this box even get CVE fixes?)
3. Build the ladder → ordered list of (PHP version, framework version) rungs
4. Safety net  → tests or characterization snapshots, dual-version CI
5. Climb       → per rung: deprecations → automated rewrite → packages → verify
6. Report      → what changed, what is still deprecated, what to do next
```

Read the reference files only when you reach the step that needs them:

| File | Read when |
|---|---|
| `references/framework-matrix.md` | Building the ladder (step 3) — PHP ↔ Laravel/Symfony/WordPress compatibility and EOL dates |
| `references/php-deprecations.md` | Climbing a PHP rung (step 5) — what breaks per PHP version, with fixes |
| `references/package-replacements.md` | A package is abandoned or blocks the PHP constraint |
| `references/wordpress.md` | The project is WordPress (no Composer, plugins/themes instead of packages) |
| `references/php-security-2026.md` | Explaining urgency, or checking whether a version is affected by a recent CVE |

## Step 1 — Assess (no edits)

Run `scripts/assess.sh` from the project root (it is read-only). It gathers
PHP/framework versions, Composer constraints, abandoned packages, the packages
blocking the target PHP version, and a PHPCompatibility sniff count. If the
script cannot run (no Composer, WordPress without Composer, missing tools),
collect the same facts manually — the questions matter more than the script:

- **What runs now?** `php -v`, SAPI (`php-fpm`, `mod_php`, `php-cgi`), the
  `php` constraint in `composer.json`, the framework version
  (`composer show laravel/framework`, `composer show symfony/framework-bundle`,
  `wp core version` / `wp-includes/version.php`).
- **What blocks the target?** `composer why-not php 8.4` is the single most
  informative command in the whole migration: it names every package whose
  constraint excludes the target PHP. Run it for each candidate target.
- **What is abandoned?** `composer outdated --direct` and `composer show`
  flag `[abandoned]` packages. For WordPress, look at plugins/themes whose last
  update is older than two years or that are not tested with the current core.
- **How much deprecated code?** `phpcs --standard=PHPCompatibility
  --runtime-set testVersion 8.4- -p --report=summary app/ src/` (use
  `PHPCompatibilityWP` for WordPress). Count by sniff, not just total.
- **Is there a safety net?** Test suite present? Passing? Coverage of the
  critical paths? No tests changes step 4 significantly.

Produce the report in this exact shape so later rungs can refer to it:

```markdown
# Migration assessment — <project>
## Current state
PHP x.y.z (SAPI) · Framework A.B · composer php constraint · test suite: yes/no
## Target
PHP x.y · Framework A.B — why this target (support window, security)
## Blockers (ordered by effort)
| Package / file | Blocks | Fix | Effort |
## Deprecation inventory
| Sniff / pattern | Count | Auto-fixable by Rector? |
## Abandoned packages / plugins
## Proposed ladder
1. ...
## Risk notes
```

Stop and share the report before touching code. If the user is not present,
state the assumptions you made and proceed with the ladder.

## Step 2 — Patch first

Before any migration work, check whether the *current* PHP is a release that
still receives security fixes, and whether it is below the latest patch of its
branch. As of October 2026, PHP 8.2 and newer receive fixes; 8.1 and older do
not, and the October 2026 PHP2Shell RCEs (CVE-2026-109618/109619) affect every
version from 5.4 up to 8.5.11. See `references/php-security-2026.md`.

If the project is on an EOL PHP, the migration *is* the security fix — say so
plainly in the report, because that framing is what gets the work prioritized.
If it is on a supported branch but behind on patches, bump the patch release
first; that is a separate, trivial change and must not wait for the migration.

## Step 3 — Build the ladder

Open `references/framework-matrix.md`. Choose the target with the support
window in mind: as of late 2026, PHP 8.2 goes EOL on 31 December 2026, so a
migration that lands on 8.2 is already late. Prefer 8.3 as a minimum landing
point and 8.4 where the framework allows it.

Then write out every intermediate rung. The framework decides the order, not
PHP: each framework major has a PHP floor *and* a PHP ceiling, so you move
whichever one is currently blocking the other. A typical Laravel ladder:

```
Laravel 8 / PHP 7.4
  → PHP 8.0             (L8 supports up to 8.1)
  → Laravel 9           (needs ≥ 8.0)
  → PHP 8.1             (L9 ceiling is 8.2)
  → Laravel 10          (needs ≥ 8.1)
  → PHP 8.2
  → Laravel 11          (needs ≥ 8.2)
  → Laravel 12
  → PHP 8.3 → Laravel 13 (needs ≥ 8.3)
  → PHP 8.4
```

For Symfony, travel LTS to LTS (5.4 → 6.4 → 7.4) and bump PHP between them.
For WordPress, the ladder is core version → plugins/themes → PHP, in that order
(see `references/wordpress.md`).

Each rung becomes a task on the task list, in order. Expect to collapse rungs
only when the framework's own upgrade guide says the jump is supported.

## Step 4 — Safety net

Migrations are judged by "nothing changed that shouldn't have", so the test
suite is the deliverable's foundation.

- Tests exist and pass → record the baseline run (time, count) and continue.
- Tests exist but fail → fix or skip the failures *before* the first rung and
  note which were skipped; a migration cannot be validated against a red suite.
- No tests → write **characterization tests** before the first rung. These do
  not assert correctness, only that behaviour is unchanged: HTTP snapshot
  tests of the top routes (Laravel: `spatie/phpunit-snapshot-assertions`;
  Symfony: `WebTestCase` + snapshot), CLI command output snapshots, and for
  WordPress a crawl of key pages diffed against the pre-migration HTML.
  Ten snapshot tests of the money-making paths beat zero unit tests.

Add a dual-version CI matrix (current PHP and next-rung PHP) and keep both
green until the rung is merged. This catches "works on my machine on 8.3".

## Step 5 — Climb one rung

For each rung, in this order:

### 5a. Fix deprecations *before* the bump
Deprecation notices are the next major's breaking changes announced early.
Fixing them on the current version, where everything still works, is far
cheaper than fixing fatals after the bump.

- **Symfony**: install `symfony/phpunit-bridge`, set
  `SYMFONY_DEPRECATIONS_HELPER=max[self]=0` and drive the count to zero.
  Symfony's deprecation layer is the best in the ecosystem — use it.
- **Laravel**: Laravel does not count deprecations for you. Work through the
  upgrade guide for the *next* major as a checklist; the "high impact" section
  is usually small and specific.
- **PHP itself**: read the section for the target version in
  `references/php-deprecations.md`. Dynamic properties (8.2) and implicitly
  nullable parameters (8.4) are the two that hit legacy code hardest.

### 5b. Automated rewrite with Rector
Rector does 70–80 % of the mechanical work. Copy `scripts/rector.template.php`
to the project as `rector.php`, set the PHP level and framework set for this
rung only, and run `vendor/bin/rector process --dry-run`. Review the diff
grouped by rule (the dry-run output is grouped already) and apply it in
separate commits per rule family — dynamic properties, nullable types, string
interpolation — so a reviewer can skim each one. Keep type-coverage rules off
during the migration; adding types is a separate project and bloats the diff.

Laravel projects with budget: Laravel Shift produces a reviewed PR per major
and is usually the fastest path. Treat its output like Rector's — review, don't
trust.

### 5c. Packages, plugins, themes
`composer why-not php <rung>` again. For each blocker: bump if a compatible
release exists; otherwise consult `references/package-replacements.md`. When
no replacement exists, fork the package, patch the constraint, and point
`composer.json` at the fork via `repositories` (and `replace` if the name must
stay) — this keeps the rung moving without a rewrite. Record every fork as
technical debt in the final report.

WordPress: update plugins/themes to versions declaring compatibility with the
target PHP *before* changing PHP; see `references/wordpress.md` for the audit.

### 5d. Bump and verify
Change the PHP version (or framework constraint), `composer update` only the
packages that need it (`composer update laravel/framework --with-all-dependencies`,
not a blanket `composer update`, which hides which change broke what), run the
full suite plus the snapshots, and smoke-test manually against a staging
environment running the real SAPI. Open the PR for this rung. Only then start
the next one.

## Step 6 — Report

End with a migration report (same file as the assessment, updated), covering:
final versions; forks and workarounds that must be revisited; deprecations
still emitted on the new version (grep the logs after a day in staging);
packages that are now at their last compatible release; and the next support
deadline that will force the next migration.

## Things that go wrong often

- `composer update` with no arguments mid-rung — updates fifty packages at
  once and you can no longer tell which one broke the build.
- Trusting `composer.json`'s `php` constraint — many projects say `^7.4` while
  actually running 8.1. Trust `php -v` on the real server.
- Forgetting the SAPI — `mod_php` and `php-fpm` have different `php.ini`
  files; a migration tested on CLI only is not tested.
- WordPress `wp-config.php` or a theme's `functions.php` with inline legacy
  PHP that no scanner sees as a "plugin". Scan the whole web root.
- PHP 8.0's string/number comparison change (`0 == "foo"` is now `false`)
  breaks logic silently with no deprecation notice. Grep for loose
  comparisons against numeric literals in legacy code.
- Patch-release regressions: the 8.4.27/8.5.12 security releases introduced
  a SimpleXML double-free; always land on the newest patch of a branch, not
  the first one that fixes the CVE.
