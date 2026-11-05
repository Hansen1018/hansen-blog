#!/usr/bin/env bash
# /var/www/blog/deploy.sh
# Rebuild Hugo + sync JSON feed to the hansen-web static site.
# Idempotent. Safe to re-run anytime.
# Update 2026-08-20: rsync --delete staging -> public/ to clean orphan output
# files (hugo --minify alone does NOT delete stale files in dest dir).
set -euo pipefail

BLOG_DIR="/var/www/blog"
WEB_DIR="/var/www/hansen-web"
FEED_REL="blog/feed.json"
STAGING_DIR="$BLOG_DIR/public.new"

cd "$BLOG_DIR"


# Sponsor QR images (WeChat / Alipay) are .gitignored private payment
# data. They live in static/images/sponsor/ locally for dev/build but are
# never committed. Hugo copies them to public/images/sponsor/ during build,
# and the rsync below deploys them to /var/www/blog/public/ like any other
# static asset — production has them, GitHub does not.
echo "[deploy] git pull (blog)..."
git pull --ff-only

# Theme lives at themes/hugo-theme-lumenveil (symlinked). Resolve and pull.
THEME_DIR="$(readlink -f themes/hugo-theme-lumenveil)"
if [ -d "$THEME_DIR/.git" ]; then
  echo "[deploy] git pull (theme)..."
  (cd "$THEME_DIR" && git pull --ff-only)
fi

echo "[deploy] hugo build (to staging $STAGING_DIR)..."
rm -rf "$STAGING_DIR"
hugo --minify --destination "$STAGING_DIR" >/dev/null

echo "[deploy] sync staging/ -> public/ (mirror)..."
# rsync is preferred. The sandbox ships rsync via /usr/local/bin/rsync, a wrapper
# pointing at a private payload under /workspace/.local/rsync/ — that payload is
# not guaranteed to survive a sandbox reset, and when it is missing the wrapper
# exits non-zero and kills this script (set -e). Fall back to cp -a + prune,
# which is semantically the same mirror (rsync --delete equivalent).
if command -v rsync >/dev/null 2>&1 && rsync --version >/dev/null 2>&1; then
  rsync -av --delete "$STAGING_DIR/" public/
else
  echo "[deploy] rsync unavailable/broken -> fallback: cp -a + prune stale files"
  cp -a "$STAGING_DIR/." public/
  # delete files/symlinks in public/ that are absent from staging/ (--delete)
  while IFS= read -r f; do
    [ -n "$f" ] && rm -f "public/$f"
  done < <(comm -23       <(cd public && find . \( -type f -o -type l \) -print | sort)       <(cd "$STAGING_DIR" && find . \( -type f -o -type l \) -print | sort))
  # then drop directories left empty by the prune
  find public -mindepth 1 -type d -empty -delete
fi

echo "[deploy] cleanup staging..."
rm -rf "$STAGING_DIR"

mkdir -p "$WEB_DIR/blog"
cp -f public/index.json "$WEB_DIR/$FEED_REL"

# touch the file to bump mtime — makes CF edge / browser caching give way
touch "$WEB_DIR/$FEED_REL"

SIZE=$(wc -c < "$WEB_DIR/$FEED_REL")
echo "[deploy] done. $FEED_REL size: $SIZE bytes @ $(date '+%H:%M:%S')"
