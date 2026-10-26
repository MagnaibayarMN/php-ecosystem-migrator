# WordPress migrations

WordPress differs from Laravel/Symfony in three ways that change the workflow:

1. **No dependency graph.** Unless the site is on Bedrock/Composer, there is no
   `composer why-not`. Every plugin and theme is an independent blob with its
   own (often undeclared) PHP ceiling. The audit is per-plugin, by hand or by
   scanner.
2. **Core is not the problem.** WordPress core has been PHP-8-clean since 6.x
   and 7.x recommends PHP 8.3. Virtually every failure after a PHP bump comes
   from a plugin, a theme's `functions.php`, a `mu-plugins/` drop-in, or
   custom code in `wp-content/`.
3. **The upgrade is usually a hosting-panel toggle.** That makes it dangerously
   easy to do without preparation — and equally easy to roll back. Use that:
   test on staging, flip, crawl, flip back if needed.

## Ladder order: core → plugins/themes → PHP

Always in this order. Updating core first means plugins are tested against the
core they will actually run on; updating plugins second means they are at the
versions that declare the target PHP; changing PHP last means the only variable
that changed at the moment of the flip is PHP itself.

```
WP 6.2 / PHP 7.4 / 40 plugins
  → WP 6.8 (or 7.x)             core update, plugins untouched
  → update every plugin/theme    to versions declaring PHP 8.x support
  → replace/remove the ones that can't
  → PHP 8.1 (if host still offers it) → 8.3 → 8.4
```

Skip PHP minors only when every plugin's "Requires PHP"/"Tested up to" clears
the target; otherwise step one minor at a time so the failing plugin is obvious.

## Step 1 — Inventory

```bash
wp core version
wp plugin list --fields=name,status,version,update,auto_update --format=table
wp theme list  --fields=name,status,version,update --format=table
wp plugin list --status=inactive --format=csv        # candidates for deletion
ls wp-content/mu-plugins/                            # invisible to the plugin screen
```

For each *active* plugin and the active theme (plus its parent), record:

| Plugin | Version | Last updated (wp.org) | Tested up to (WP) | Requires PHP | From wp.org? | Still needed? |

Sources for the columns:
- `readme.txt` in the plugin directory: `Requires PHP:` and `Tested up to:`.
- The wp.org plugin page (last-updated date, active installs). A plugin not
  updated in >2 years or not tested with the last two majors is a liability
  regardless of what it declares.
- Premium/custom plugins have no wp.org page — treat them as unknown and scan.

Delete inactive plugins and themes *now*. They still execute nothing but are
still scanned, still attack surface, and still confuse the audit.

## Step 2 — Scan

Static scan (CLI, repeatable, put it in CI):

```bash
composer global require --dev phpcompatibility/phpcompatibility-wp dealerdirect/phpcodesniffer-composer-installer
phpcs -p --standard=PHPCompatibilityWP --runtime-set testVersion 8.3- \
      --extensions=php --ignore='*/vendor/*,*/node_modules/*' \
      --report=summary wp-content/
```

`PHPCompatibilityWP` knows about WordPress's own polyfills so it does not
report false positives for functions core backfills. Run it against the whole
`wp-content/` (plugins, themes, mu-plugins, uploads with stray PHP) and against
`wp-config.php` — custom constants and legacy snippets hide there.

In-admin alternative when there is no shell: the **PHP Compatibility Checker**
plugin (WP Engine) runs the same sniffs from wp-admin. Slower, same output.

Interpret by sniff, not by total. Three categories matter:

| Category | Example | Blocking? |
|---|---|---|
| Removed function / syntax | `create_function()`, `each()`, `${}` interpolation, curly-brace string offsets | Yes — fatal on the target |
| Behaviour change | `0 == "abc"`, `strlen(null)`, implicit float→int | Yes, silently — needs review |
| Deprecation only | dynamic properties (8.2), implicitly nullable params (8.4) | No — log noise now, fatal in a later major |

A plugin with only category-3 hits can ship on the rung with a note. A plugin
with category-1 hits cannot: update, replace, patch, or drop it.

## Step 3 — Decide per plugin

For each plugin with blocking hits, in order of preference:

