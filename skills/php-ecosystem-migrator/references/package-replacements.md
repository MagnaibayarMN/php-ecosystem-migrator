# Abandoned and blocking packages — replacements

Consult when `composer why-not php <target>` names a package, or when
`composer show` marks one `[abandoned]`. Packagist marks abandonment with a
suggested replacement; this table collects the ones that recur in real
migrations plus the gotchas Packagist does not mention.

Verify the current state on Packagist before acting — a package abandoned in
2023 may have been revived or forked under a new vendor by now.

## Decision order for any blocker

1. **Bump** — a newer release already supports the target PHP. `composer
   require vendor/pkg:^N --with-all-dependencies`. Check *its* changelog for
   breaking changes; a dependency's major bump is a mini-rung of its own.
2. **Replace** — table below.
3. **Fork and patch the constraint** — when the code itself works on the target
   and only `composer.json` says it doesn't (very common for small libraries):

   ```json
   "repositories": [
     { "type": "vcs", "url": "https://github.com/yourorg/pkg" }
   ],
   "require": { "vendor/pkg": "dev-php84-compat as 2.3.0" }
   ```

   The `as` alias keeps dependents that require `^2.3` satisfied. Record the
   fork in the final report; it is debt with a due date (the day the real
   package gets a security fix you must re-apply).
4. **Inline** — a 200-line helper library can be copied into `src/Support/`
   with attribution. Often cleaner than a fork.
5. **Drop** — ask what it does today.

## Generic / cross-framework

