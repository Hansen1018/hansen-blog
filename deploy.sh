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

echo "[deploy] hugo build (to staging $STAGING_DIR)..."
rm -rf "$STAGING_DIR"
hugo --minify --destination "$STAGING_DIR" >/dev/null

echo "[deploy] rsync --delete staging/ -> public/..."
rsync -av --delete "$STAGING_DIR/" public/

echo "[deploy] cleanup staging..."
rm -rf "$STAGING_DIR"

mkdir -p "$WEB_DIR/blog"
cp -f public/index.json "$WEB_DIR/$FEED_REL"

# touch the file to bump mtime — makes CF edge / browser caching give way
touch "$WEB_DIR/$FEED_REL"

SIZE=$(wc -c < "$WEB_DIR/$FEED_REL")
echo "[deploy] done. $FEED_REL size: $SIZE bytes @ $(date '+%H:%M:%S')"
