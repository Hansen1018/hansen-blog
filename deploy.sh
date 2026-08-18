#!/usr/bin/env bash
# /var/www/blog/deploy.sh
# Rebuild Hugo + sync JSON feed to the hansen-web static site.
# Idempotent. Safe to re-run anytime.
set -euo pipefail

BLOG_DIR="/var/www/blog"
WEB_DIR="/var/www/hansen-web"
FEED_REL="blog/feed.json"

cd "$BLOG_DIR"

echo "[deploy] hugo build..."
hugo --minify >/dev/null

mkdir -p "$WEB_DIR/blog"
cp -f public/index.json "$WEB_DIR/$FEED_REL"

# touch the file to bump mtime — makes CF edge / browser caching give way
touch "$WEB_DIR/$FEED_REL"

SIZE=$(wc -c < "$WEB_DIR/$FEED_REL")
echo "[deploy] done. $FEED_REL size: $SIZE bytes @ $(date '+%H:%M:%S')"
