<?php

/**
 * rector.php — migration template.
 *
 * Copy to the project root as rector.php. Edit ONLY the three marked blocks
 * for the rung you are on, then:
 *
 *   composer require --dev rector/rector            # once
 *   vendor/bin/rector process --dry-run             # review, grouped by rule
 *   vendor/bin/rector process --only="Rector\\Php82\\Rector\\Class_\\..."   # apply one rule family
 *
 * Principles baked in:
 *  - One rung at a time: only the PHP level and framework version for THIS rung.
 *    Enabling php84 while the server runs 8.1 produces syntax the server rejects.
 *  - Migration ≠ modernisation: type-coverage, code-quality and dead-code sets
 *    are OFF. They are good, but they triple the diff and hide the real changes.
 *    Turn them on in a separate PR after the migration lands.
 *  - Apply per rule family (--only) and commit each separately so a reviewer
 *    can skim "dynamic properties" in one commit and "nullable params" in another.
 */

declare(strict_types=1);

use Rector\Config\RectorConfig;
use Rector\Php74\Rector\Closure\ClosureToArrowFunctionRector;
use Rector\Php81\Rector\Array_\FirstClassCallableRector;
use Rector\Php81\Rector\ClassConst\FinalizePublicClassConstantRector;
use Rector\Php81\Rector\Property\ReadOnlyPropertyRector;
use Rector\Php83\Rector\ClassMethod\AddOverrideAttributeToOverriddenMethodsRector;
// Framework sets — uncomment the one you use (requires the matching extension package):
//   composer require --dev driftingly/rector-laravel      → RectorLaravel\Set\LaravelSetList
//   (Symfony sets ship with rector/rector)                 → Rector\Symfony\Set\SymfonySetList
// use RectorLaravel\Set\LaravelSetList;
// use Rector\Symfony\Set\SymfonySetList;
// use Rector\Doctrine\Set\DoctrineSetList;
// use Rector\PHPUnit\Set\PHPUnitSetList;

return RectorConfig::configure()

    // ───────────────────────────── 1. Paths ─────────────────────────────
    ->withPaths([
        __DIR__ . '/app',        // Laravel
        __DIR__ . '/src',        // Symfony / generic
        __DIR__ . '/config',
        __DIR__ . '/database',   // Laravel
        __DIR__ . '/routes',     // Laravel
        __DIR__ . '/tests',
        // WordPress (Bedrock or custom code only — never run Rector on third-party plugins):
        // __DIR__ . '/web/app/mu-plugins',
        // __DIR__ . '/wp-content/themes/your-theme',
    ])
    ->withSkip([
        __DIR__ . '/vendor',
        __DIR__ . '/storage',
        __DIR__ . '/bootstrap/cache',
        __DIR__ . '/var',
        __DIR__ . '/node_modules',
        __DIR__ . '/public',
        '*/migrations/*',        // Laravel/Doctrine migrations are history; leave them

        // Modernisation rules that are *in* the PHP sets but are style, not
        // compatibility. They bloat the migration diff; re-enable afterwards.
        ClosureToArrowFunctionRector::class,
        FirstClassCallableRector::class,
        ReadOnlyPropertyRector::class,
        FinalizePublicClassConstantRector::class,
        AddOverrideAttributeToOverriddenMethodsRector::class,
    ])

    // ─────────────────── 2. PHP level for THIS rung only ────────────────
    // Set exactly one of these to the version you are moving TO. Each flag
    // implies the lower ones. Match the *server's* new version, not the
    // newest PHP that exists.
    ->withPhpSets(
        // php80: true,
        // php81: true,
        php82: true,
        // php83: true,
        // php84: true,
        // php85: true,
    )

    // ─────────────── 3. Framework set for THIS rung only ────────────────
    // Exactly one; the version you are moving TO. Remove the block entirely
    // for a PHP-only rung.
    ->withSets([
        // LaravelSetList::LARAVEL_90,
        // LaravelSetList::LARAVEL_100,
        // LaravelSetList::LARAVEL_110,
        // LaravelSetList::LARAVEL_120,

        // SymfonySetList::SYMFONY_54,
        // SymfonySetList::SYMFONY_64,
        // SymfonySetList::SYMFONY_70,
        // SymfonySetList::SYMFONY_74,
        // SymfonySetList::ANNOTATIONS_TO_ATTRIBUTES,   // on 6.4, once PHP ≥ 8.1 is guaranteed

        // DoctrineSetList::DOCTRINE_DBAL_30,
        // DoctrineSetList::ANNOTATIONS_TO_ATTRIBUTES,

        // PHPUnitSetList::PHPUNIT_100,                 // PHPUnit 9 → 10 (annotations → attributes)
        // PHPUnitSetList::ANNOTATIONS_TO_ATTRIBUTES,
    ])

    // Keep these OFF during the migration. They are the "second PR".
    // ->withPreparedSets(deadCode: true, codeQuality: true, typeDeclarations: true)
    // ->withTypeCoverageLevel(0)

    // Symfony: lets Rector resolve services/containers for more accurate rewrites.
    // ->withSymfonyContainerXml(__DIR__ . '/var/cache/dev/App_KernelDevDebugContainer.xml')

    ->withImportNames(importShortClasses: false, removeUnusedImports: true)
    ->withParallel()
    ->withCache(cacheDirectory: __DIR__ . '/var/rector');
