# Framework ↔ PHP compatibility matrix

Snapshot as of late October 2026. Dates move; before building a ladder, verify
the current rows against the official pages linked at the bottom — a search
for "<framework> support policy" is enough. Treat anything older than six
months in this file as a hypothesis.

## PHP runtime support

| PHP | Active support until | Security until | Status (Oct 2026) |
|---|---|---|---|
| 8.5 | Dec 2027 | Dec 2029 | Current |
| 8.4 | Dec 2026 | Dec 2028 | Active |
| 8.3 | Dec 2025 | Dec 2027 | Security only |
| 8.2 | Dec 2024 | **31 Dec 2026** | Security only — EOL in weeks |
| 8.1 and older | — | — | EOL, no fixes (incl. PHP2Shell) |

Landing rule: do not plan a migration that ends on a security-only branch
whose EOL is less than a year away. In late 2026 that means land on 8.3 at
minimum, 8.4 by preference.

## Laravel

Policy: new major each Q1, 18 months bug fixes, 24 months security fixes.
Each major has a PHP floor *and* ceiling — the ceiling is what forces you to
upgrade Laravel before PHP, the floor the reverse.

| Laravel | PHP | Released | Bug fixes until | Security until | Status (Oct 2026) |
|---|---|---|---|---|---|
| 13 | 8.3 – 8.5 | Mar 2026 | Q3 2027 | Mar 2028 | Current |
| 12 | 8.2 – 8.5 | Feb 2025 | Aug 2026 | Feb 2027 | Security only |
| 11 | 8.2 – 8.4 | Mar 2024 | Sep 2025 | Mar 2026 | **EOL** |
| 10 | 8.1 – 8.3 | Feb 2023 | Aug 2024 | Feb 2025 | EOL |
| 9 | 8.0 – 8.2 | Feb 2022 | Aug 2023 | Feb 2024 | EOL |
| 8 | 7.3 – 8.1 | Sep 2020 | Jul 2022 | Jan 2023 | EOL |
| 7 | 7.2 – 8.0 | Mar 2020 | — | — | EOL |
| 6 (LTS) | 7.2 – 8.0 | Sep 2019 | — | — | EOL |

Upgrade guides live at `https://laravel.com/docs/<major>.x/upgrade` and are
written from the previous major only. The guide's "High Impact" section is the
mandatory checklist for the rung; "Medium" and "Low" are review items.

Typical ladder from a 2020-era app:

```
L8/7.4 → PHP 8.0 → L9 → PHP 8.1 → L10 → PHP 8.2 → L11 → L12 → PHP 8.3 → L13 → PHP 8.4
```

Known rung-specific pain:
- **8 → 9**: Flysystem 1 → 3 (storage drivers), Swift Mailer → Symfony Mailer,
  `$dates` → `$casts`, PHP 8.0 string comparison semantics.
- **9 → 10**: native return types added across the framework — every class
  that extends a framework class and overrides a method needs matching
  return types. Rector's `LARAVEL_100` set handles most.
- **10 → 11**: slim skeleton (no `app/Http/Kernel.php`, middleware moves to
  `bootstrap/app.php`); Laravel Shift or manual skeleton diff. Optional —
  the old structure still works, so defer this if the rung is already large.
- **11 → 12**: mostly dependency bumps; usually the cheapest rung.
- **12 → 13**: PHP 8.3 floor; check the guide for the current list.

## Symfony

Policy: minor every six months (May/November), major every two years, the
`x.4` minor is always the LTS (3 years bug fixes, 4 years security).

| Symfony | PHP | Released | Bug fixes until | Security until | Status (Oct 2026) |
|---|---|---|---|---|---|
| 8.1 | ≥ 8.4 | May 2026 | Jan 2027 | Jan 2027 | Current |
| 8.0 | ≥ 8.4 | Nov 2025 | Jul 2026 | Jul 2026 | EOL |
| 7.4 (LTS) | ≥ 8.2 | Nov 2025 | Nov 2028 | Nov 2029 | **Recommended landing** |
| 7.0 – 7.3 | ≥ 8.2 | 2023–2025 | — | — | EOL |
| 6.4 (LTS) | ≥ 8.1 | Nov 2023 | Nov 2026 | Nov 2027 | Bug fixes end in weeks |
| 5.4 (LTS) | ≥ 7.2.5 | Nov 2021 | Nov 2024 | Feb 2029* | Security only |
| 4.4 (LTS) | ≥ 7.1.3 | Nov 2019 | Nov 2022 | Nov 2023 | EOL |

*5.4 security support was extended to 2029 for Symfony Corp. customers; treat
it as EOL for planning purposes.

Travel LTS → LTS. Symfony's deprecation layer makes this reliable: a 6.4 app
with zero deprecations (`SYMFONY_DEPRECATIONS_HELPER=max[self]=0`) upgrades to
7.0 almost mechanically, and 7.4 to 8.0 the same way.

Typical ladder:

```
SF 4.4/7.3 → PHP 7.4 → SF 5.4 → PHP 8.1 → SF 6.4 → PHP 8.2 → SF 7.4 → PHP 8.4 → SF 8.x
```

Known rung-specific pain:
- **4.4 → 5.4**: annotations to attributes is *optional* here but mandatory
  later; do it on 6.4 when PHP ≥ 8.1 is guaranteed. `sensio/framework-extra-bundle`
  features move into core (`#[Route]`, `#[ParamConverter]` → `#[MapEntity]`).
- **5.4 → 6.4**: return types on everything you extend; Rector's
  `SymfonySetList::SYMFONY_64` plus the `symfony/phpunit-bridge` count.
- **6.4 → 7.4**: doctrine/annotations removed in favour of attributes; Twig 3;
  many bundles drop PHP < 8.2 here.
- **7.4 → 8.x**: PHP 8.4 floor; Symfony 8.0 removed everything deprecated in 7.x.

## WordPress

WordPress has no Composer dependency graph (unless managed via Bedrock/Composer
— then treat it like a Symfony-style project). Compatibility is decided by
core, then by every plugin and theme independently. See `wordpress.md` for the
audit procedure.

| WordPress | Minimum PHP | Recommended PHP | DB minimum | Notes |
|---|---|---|---|---|
| 7.x (7.0 May 2026, 7.1 later 2026) | 7.4 | 8.3 (8.4 is the practical production target) | MySQL 8.0 / MariaDB 10.6 | Dropped PHP 7.2/7.3 |
| 6.7 – 6.8 | 7.2.24 | 8.3 | MySQL 5.5.5 / MariaDB 10.1 | 8.3 fully supported from 6.8 |
| 6.3 – 6.6 | 7.0 | 8.1+ | — | PHP 8.2 compat improving |
| ≤ 6.2 | 5.6 | — | — | Treat as unmaintained |

The minimum (7.4) is the floor the core refuses to run below; it is itself EOL
and must not be a target. Plan WordPress migrations to PHP 8.3 or 8.4, and
budget the time for plugins, not for core — core is PHP-8-clean, the plugin
ecosystem is where `create_function()` still lives.

## Verify before use

- PHP: https://www.php.net/supported-versions.php
- Laravel: https://laravel.com/docs/master/releases (Support Policy table)
- Symfony: https://symfony.com/releases and https://symfony.com/releases.json
- WordPress: https://wordpress.org/about/requirements/ and
  https://make.wordpress.org/core/handbook/references/php-compatibility-and-wordpress-versions/
- endoflife.date has machine-readable JSON for all four.
