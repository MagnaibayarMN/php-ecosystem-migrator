# PHP security advisories, 2026

Use this to answer "is our version affected?" and to make the case for a
migration whose real driver is security. Everything here is a snapshot as of
25 October 2026; check php.net's security advisories and the GitHub
`php/php-src` security tab for anything newer before quoting it.

## PHP2Shell — CVE-2026-109618 and CVE-2026-109619 (21 Oct 2026)

Two critical, unauthenticated remote code execution vulnerabilities in the
PHP core interpreter. Both rated CVSS v4.0 9.2. Details leaked before the fix
was released, a public one-click exploit exists for -109618, and exploitation
in the wild was observed by watchTowr and AWS before disclosure.

| | |
|---|---|
| **CVE-2026-109618** | Out-of-memory handling can interrupt PHP while internal request data is only partially initialised; the cleanup routine then processes invalid data → RCE |
| **CVE-2026-109619** | Request-owned internal state survives after its memory is freed (`longjmp()` fatal-error path leaves global pointers to freed regions); a worker can reuse stale state from a previous request → RCE / memory disclosure |
| **Affected** | Every PHP from **5.4 through 8.5.11** — default configurations, PHP-FPM, mod_php and php-cgi alike |
| **Fixed in** | 8.5.12 · 8.4.27 · 8.3.36 · 8.2.35 |
| **Not fixed** | 8.1 and older (EOL). Remi Collet maintains unofficial backports at `github.com/remicollet/php-src-security`; distributions (RHEL, Debian LTS, Ubuntu ESM) ship their own backports for their supported PHP packages |
| **Mitigations** | PHP: "There are no complete mitigations, updating is the only safe choice." Partial for -109619: `session.upload_progress.enabled = 0`; on 8.5 also `fatal_error_backtraces = 0`. Third-party extension `php_uploadprogress_guard` (HOSTED-POWER) hardens 5.4–8.5 without rebuilding PHP — a bridge for EOL boxes, not a fix |
| **Exposure** | Palo Alto Xpanse: >22.6 M potentially vulnerable exposed instances; ~884 k internet-facing hosts on EOL versions with no official patch |

### Patch-release regressions to know about

- **SimpleXML double free** in the garbage collector, *introduced by* 8.4.27 and
  8.5.12 (php-src#24488). Fixed in the following patch release. Land on the
  newest patch of the branch, not on the first one that fixes the CVE.
- **unserialize() use-after-free** during `var_destroy()` (php-src#24481),
  present in every current release including 8.5.12 and 8.4.27 at the time of
  writing. Nested `unserialize()`/`session_decode()` calls from destructors.
  Track the fix; relevant if the app unserializes untrusted data (it should
  not, regardless).

### How to use this in a migration report

If the project is on PHP ≤ 8.1, write it as: *"The current runtime has two
publicly exploited unauthenticated RCEs with no vendor patch. The migration to
8.x is the remediation."* That sentence gets the work funded; "we should
modernise" does not.

If the project is on 8.2–8.5 but below the fixed patch, the patch bump is a
separate, immediate change (Step 2 of the skill) and must not be bundled into
the migration PRs.

## July 2026 security release (8.5.9 / 8.4.24 / 8.3.33 / 8.2.33)

| CVE | Component | Issue |
|---|---|---|
| CVE-2026-9672 | GD | libgd upgrade (bundled image library vulnerabilities) |
| CVE-2026-17543 | PGSQL | SQL injection via `E'...'` backslash breakout in escaping |
| CVE-2026-7260 | Phar | Crash via recursive symlinks |
| CVE-2026-17544 | BCMath (8.4/8.5 only) | Out-of-bounds write in `bccomp()` |

The PGSQL one matters for any app using `pg_escape_*` manually instead of
parameterised queries — a migration is a good moment to grep for it.

## May 2026 security release

| CVE | Severity | Component | Issue |
|---|---|---|---|
| CVE-2026-29078 | Moderate (RCE class) | DOM (8.4/8.5) | OOB read/write traversing DOM contents |
| CVE-2026-29079 | Critical | DOM (8.4/8.5) | Type confusion in HTML fragment parsing |
| CVE-2025-14179 | Critical | PDO Firebird | Invalid NULL-byte handling in prepared queries |
| CVE-2026-6735 | Medium | PHP-FPM | XSS in the FPM status page |
| CVE-2026-7261 | Critical (9.8) | core | Use-after-free |
| CVE-2026-6722 | Critical (9.8) | — | see NVD |
| CVE-2026-6104 | Critical (9.1) | — | see NVD |
| CVE-2026-7258/7259/7262/7263/7568 | High/Medium | various | see NVD |

Also from that period: CVE-2026-12184 (TLS cleanup crash, DoS; 8.3.0–8.3.31,
8.4.0–8.4.20, 8.5.0–8.5.5) and CVE-2026-14355 (OpenSSL buffer allocation,
7.2–8.5).

## Reading the pattern

Three 2026 observations shape migration advice:

1. **EOL means EOL.** PHP2Shell affected 5.4+, and 8.1 got nothing. Any app on
   8.1 or lower is now provably exposed, not theoretically.
2. **8.2 goes EOL on 31 Dec 2026.** A migration landing on 8.2 buys weeks.
   Land on 8.3 minimum, 8.4 preferred.
3. **Newer branches get new-code bugs too** (DOM, BCMath issues were 8.4/8.5
   only). "Newest" is not automatically "safest" for the first weeks after a
   release; "newest patch of a supported branch" is the rule.

## Sources

- PHP advisory: https://www.php.net/archive/2026.php#2026-10-21-5
- GHSA-w8hw-w9fx-j79w (109618), GHSA-6wmf-4rv5-p3rp (109619)
- watchTowr FAQ: https://watchtowr.com/intelligence/php-cve-2026-109618-faq/
- Datadog Security Labs analysis: https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/
- Unit 42 threat brief: https://unit42.paloaltonetworks.com/cve-2026-109618-cve-2026-109619/
- oss-security, July 2026 release: https://www.openwall.com/lists/oss-security/2026/07/30/29
- Zend security center: https://www.zend.com/security-center
