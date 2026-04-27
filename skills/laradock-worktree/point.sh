#!/usr/bin/env bash
# laradock-worktree: point laradock at a different code path.
#
# Usage:
#   point.sh <target-worktree-path> [--from <source-path>]
#
# Copies env/vendor/compiled assets the bind-mounted containers need,
# updates laradock's .env, and recreates nginx + php-fpm + workspace so
# the new APP_CODE_PATH_HOST takes. See SKILL.md for the why behind each
# step.

set -euo pipefail

LARADOCK_DIR="${LARADOCK_DIR:-/home/lifeboy/Locally/laradock}"
DEFAULT_SOURCE="${DEFAULT_SOURCE:-/home/lifeboy/Locally}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <target-worktree> [--from <source>]

Points laradock at <target-worktree>. Copies env/vendor/compiled assets
from <source> (defaults to whatever APP_CODE_PATH_HOST currently points
at, falling back to $DEFAULT_SOURCE if that's gone).

Examples:
    $(basename "$0") ~/Locally/.claude/worktrees/frg-268
    $(basename "$0") ~/Locally/.claude/worktrees/frg-268 --from ~/Locally
EOF
    exit 1
}

[[ $# -lt 1 ]] && usage

TARGET="$1"
shift

SOURCE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from) SOURCE="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "unknown flag: $1" >&2; usage;;
    esac
done

# Resolve TARGET to an absolute path. Fail loudly if it's not a directory.
if [[ ! -d "$TARGET" ]]; then
    echo "✗ target not a directory: $TARGET" >&2
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

LARADOCK_ENV="$LARADOCK_DIR/.env"
if [[ ! -f "$LARADOCK_ENV" ]]; then
    echo "✗ laradock .env not found at $LARADOCK_ENV" >&2
    echo "   Set LARADOCK_DIR if your laradock checkout is elsewhere." >&2
    exit 1
fi

# Resolve SOURCE: explicit > current APP_CODE_PATH_HOST > default.
if [[ -z "$SOURCE" ]]; then
    CURRENT="$(grep -E '^APP_CODE_PATH_HOST=' "$LARADOCK_ENV" | head -1 | cut -d= -f2-)"
    CURRENT="${CURRENT%/}"
    if [[ -d "$CURRENT" && -d "$CURRENT/vendor" ]]; then
        SOURCE="$CURRENT"
    elif [[ -d "$DEFAULT_SOURCE" && -d "$DEFAULT_SOURCE/vendor" ]]; then
        SOURCE="$DEFAULT_SOURCE"
    else
        echo "✗ couldn't find a source with vendor/ to copy from." >&2
        echo "   Tried: $CURRENT, $DEFAULT_SOURCE" >&2
        echo "   Pass --from <path> explicitly." >&2
        exit 1
    fi
fi
SOURCE="$(cd "$SOURCE" && pwd)"

echo "→ Source : $SOURCE"
echo "→ Target : $TARGET"

if [[ "$SOURCE" != "$TARGET" ]]; then
    echo "→ Copying env files…"
    [[ -f "$SOURCE/.env" ]]          && cp -f "$SOURCE/.env"          "$TARGET/.env"
    [[ -f "$SOURCE/composer.lock" ]] && cp -f "$SOURCE/composer.lock" "$TARGET/composer.lock"

    if [[ -d "$SOURCE/vendor" ]]; then
        echo "→ Copying vendor/ (~30s first time)…"
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --delete "$SOURCE/vendor/" "$TARGET/vendor/"
        else
            rm -rf "$TARGET/vendor"
            cp -R "$SOURCE/vendor" "$TARGET/vendor"
        fi
    fi

    echo "→ Copying compiled assets…"
    for d in public/css/compiled public/css/min public/js/compiled public/js/min public/js/react; do
        if [[ -d "$SOURCE/$d" ]]; then
            mkdir -p "$(dirname "$TARGET/$d")"
            if command -v rsync >/dev/null 2>&1; then
                rsync -a --delete "$SOURCE/$d/" "$TARGET/$d/"
            else
                rm -rf "$TARGET/$d"
                cp -R "$SOURCE/$d" "$TARGET/$d"
            fi
        fi
    done

    if [[ -f "$SOURCE/app/storage/creds/bq-adc.json" ]]; then
        echo "→ Copying BQ creds…"
        mkdir -p "$TARGET/app/storage/creds"
        cp -f "$SOURCE/app/storage/creds/bq-adc.json" "$TARGET/app/storage/creds/bq-adc.json"
    fi
else
    echo "→ Source == target. Skipping copies."
fi

echo "→ Loosening storage perms (Laravel writes the blade view cache)…"
for sub in cache logs meta sessions views; do
    if [[ -d "$TARGET/app/storage/$sub" ]]; then
        chmod -R 777 "$TARGET/app/storage/$sub" 2>/dev/null || true
    fi
done

echo "→ Updating APP_CODE_PATH_HOST in $LARADOCK_ENV …"
TARGET_WITH_SLASH="$TARGET/"
# In-place sed; handle | as separator since paths have slashes.
sed -i.bak "s|^APP_CODE_PATH_HOST=.*|APP_CODE_PATH_HOST=$TARGET_WITH_SLASH|" "$LARADOCK_ENV"
rm -f "$LARADOCK_ENV.bak"

echo "→ Recreating bind-mounted containers (nginx, php-fpm, workspace)…"
cd "$LARADOCK_DIR"
docker compose stop nginx php-fpm workspace 2>/dev/null || true
docker compose rm -f nginx php-fpm workspace 2>/dev/null || true
# Up the bind-mounted ones plus the supporting services Laravel needs.
# `docker compose up -d <svc>` is idempotent — already-running services
# are left alone, stopped ones are started.
docker compose up -d nginx php-fpm workspace memcached redis mysql 2>&1 | tail -10

# Clear stale compiled blade views inside the container so a perms-locked
# file from a previous run doesn't immediately 500 the next request.
docker exec lde-php-fpm-1 sh -c 'rm -f /var/www/app/storage/views/* 2>/dev/null' || true

echo "→ Waiting for HTTP to come up…"
for i in $(seq 1 30); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' http://localhost/station/login 2>/dev/null || true)"
    if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" ]]; then
        echo "✓ http://localhost/ healthy (HTTP $code) — laradock now serving:"
        echo "   $TARGET"
        exit 0
    fi
    sleep 2
done

echo "✗ HTTP didn't come up healthy in 60s." >&2
echo "   Check 'docker compose logs nginx php-fpm' in $LARADOCK_DIR." >&2
exit 1
