#!/usr/bin/env bash
# assess.sh — read-only PHP ecosystem migration assessment.
#
# Usage:  scripts/assess.sh [TARGET_PHP] [PROJECT_DIR]
#         scripts/assess.sh 8.4 .
#
# Writes a Markdown report to stdout. Makes NO changes to the project:
# no composer install/update, no file edits. Tools that are missing are
# reported as missing, and the corresponding section says what to run by hand.
#
# Detects: Laravel, Symfony, WordPress (plain or Bedrock), generic Composer.

set -u
TARGET="${1:-8.4}"
DIR="${2:-.}"
cd "$DIR" || { echo "Cannot cd to $DIR" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n\n' "$1"; }
code() { printf '```\n%s\n```\n' "$1"; }
json_get() { # json_get FILE JQ_EXPR  — falls back to grep-ish when jq is absent
  if have jq; then jq -r "$2 // empty" "$1" 2>/dev/null
  else php -r 'echo @json_decode(file_get_contents($argv[1]), true)'"$3"' ?? "";' "$1" 2>/dev/null
  fi
}

echo "# Migration assessment — $(basename "$(pwd)")"
echo
echo "_Generated $(date -u +%Y-%m-%dT%H:%MZ) · target PHP ${TARGET} · read-only_"

# ---------------------------------------------------------------- current state
section "Current state"

if have php; then
  PHPV=$(php -r 'echo PHP_VERSION;')
  SAPI=$(php -r 'echo PHP_SAPI;')
  echo "- PHP (CLI): **${PHPV}** (sapi: ${SAPI}) — the web SAPI may differ; verify with phpinfo() through the web server"
  echo "- php.ini (CLI): $(php --ini | awk -F': ' '/Loaded Configuration/{print $2}')"
else
  echo "- PHP: **not found on PATH** — record \`php -v\` from the real server manually"
fi

if have php-fpm || have php-fpm8.2 || have php-fpm8.3 || have php-fpm8.4; then
  echo "- php-fpm binary present"
fi
if have apachectl || have httpd; then
  echo "- Apache present — check whether mod_php or FPM proxy is in use"
fi

if [ -f composer.json ]; then
  CONSTRAINT=$(json_get composer.json '.require.php' '["require"]["php"]')
  echo "- composer.json php constraint: \`${CONSTRAINT:-none}\`"
  PLATFORM=$(json_get composer.json '.config.platform.php' '["config"]["platform"]["php"]')
  [ -n "$PLATFORM" ] && echo "- composer platform.php override: \`${PLATFORM}\` (Composer resolves against this, not the real PHP)"
  if [ -f composer.lock ]; then
    LOCKPLAT=$(json_get composer.lock '.platform.php' '["platform"]["php"]')
    echo "- composer.lock platform php: \`${LOCKPLAT:-none}\`"
  else
    echo "- **No composer.lock** — the installed set is not reproducible"
  fi
else
  echo "- No composer.json (not a Composer project)"
fi

# ---------------------------------------------------------------- framework
section "Framework / CMS"

FW="unknown"
if [ -f composer.lock ] && have jq; then
  LARAVEL=$(jq -r '.packages[] | select(.name=="laravel/framework") | .version' composer.lock)
  SYMFONY=$(jq -r '.packages[] | select(.name=="symfony/framework-bundle" or .name=="symfony/symfony") | .version' composer.lock | head -1)
  LUMEN=$(jq -r '.packages[] | select(.name=="laravel/lumen-framework") | .version' composer.lock)
  BEDROCK=$(jq -r '.packages[] | select(.name=="roots/wordpress" or .name=="johnpbloch/wordpress") | .version' composer.lock | head -1)
  [ -n "$LARAVEL" ] && { FW="laravel"; echo "- **Laravel ${LARAVEL}**"; }
  [ -n "$LUMEN" ]   && { FW="lumen";   echo "- **Lumen ${LUMEN}** (maintenance mode — plan to move to Laravel)"; }
  [ -n "$SYMFONY" ] && { FW="symfony"; echo "- **Symfony ${SYMFONY}**"; }
  [ -n "$BEDROCK" ] && { FW="wordpress-composer"; echo "- **WordPress (Composer-managed) ${BEDROCK}**"; }
fi
if [ -f wp-includes/version.php ]; then
  WPV=$(grep -oP "\\\$wp_version = '\K[^']+" wp-includes/version.php)
  WPPHP=$(grep -oP "\\\$required_php_version = '\K[^']+" wp-includes/version.php)
  FW="wordpress"
  echo "- **WordPress ${WPV}** (core requires PHP ≥ ${WPPHP})"
  if have wp; then
    echo "- Active plugins: $(wp plugin list --status=active --field=name 2>/dev/null | wc -l | tr -d ' ')"
    echo "- Inactive plugins (delete before migrating): $(wp plugin list --status=inactive --field=name 2>/dev/null | wc -l | tr -d ' ')"
    echo "- Themes: $(wp theme list --field=name 2>/dev/null | wc -l | tr -d ' ')"
  else
    echo "- Plugins dir: $(ls -1 wp-content/plugins 2>/dev/null | wc -l | tr -d ' ') entries (wp-cli not found; audit by hand)"
  fi
  [ -d wp-content/mu-plugins ] && echo "- mu-plugins present: $(ls -1 wp-content/mu-plugins | tr '\n' ' ')"
  echo
  echo "→ Read \`references/wordpress.md\`; the plugin audit table is the real assessment here."
fi
[ "$FW" = "unknown" ] && echo "- No recognised framework; treat as generic Composer/PHP project"

# ---------------------------------------------------------------- blockers
if [ -f composer.json ] && have composer; then
  section "Packages blocking PHP ${TARGET}  (\`composer why-not php ${TARGET}\`)"
  OUT=$(composer why-not php "${TARGET}" 2>&1 | grep -v '^$' | head -60)
  if [ -z "$OUT" ] || echo "$OUT" | grep -qi "there is no installed package"; then
    echo "Nothing blocks PHP ${TARGET} at the constraint level (code-level issues may remain — see deprecations)."
  else
    code "$OUT"
  fi

  section "Abandoned packages"
  AB=$(composer show --direct 2>/dev/null | grep -i abandoned)
  AB_ALL=$(composer show 2>/dev/null | grep -ic abandoned)
  if [ -n "$AB" ]; then code "$AB"; else echo "No *direct* abandoned packages."; fi
  echo "Total abandoned (incl. transitive): ${AB_ALL:-0}"
  echo
  echo "→ For each: \`references/package-replacements.md\`"

  section "Outdated direct dependencies (majors only)"
  OD=$(composer outdated --direct --major-only 2>/dev/null | head -40)
  if [ -n "$OD" ]; then code "$OD"; else echo "None, or composer could not resolve (run \`composer outdated --direct\` manually)."; fi
elif [ -f composer.json ]; then
  section "Packages"
  echo "composer not on PATH. Run manually: \`composer why-not php ${TARGET}\`, \`composer show --direct | grep -i abandoned\`, \`composer outdated --direct\`"
fi

# ---------------------------------------------------------------- deprecations
section "Deprecation / compatibility sniff  (PHPCompatibility, testVersion ${TARGET}-)"

SRC_DIRS=""
for d in app src lib includes wp-content/plugins wp-content/themes wp-content/mu-plugins web/app; do
  [ -d "$d" ] && SRC_DIRS="$SRC_DIRS $d"
done
[ -z "$SRC_DIRS" ] && SRC_DIRS="."

STD="PHPCompatibility"
case "$FW" in wordpress*) STD="PHPCompatibilityWP";; esac

