---
name: laradock-worktree
description: Point laradock at a different code path (typically a git worktree at ~/Locally/.claude/worktrees/...) so you can preview that branch in the browser. Copies the env / vendor / compiled assets the bind-mounted containers need (symlinks don't resolve inside the container), updates ~/Locally/laradock/.env, and recreates nginx + php-fpm + workspace so the new mount takes. Use when the user asks to "switch laradock to <path>", "point laradock at <branch>", "preview this branch in the browser", or any phrasing that means "make the local site serve a different worktree".
---

# Laradock worktree pointer

The Locally dev environment runs in laradock (`~/Locally/laradock`). The `nginx`, `php-fpm`, and `workspace` containers bind-mount whatever path is in `APP_CODE_PATH_HOST` in `~/Locally/laradock/.env`. To preview a worktree (or any alternate checkout) in the browser, that path needs to point at the worktree AND the worktree needs the env, vendor, and compiled assets the containers expect.

This skill is the one-liner to do the whole switch.

## Usage

```bash
~/.claude/skills/laradock-worktree/point.sh <target-worktree-path>
```

Optional `--from <source-path>` to copy the env/vendor from a specific worktree. By default the script copies from whatever `APP_CODE_PATH_HOST` currently points at — so re-running it on a fresh worktree picks up wherever you were last working.

## What it does

1. Resolves target and source paths.
2. Copies into the target:
   * `.env` and `composer.lock`
   * `vendor/` (the slow one — rsync, ~30 seconds the first time)
   * `public/css/{compiled,min}`, `public/js/{compiled,min,react}`
   * `app/storage/creds/bq-adc.json`
3. `chmod 777` on `app/storage/{cache,logs,meta,sessions,views}` so Laravel can write the compiled blade view cache from inside the container.
4. Updates `APP_CODE_PATH_HOST` in `~/Locally/laradock/.env`.
5. `stop + rm + up -d` for `nginx`, `php-fpm`, `workspace` (the bind-mounted ones) and brings up `memcached`, `redis`, `mysql` (which a `docker compose down` would otherwise kill).
6. Clears any stale compiled blade views inside the container.
7. Waits up to 60s for `http://localhost/station/login` to return 200/302/301 and reports success.

## Why copy and not symlink

The containers bind-mount the worktree path. Symlinks pointing OUTSIDE that mount root resolve to a path the container can't see — it's a different filesystem namespace. So `vendor/` and the compiled assets have to be physical copies inside the worktree.

## Gotchas this skill handles

* `docker compose down` would stop `memcached` / `redis` / `mysql` too — once those go away, Laravel throws a `MemcachedConnector` 500 on the first request. We `stop + rm` only the bind-mounted services and `up` brings the supporting ones back if they had been stopped.
* PHP-FPM caches the "vendor/autoload.php not found" failure across requests — recreating the container side-steps the cached failure rather than restarting in place.
* Blade view cache files inherit ownership from whichever container wrote them; a fresh worktree's `app/storage/views/` is `lifeboy:lifeboy` and `www-data` (gid 33 in the container) can't write to it without the chmod.
* Trailing slash on `APP_CODE_PATH_HOST` matters — we always write it with one.

## Trigger phrases

* "switch laradock to …"
* "point laradock at this worktree"
* "preview \<branch\>" / "let me preview that in the browser"
* "the panel isn't loading" — usually means laradock is pointed somewhere stale
* Right after `git worktree add` for a branch you want to view