| Abandoned | Replacement | Notes |
|---|---|---|
| `swiftmailer/swiftmailer` | `symfony/mailer` | API differs completely; Laravel 9 and Symfony 5+ did this for you if you use the framework's mail layer |
| `fzaninotto/faker` | `fakerphp/faker` | Drop-in; same namespace `Faker\` |
| `phpunit/php-token-stream`, `phpunit/phpunit` < 9 | `phpunit/phpunit` ^10/^11 | PHPUnit 10 removed `@` annotations in favour of attributes and changed the XML config — run `--migrate-configuration` |
| `mockery/mockery` < 1.5 | `mockery/mockery` ^1.6 | Just bump |
| `doctrine/annotations` | PHP 8 attributes | Doctrine ORM 3 and Symfony 7 no longer read annotations at all |
| `doctrine/cache` | `symfony/cache` or PSR-6/16 adapters | Doctrine ORM 3 dropped it |
| `doctrine/dbal` ^2 | `doctrine/dbal` ^3/^4 | `fetchAll()` → `fetchAllAssociative()` etc.; Rector `DoctrineSetList` covers most |
| `guzzlehttp/guzzle` ^6 | `guzzlehttp/guzzle` ^7 | PSR-18; `GuzzleHttp\Psr7` moved to `guzzlehttp/psr7` ^2 |
| `league/flysystem` ^1 | `league/flysystem` ^3 | Method renames (`put`→`write`, `has`→`fileExists`); adapters are separate packages now |
| `nesbot/carbon` ^1 | `nesbot/carbon` ^2/^3 | Carbon 3 requires PHP 8.1 and changed diff-in-X return types to float |
| `ramsey/uuid` ^3 | `ramsey/uuid` ^4 | Mostly compatible; `Uuid::uuid4()->toString()` unchanged |
| `monolog/monolog` ^1 | `monolog/monolog` ^3 | Handler signatures typed; `LogRecord` object instead of array in custom handlers/processors |
| `predis/predis` ^1 | `predis/predis` ^2 or ext-redis | Mostly compatible |
| `moontoast/math` | `brick/math` | Different API |
| `paragonie/random_compat` | nothing — `random_bytes()` is core since 7.0 | Just remove |
| `symfony/polyfill-php7x`, `-php80`, `-php81` | nothing once your floor ≥ that version | `composer remove`; they are harmless but dead weight |
| `ircmaxell/password-compat` | nothing — core since 5.5 | Remove |
| `zendframework/*`, `zend-*` | `laminas/*` | 1:1 rename; `composer require laminas/laminas-dependency-plugin` rewrites them automatically |
| `pear/*` ancient libs (Mail, Net_SMTP, HTTP_Request) | Symfony components / Guzzle | Rewrite |
| `phpoffice/phpexcel` | `phpoffice/phpspreadsheet` | Namespace change; mechanical |
| `dompdf/dompdf` < 1 | `dompdf/dompdf` ^2/^3 | Bump |
| `tecnickcom/tcpdf` | still maintained; bump | Often pinned very old |
| `twig/twig` ^1/^2 | `twig/twig` ^3 | Twig 3 dropped `spaceless`, `filter` tag, `for..if`; `twig/twig` 3.x needs PHP ≥ 8.0 (3.9+ ≥ 8.1) |
| `league/oauth2-client` providers from 2017 | current `league/oauth2-*` | Bump |
| `facebook/graph-sdk` | `facebook/php-business-sdk` or raw Guzzle | Abandoned, no drop-in |
| `google/apiclient` ^1 | `google/apiclient` ^2 | Namespaced classes |
| `aws/aws-sdk-php` ^2 | `aws/aws-sdk-php` ^3 | Client factories changed |
| `stripe/stripe-php` ancient | current | Bump; API version pinning is separate |
| `sentry/sentry` ^1/^2 | `sentry/sentry` ^4 + framework SDK | Init API changed |

## Laravel ecosystem

| Abandoned / blocking | Replacement | Notes |
|---|---|---|
| `laravelcollective/html` | `spatie/laravel-html`, or Blade components | Abandoned 2024; forks exist (`laravelcollective/html` → `laravel-collective/html` community fork) if a quick bridge is needed |
| `fruitcake/laravel-cors` | core — `HandleCors` middleware since Laravel 9 | Remove package, keep `config/cors.php` |
| `fideloper/proxy` | core — `TrustProxies` since Laravel 9 | Remove |
| `laravel/ui` | starter kits (Breeze → the new L12/13 kits) or keep `laravel/ui` (still maintained for Bootstrap scaffolding) | Only replace if you want to |
| `laravel/breeze`, `laravel/jetstream` | new starter kits (L12+) | Both frozen; existing installs keep working |
| `laravel/dusk` < 7 | bump | — |
| `barryvdh/laravel-cors` | core | Remove |
| `barryvdh/laravel-debugbar`, `-ide-helper` | bump | Fast to follow Laravel majors |
| `tymon/jwt-auth` | `php-open-source-saver/jwt-auth` | Maintained fork, same namespace alias available |
| `maatwebsite/excel` ^2 | `maatwebsite/excel` ^3 | Complete rewrite in 3.0 |
| `intervention/image` ^2 | `intervention/image` ^3 | API changed; `Image::make()` → `ImageManager` |
| `spatie/laravel-permission` old | bump | Follow upgrade guides per major |
| `beyondcode/laravel-websockets` | `laravel/reverb` | Abandoned; Reverb is first-party |
| `pusher/pusher-php-server` ^4 | ^7 | Bump |
| `doctrine/dbal` in Laravel for `change()` migrations | not needed since Laravel 11 | Remove; L11 has native column modification |
| `nunomaduro/larastan` | `larastan/larastan` | Renamed; `composer require larastan/larastan` |
| `facade/ignition` | `spatie/laravel-ignition` | L9+ |
| `league/flysystem-aws-s3-v3` ^1 | ^3 | With Flysystem 3 |
| `predis/predis` for Laravel ≥ 9 | fine, or `ext-redis` | — |
| Lumen | Laravel proper | Lumen is in maintenance; migrate to Laravel with `--api` style |

## Symfony ecosystem

| Abandoned / blocking | Replacement | Notes |
|---|---|---|
| `sensio/framework-extra-bundle` | core attributes: `#[Route]`, `#[MapEntity]`, `#[IsGranted]`, `#[Cache]`; templates via `#[Template]` in `symfony/twig-bundle` 6.2+ | Abandoned with Symfony 6.x |
| `symfony/swiftmailer-bundle` | `symfony/mailer` | — |
| `friendsofsymfony/user-bundle` | Symfony Security + `make:user`; or `symfonycasts/verify-email-bundle`, `symfonycasts/reset-password-bundle` | No drop-in; FOSUser is the classic 5.4-blocker |
| `friendsofsymfony/rest-bundle` | API Platform, or plain controllers + Serializer | Maintained but lagging |
| `jms/serializer-bundle` | `symfony/serializer` | Mostly; annotations → attributes |
| `knplabs/knp-paginator-bundle` | bump — follows Symfony | — |
| `stof/doctrine-extensions-bundle` | bump — follows Symfony | — |
| `symfony/templating` | Twig | Removed in 6.0 |
| `symfony/security-guard` | authenticators (`symfony/security-http`) | Guard removed in 6.0; the biggest 5.4 → 6.4 rewrite in most apps |
| `symfony/web-server-bundle` | Symfony CLI (`symfony serve`) | Removed 5.0 |
| `symfony/debug` | `symfony/error-handler` | Removed 5.0 |
| `symfony/http-kernel` sub-requests via `Kernel::terminate` style hacks | Messenger | — |
| `doctrine/doctrine-cache-bundle` | `symfony/cache` | Removed |
| `doctrine/doctrine-fixtures-bundle` ^2 | ^3 | Bump |
| `lexik/jwt-authentication-bundle` old | bump | Fine |
| `nelmio/cors-bundle`, `nelmio/api-doc-bundle` old | bump | Fine |
| `liip/imagine-bundle` old | bump | — |
| `sonata-project/*` ^3 | ^4 | Major rewrite; often the heaviest blocker in Symfony legacy apps |
| `easycorp/easyadmin-bundle` ^2 | ^4 | Full rewrite between 2 and 3 |
| `symfony/monolog-bundle` ^3 | still fine; needs Monolog 3 for Symfony 7 | — |
| `php-http/*` adapters | `symfony/http-client` + PSR-18 | — |

## WordPress (Composer-managed only)

| Abandoned / blocking | Replacement |
|---|---|
| `johnpbloch/wordpress` ^5 | `roots/wordpress` |
| `wpackagist-plugin/<x>` pinned low | bump — the plugin audit in `wordpress.md` decides |
| `composer/installers` ^1 | ^2 |

## When the blocker is a *private* package

Check whether it is actually used (`composer why vendor/pkg`, grep for its
namespace). Internal libraries from a previous team are the most common
"blocker nobody owns". Fork into the monorepo or inline; do not wait for an
owner who has left.