PHPCS=""
for c in vendor/bin/phpcs phpcs "$HOME/.composer/vendor/bin/phpcs" "$HOME/.config/composer/vendor/bin/phpcs"; do
  if [ -x "$c" ] || have "$c"; then PHPCS="$c"; break; fi
done

if [ -n "$PHPCS" ] && $PHPCS -i 2>/dev/null | grep -q "$STD"; then
  echo "Standard: ${STD} · paths:${SRC_DIRS}"
  echo
  # shellcheck disable=SC2086
  SUMMARY=$($PHPCS -q --standard="$STD" --runtime-set testVersion "${TARGET}-" \
            --extensions=php --ignore='*/vendor/*,*/node_modules/*,*/storage/*,*/cache/*' \
            --report=summary $SRC_DIRS 2>/dev/null | tail -8)
  code "$SUMMARY"
  echo "Per-sniff counts (this is the table that sizes the work):"
  # shellcheck disable=SC2086
  BYSNIFF=$($PHPCS -q --standard="$STD" --runtime-set testVersion "${TARGET}-" \
            --extensions=php --ignore='*/vendor/*,*/node_modules/*,*/storage/*,*/cache/*' \
            --report=source $SRC_DIRS 2>/dev/null | grep -E '^\s*PHPCompatibility' | head -40)
  code "${BYSNIFF:-no findings}"
