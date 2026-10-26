# PHP Ecosystem Migrator — a Claude skill

A [Claude skill](https://docs.claude.com) that plans and executes PHP upgrades
as an *ecosystem* problem: the runtime, the deprecated language features in
your code, the framework or CMS on top (Laravel, Symfony, WordPress), and the
Composer packages, plugins and themes that pin everything in place.

Written in the week after **PHP2Shell** (CVE-2026-109618 / CVE-2026-109619,
21 Oct 2026) — two unauthenticated RCEs affecting every PHP from 5.4 to 8.5.11,
with no patch for 8.1 or older. If you are still on an end-of-life PHP, the
migration *is* the security fix. This skill is built to make that migration
small, reversible and testable.

## What it does

```
1. Assess        read-only report: versions, blockers, abandoned packages, deprecation counts
2. Patch first   is the current PHP even receiving fixes? bump the patch before anything else
3. Build ladder  ordered rungs of (PHP version, framework version) — never jump a rung
4. Safety net    tests, or characterization snapshots when there are none; dual-PHP CI
5. Climb         per rung: deprecations → Rector → packages → bump → verify → one PR
6. Report        what changed, what is still deprecated, what forces the next migration
```

Two rules shape everything: **no code changes before the assessment report**,
and **one rung of the ladder = one pull request**.

## Contents

```
skills/php-ecosystem-migrator/
├── SKILL.md                          workflow and rules
├── references/
│   ├── framework-matrix.md           PHP ↔ Laravel / Symfony / WordPress compatibility, EOL dates, per-rung pain
│   ├── php-deprecations.md           what breaks per PHP version 8.0 → 8.5, with fixes and Rector rule names
│   ├── package-replacements.md       abandoned → replacement, for generic / Laravel / Symfony / WordPress packages
│   ├── wordpress.md                  core → plugins/themes → PHP; PHPCompatibilityWP; crawl-diff safety net
│   └── php-security-2026.md          PHP2Shell and the other 2026 advisories, with fixed versions
└── scripts/
    ├── assess.sh                     read-only assessment → Markdown report
    └── rector.template.php           one-rung Rector config, modernisation rules off
```

## Install

**Claude Code — per project** (recommended for a legacy app you are migrating):

```bash
git clone https://github.com/magnaibayarmn/php-ecosystem-migrator /tmp/pem
mkdir -p .claude/skills
cp -r /tmp/pem/skills/php-ecosystem-migrator .claude/skills/
```

Then in Claude Code: `/php-ecosystem-migrator` — or just ask
"can this run on PHP 8.4?" and the skill triggers on its own.

**Claude Code — global:** same, into `~/.claude/skills/`.

**As a plugin / marketplace:**

```
/plugin marketplace add <you>/php-ecosystem-migrator
/plugin install php-ecosystem-migrator
```

**claude.ai:** zip the `skills/php-ecosystem-migrator` folder and upload it
under Settings → Skills.

## Use

Point Claude at a project and ask for a migration plan. The first thing it
produces is the assessment report — it will not touch code until you have
seen it:

```
> We're on Laravel 8 / PHP 7.4 and the host is forcing PHP 8.3 next month. Plan it.
```

Or run the assessment yourself:

```bash
bash .claude/skills/php-ecosystem-migrator/scripts/assess.sh 8.4 . > MIGRATION.md
```

The script is read-only. It needs `php`, and optionally `composer`, `jq`,
`rg`/`grep`, `wp` (WordPress) and `phpcs` with PHPCompatibility installed
globally; anything missing is reported with the command to run by hand.

## Scope

- PHP 7.x / 8.0 / 8.1 → 8.2 / 8.3 / 8.4 / 8.5
- Laravel 6 → 13, Symfony 4.4 → 8.x (LTS to LTS), WordPress 6.x → 7.x,
  Bedrock, plain Composer projects
- Not covered: PHP 5.x → 7.x (the references list the removed functions, but
  the skill assumes you are already on 7.x), Drupal, Magento (PRs welcome)

## Keeping it current

The compatibility matrix and the security notes are dated snapshots
(October 2026). Each reference file says where to verify its rows. If you
update them, please send a PR — a stale EOL date is worse than none.

## Contributing

Issues and PRs welcome. Useful contributions, in order:

1. Corrections to `references/` tables (with a link to the official source)
2. New rows in `package-replacements.md` for blockers you hit in real migrations
3. Framework/CMS additions as separate `references/<name>.md` files
4. Eval cases under `skills/php-ecosystem-migrator/evals/` (see Anthropic's skill-creator format)

CI runs shellcheck, `bash -n`, `php -l` and a frontmatter check.

## License

MIT
