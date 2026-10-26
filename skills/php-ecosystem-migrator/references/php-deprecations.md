# PHP deprecations and removals by version

What breaks when moving *to* each version, ordered by how often it bites
legacy code. "Fatal" means the code stops working on that version; "Deprecated"
means it still runs but emits `E_DEPRECATED` and will be fatal in a later
major. Fix deprecations on the version *before* the bump, where everything
still works.

Rector rule names are given where one exists (`->withPhpSets(phpXY: true)`
includes them). "Manual" means Rector cannot do it safely and a human must.

## Contents

- [To PHP 8.0](#to-php-80) — the big semantic break
- [To PHP 8.1](#to-php-81) — null to internal functions, Serializable
- [To PHP 8.2](#to-php-82) — dynamic properties, `${}` interpolation
- [To PHP 8.3](#to-php-83) — quiet; mostly stricter typing
- [To PHP 8.4](#to-php-84) — implicitly nullable parameters
- [To PHP 8.5](#to-php-85) — check current notes
- [Removed in 7.x that still lingers](#removed-in-7x-that-still-lingers)
- [Grep list](#grep-list)

## To PHP 8.0

The only PHP 8 bump with *silent* behaviour changes. Everything else announces
itself with a deprecation first; 8.0 does not.

| Change | Severity | Fix | Rector |
|---|---|---|---|
| **String ↔ number comparison**: `0 == "foo"` is now `false`; `"abc" == 0` false; `"1" == "01"` still true | Silent | Grep `== 0`, `== ''`, `!= 0` against values that may be strings; use `===` or cast | Manual |
| Internal functions throw `TypeError`/`ValueError` instead of returning `null`/`false` on bad args (`strlen([])`, `array_combine` with mismatched lengths) | Fatal | Fix the call sites; wrap only when the input is truly untrusted | Manual |
| `match` / `str_contains` etc. are new — not breaking, but a user-defined `str_contains()` polyfill now redeclares a built-in | Fatal | Remove polyfills; `function_exists()` guards are fine | Manual |
| Arithmetic/bitwise on arrays, resources, objects throws | Fatal | Fix | Manual |
| `create_function()` removed | Fatal | Closure | `CreateFunctionToAnonymousFunctionRector` (7.2 set) |
| `each()` removed | Fatal | `foreach` / `key()`+`current()`+`next()` | `WhileEachToForeachRector` |
| `__autoload()` removed | Fatal | `spl_autoload_register()` | Manual |
| `(real)`, `(unset)` casts removed; `is_real()` | Fatal | `(float)`, `null` | Set includes |
| `{}` string offset (`$str{0}`) removed | Fatal | `$str[0]` | `CurlyToSquareBracketArrayStringRector` |
| Named arguments: calling with unknown names to internal/framework functions fails | Fatal | Only an issue if you already used named args via reflection | Manual |
| `@` no longer silences fatal errors | Behaviour | Remove `@`, handle properly | Manual |
| Default error_reporting is `E_ALL`; `display_startup_errors` on | Noise | Set explicitly in `php.ini` | — |
| Inheritance: method signatures are checked for *all* methods now (previously private/static had exceptions) | Fatal | Match parent signature | Manual |
| `mb_*`, `libxml_disable_entity_loader()` deprecated | Deprecated | Remove the libxml call (entity loading is off by default from 8.0) | Manual |
| Sorting is stable | Behaviour | Only matters if code relied on unstable order | — |

## To PHP 8.1

| Change | Severity | Fix | Rector |
|---|---|---|---|
| **`null` to non-nullable internal parameter** (`strlen(null)`, `trim(null)`, `htmlspecialchars(null)`, `str_replace(null,…)`) | Deprecated (fatal in 9) | `?? ''`, or fix the source that produces null. Hits form handling everywhere | Manual (Rector can add `(string)` casts with `NullToStrictStringFuncCallArgRector`, review each) |
| `Serializable` without `__serialize()/__unserialize()` | Deprecated | Add the magic methods | `Php81` set partial |
| Implicit float → int losing precision (`$arr[1.5]`, `intdiv(1.5, 1)`) | Deprecated | Explicit `(int)` | Manual |
| Passing by reference where a value is expected (`end(explode(...))`) | Notice → stricter | Assign first | Manual |
| `mysqli` default error mode is now exceptions | Behaviour | Code that checked return values now gets exceptions; add try/catch or `mysqli_report(MYSQLI_REPORT_OFF)` as a *temporary* bridge | Manual |
| `date_sunrise()/date_sunset()`, `strftime()`, `gmstrftime()`, `mhash*()`, `FILTER_SANITIZE_STRING`, `filter_var(..., FILTER_SANITIZE_STRING)` | Deprecated | `date_sun_info()`, `IntlDateFormatter`/`date()`, `hash()`, `htmlspecialchars()` | Partial |
| Static call to non-static method, `$GLOBALS` restrictions | Fatal | Fix | Manual |
| Enums, readonly, `new` in initializers, first-class callables introduced | — | Opt-in modernisation; keep out of the migration PR | `Php81` set (disable during migration) |

## To PHP 8.2

| Change | Severity | Fix | Rector |
|---|---|---|---|
| **Dynamic properties** (`$obj->undeclared = 1` on a class without `__set` or `#[AllowDynamicProperties]`) | Deprecated (fatal in 9) | Declare the property; `stdClass` and `__get/__set` classes are exempt. In legacy code this is the #1 count | `CompleteDynamicPropertiesRector` — adds declarations; review visibility/types |
| **`${var}` and `${expr}` string interpolation** | Deprecated | `{$var}` | `Php82` set includes |
| `utf8_encode()`, `utf8_decode()` | Deprecated | `mb_convert_encoding($s, 'UTF-8', 'ISO-8859-1')` | `Utf8DecodeEncodeToMbConvertEncodingRector` |
| Partially-supported callables (`"self::method"`, `[new Foo, "parent::bar"]`) | Deprecated | Real callables / first-class callable syntax | Partial |
| `strtolower()` & co. are now locale-insensitive | Behaviour | Only matters for Turkish-ı-style locale tricks | — |
| `SplFileObject::fgetss()`, `mysqli_driver::$driver_version`, `iterator_count()` of empty generator | Minor | — | — |
| `ksort`/`krsort` numeric-string ordering fixed | Behaviour | Stable in 8.2.1+; check sort-dependent output | — |
| `readonly` classes, DNF types, `true` type introduced | — | Opt-in | — |

## To PHP 8.3

Smallest break in the series. Typical legacy codebases need no changes.

| Change | Severity | Fix |
|---|---|---|
| `unserialize()` emits `E_WARNING` instead of `E_NOTICE` on malformed data | Noise → warning | Code that caught notices via handler may now see warnings |
| Static property access via `static::` on traits changes semantics | Edge | Rare |
| `get_class()`/`get_parent_class()` without arguments deprecated | Deprecated | `static::class` / `self::class` / `parent::class` |
| `highlight_file`/`highlight_string` output markup changed | Behaviour | Only if you parse it |
| Typed class constants, `#[\Override]`, `json_validate()` introduced | — | Opt-in; `#[\Override]` is useful *after* migration to catch signature drift |

## To PHP 8.4

| Change | Severity | Fix | Rector |
|---|---|---|---|
| **Implicitly nullable parameters** `function f(Foo $x = null)` | Deprecated (fatal in 9) | `?Foo $x = null` or `Foo\|null $x = null`. Massive count in pre-7.1 code; trivial fix | `ExplicitNullableParamTypeRector` — safe to apply wholesale |
| `E_STRICT` constant deprecated | Deprecated | Remove from `error_reporting()` masks | Manual |
| `session_set_save_handler()` with 7-8 arguments; `SplFixedArray::__wakeup`; `xml_set_object()` and non-callable xml handlers | Deprecated | Use the 2-argument object form; closures for xml | Manual |
| `DOMDocument`/`DOMEntity` property deprecations, `mysqli_ping`, `mysqli_refresh`, `stream_bucket_make_writeable` edge cases | Deprecated | Per function | Manual |
| `round()` with invalid mode throws | Fatal | Fix mode | — |
| `strcspn`/`strspn` with negative length behaviour aligned | Behaviour | Rare | — |
| `exit()` is now a function — `exit` as a constant-like string no longer special | Edge | Rare | — |
| New `Dom\HTMLDocument`, property hooks, asymmetric visibility, `#[\Deprecated]`, `array_find()` | — | Opt-in | `Php84` set (disable during migration) |

## To PHP 8.5

Released November 2025. Verify against the official migration guide
(`https://www.php.net/manual/en/migration85.php`) — this file was written when
8.5 was less than a year old and the ecosystem's experience of it is thin.
Known items at time of writing:

| Change | Severity | Fix |
|---|---|---|
| Non-canonical cast names (`(integer)`, `(boolean)`, `(double)`, `(binary)`) | Deprecated | `(int)`, `(bool)`, `(float)`, `(string)` |
| `__sleep()`/`__wakeup()` | Deprecated | `__serialize()`/`__unserialize()` |
| Returning non-string from `__debugInfo`, chained `static` property access edge cases | Deprecated | Per case |
| `fatal_error_backtraces` ini introduced — relevant to CVE-2026-109619 mitigation (`=0`) | Config | See `php-security-2026.md` |
| Pipe operator `\|>`, `#[\NoDiscard]`, `clone` with properties, URI extension introduced | — | Opt-in |

## Removed in 7.x that still lingers

Code that skipped 7.x upgrades (jumped from 5.6 straight to 8) hits these at
once. They are all fatal on 8.0:

- `mysql_*` functions (removed 7.0) → `mysqli_*` or PDO. Rector cannot do this
  mechanically because of connection handling; it is a manual rewrite but a
  pattern-driven one.
- `ereg*()`, `split()`, `spliti()` (removed 7.0) → `preg_*` with delimiters.
- `mcrypt_*` (removed 7.2) → `openssl_*` or `sodium_*`. Watch for data
  encrypted with mcrypt that must still be decrypted — keep a decryption-only
  shim via `pecl/mcrypt` or re-encrypt everything in a one-off job.
- `__autoload`, `each`, `create_function`, `assert()` with string argument,
  `$php_errormsg`, `track_errors`, `(unset)` cast (removed 7.2–8.0).
- Constructors named after the class (PHP 4 style) — deprecated 7.0, removed
  8.0; old WordPress plugins and PEAR-era libraries are full of them.
- `get_magic_quotes_gpc()`, `set_magic_quotes_runtime()` (removed 8.0).
- `money_format()` (removed 8.0) → `NumberFormatter`.
- `hebrevc()`, `convert_cyr_string()`, `restore_include_path()`,
  `ezmlm_hash()`, `fgetss()` (removed 8.0).
- `array_key_exists()` on objects (removed 8.0) → `property_exists()`/`isset()`.

## Grep list

Quick scan before the sniffers run, to size the job in a minute:

```bash
rg -n --type php -e 'create_function\(' -e '\beach\(' -e 'mysql_(connect|query|fetch)' \
   -e '\bereg(i)?\(' -e '\bsplit\(' -e 'mcrypt_' -e 'utf8_(en|de)code\(' \
   -e '\$\{[a-zA-Z_]' -e 'money_format\(' -e '__autoload\(' \
   -e '\bassert\(\s*["'\'']' -e 'FILTER_SANITIZE_STRING' -e 'strftime\(' \
   -e '\)\s*=\s*null\s*[,)]' .    # implicitly nullable params (noisy, review)
```

Count per pattern, not just the total — one pattern with 400 hits and a Rector
rule is an hour; one pattern with 12 hits and no rule is a day.