else
  echo "PHPCompatibility sniff not available. Install once (global, read-only for the project):"
  code "composer global require --dev phpcompatibility/php-compatibility dealerdirect/phpcodesniffer-composer-installer
# WordPress: also phpcompatibility/phpcompatibility-wp
phpcs -p --standard=${STD} --runtime-set testVersion ${TARGET}- --extensions=php --report=summary${SRC_DIRS}"
fi

# ---------------------------------------------------------------- quick greps
section "Quick grep for removed / dangerous constructs"

GREP=rg; have rg || GREP=grep
patterns=(
  'create_function\('   '\beach\('         'mysql_(connect|query|fetch_|num_rows)'
  '\bereg'              'mcrypt_'          'utf8_(en|de)code\('
  '\$\{[a-zA-Z_]'       'money_format\('   '__autoload\('
  'FILTER_SANITIZE_STRING' 'strftime\('    'get_magic_quotes'
  '\)\s*=\s*null\s*[,)]'
)
labels=(
  'create_function (removed 8.0)' 'each() (removed 8.0)' 'mysql_* (removed 7.0)'
  'ereg* (removed 7.0)' 'mcrypt_* (removed 7.2)' 'utf8_encode/decode (deprecated 8.2)'
  '${var} interpolation (deprecated 8.2)' 'money_format (removed 8.0)' '__autoload (removed 8.0)'
  'FILTER_SANITIZE_STRING (deprecated 8.1)' 'strftime (deprecated 8.1)' 'magic_quotes (removed 8.0)'
  'implicitly nullable param "= null" (deprecated 8.4; noisy — review)'
)
printf '| Pattern | Hits |\n|---|---|\n'
for i in "${!patterns[@]}"; do
  if [ "$GREP" = rg ]; then
    # shellcheck disable=SC2086
    n=$(rg -c --type php -g '!vendor' -g '!node_modules' -e "${patterns[$i]}" $SRC_DIRS 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  else
    # shellcheck disable=SC2086
    n=$(grep -rEc --include='*.php' --exclude-dir=vendor --exclude-dir=node_modules -e "${patterns[$i]}" $SRC_DIRS 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  fi
  printf '| %s | %s |\n' "${labels[$i]}" "$n"
done

# ---------------------------------------------------------------- tests
section "Safety net"

if [ -f phpunit.xml ] || [ -f phpunit.xml.dist ] || [ -f phpunit.dist.xml ]; then
  echo "- PHPUnit config present"
  TESTS=$(find tests test -name '*Test.php' 2>/dev/null | wc -l | tr -d ' ')
  echo "- Test files: ${TESTS}"
  if have jq && [ -f composer.lock ]; then
    PU=$(jq -r '.["packages-dev"][] | select(.name=="phpunit/phpunit") | .version' composer.lock)
    [ -n "$PU" ] && echo "- PHPUnit ${PU} (PHPUnit 10+ needs PHP ≥ 8.1; 11+ ≥ 8.2 — may itself be a rung)"
  fi
  echo "- Run the suite now and record the baseline (count, failures, duration) before the first rung."
else
  echo "- **No PHPUnit configuration found.** Plan characterization tests (snapshots of key routes/commands) before touching code — see SKILL.md step 4."
fi
if ls .github/workflows/*.yml >/dev/null 2>&1; then echo "- GitHub Actions present — add a PHP matrix (current + next rung)"; fi
[ -f .gitlab-ci.yml ] && echo "- GitLab CI present — add a PHP matrix (current + next rung)"
[ -f rector.php ] && echo "- rector.php already present — review before replacing with scripts/rector.template.php"

# ---------------------------------------------------------------- next
section "Next"
cat <<EOF
1. Fill in the **Target** and **Proposed ladder** sections using \`references/framework-matrix.md\`.
2. Confirm the security floor: is PHP ${PHPV:-?} a release that still gets fixes, and is it on the latest patch? (\`references/php-security-2026.md\`)
3. Share this report before editing anything.
EOF