1. **Update** — a newer version from the same author clears the scan.
2. **Replace** — a maintained plugin covers the same function (see the
   replacement table below for the common ones).
3. **Patch & own** — fork into `wp-content/plugins/<name>/` with the fix,
   disable auto-updates for it, record it as technical debt. Acceptable for
   small custom plugins; a trap for large ones that will need every future
   security release re-applied.
4. **Drop** — surprisingly often the right answer. Ask what the plugin does
   today, not what it did when installed.

Common replacements:

| Old / abandoned | Replace with |
|---|---|
| Classic Editor shims, TinyMCE Advanced | Advanced Editor Tools (same plugin, renamed) or block editor |
| WP Super Cache / W3 Total Cache (unmaintained forks) | host-level cache, or LiteSpeed Cache / WP Rocket |
| Yoast ≤ 14, All in One SEO ≤ 3 | current Yoast / Rank Math |
| Contact Form 7 add-ons from 2018 | current CF7 or WPForms/Fluent Forms |
| Jetpack monolith used for one feature | the specific standalone Jetpack plugin |
| Any "PHP snippet" plugin (Insert PHP, PHP Code Widget, Code Snippets with `eval`) | move the code into `mu-plugins/` as real PHP and scan it |
| WooCommerce extensions not updated for HPOS | current versions; HPOS compatibility is a hard requirement from WC 8+ |

## Step 4 — Safety net

WordPress sites rarely have tests, so characterization is the norm:

1. **Crawl before**: `wget --mirror --no-parent --level=2 https://staging.example` or
   a sitemap-driven script; store the HTML.
2. **Crawl after** the flip; `diff -r` the two trees, ignoring nonces, dates and
   cache-busters. Anything else that changed needs an explanation.
3. **Log watch**: enable `WP_DEBUG_LOG` on staging, flip PHP, click through
   admin (dashboard, post edit, media upload, WooCommerce order if present,
   each plugin's settings page), then read `wp-content/debug.log`. Deprecated
   notices here are the "fatal in the next major" list.
4. **Cron & background jobs**: `wp cron event run --all` on the new PHP —
   scheduled tasks are code paths a crawl never hits.

## Step 5 — Flip PHP

On managed hosting (Kinsta, WP Engine, SiteGround, Cloudways): the panel
toggle, on **staging first**. On self-hosted: change the FPM pool or
`mod_php` module, remembering that CLI (`wp` commands) and FPM use different
`php.ini` files and can be on different PHP versions — verify with
`wp eval 'echo PHP_VERSION;'` *through the web* (a tiny mu-plugin that prints
it on a hidden page) as well as on CLI.

After the flip: crawl diff, admin click-through, `debug.log` review, Site
Health (Tools → Site Health → Info → Server). Then production, with the panel
rollback one click away for 24 hours.

## WordPress-specific traps

- `wp-config.php` with `define('WP_DEBUG', true)` left on from a previous
  migration prints deprecations into the HTML and breaks JSON endpoints.
- Themes bought once, never updated, with a bundled copy of a library
  (TGM Plugin Activation, old Redux, old Kirki) — these are the most common
  `create_function()` and `each()` sources.
- `mu-plugins/` runs before everything and does not appear on the Plugins
  screen; migration audits that only look at `wp plugin list` miss it.
- Uploaded `.php` files in `wp-content/uploads/` are either a legacy hack or a
  web shell. Either way, scan the directory and ask.
- Multisite: plugins can be network-activated and invisible per-site; audit
  from the network admin (`wp plugin list --network`).
- PHP 8.2+ dynamic-property deprecations flood `debug.log` on old plugins
  (`$this->foo = ...` on undeclared properties). Not fatal yet, but a plugin
  producing thousands per request is a performance problem and an author who
  has stopped maintaining it.
- WordPress 7.x raised the DB floor to MySQL 8.0 / MariaDB 10.6 — a hosting
  plan old enough to be on PHP 7.4 is often also on MySQL 5.7. Check both.

## Bedrock / Composer-managed WordPress

Treat as a normal Composer project: `composer why-not php 8.4`,
`wpackagist-plugin/*` constraints, Rector with `->withPhpSets()`. The
plugin audit above still applies because wpackagist mirrors wp.org plugins
with whatever PHP support they actually have, not what their constraint says.
