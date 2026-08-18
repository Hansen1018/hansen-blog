#!/usr/bin/env bash
# /var/www/blog/watch.sh
# Poll /var/www/blog/content for .md changes every INTERVAL seconds,
# then run deploy.sh to rebuild + sync. No inotifywait / external deps.
# Run in background, e.g.:  nohup /var/www/blog/watch.sh >>/var/log/blog-sync.log 2>&1 &
set -euo pipefail

CONTENT_DIR="/var/www/blog/content"
DEPLOY="/var/www/blog/deploy.sh"
INTERVAL="${INTERVAL:-60}"   # seconds
LOG_PREFIX="[watch]"

# Per user's rule (2026-08-18):
# "以后新建文章和修改已有文章先检查有没有toc"
# hugo.toml TOC 配置 startLevel=2..4，所以匹配 ## / ### / ####
TOC_HEADING_RE='^## |^### |^#### '

echo "$LOG_PREFIX start, content=$CONTENT_DIR interval=${INTERVAL}s deploy=$DEPLOY"

# Pre-deploy TOC check: scan ALL archives/.md and warn if any lacks h2-h4.
# Runs on every iteration (cheap), independent of changes — catches old
# articles that never got ## headings too.
toc_check() {
    local missing=0 total=0
    while IFS= read -r md; do
        [ -z "$md" ] && continue
        total=$((total + 1))
        if ! grep -qE "$TOC_HEADING_RE" "$md"; then
            echo "$LOG_PREFIX ⚠️  TOC empty: ${md#$CONTENT_DIR/}"
            missing=$((missing + 1))
        fi
    done < <(find "$CONTENT_DIR/archives" -type f -name "*.md" 2>/dev/null)
    if [ "$missing" -eq 0 ]; then
        echo "$LOG_PREFIX TOC ok — $total article(s), all have ## headings"
    else
        echo "$LOG_PREFIX ⚠️  $missing/$total article(s) missing ## headings (deploy still runs)"
    fi
}

while true; do
    # any .md under content/ modified in the last (2 * INTERVAL) seconds
    changed=$(find "$CONTENT_DIR" -type f -name "*.md" -mmin "-$((INTERVAL * 2 / 60 + 1))" 2>/dev/null)
    if [ -n "$changed" ]; then
        echo "$LOG_PREFIX content change detected @ $(date '+%H:%M:%S')"
        echo "$LOG_PREFIX changed files:"
        while IFS= read -r md; do
            [ -n "$md" ] && echo "$LOG_PREFIX   - ${md#$CONTENT_DIR/}"
        done <<< "$changed"

        # Per-rule check, scoped to changed files only (fast feedback)
        echo "$LOG_PREFIX per-file TOC check (changed files):"
        while IFS= read -r md; do
            [ -z "$md" ] && continue
            if grep -qE "$TOC_HEADING_RE" "$md"; then
                echo "$LOG_PREFIX   ✓ ${md#$CONTENT_DIR/}"
            else
                echo "$LOG_PREFIX   ✗ MISSING ## headings: ${md#$CONTENT_DIR/}"
            fi
        done <<< "$changed"

        if "$DEPLOY" 2>&1; then
            echo "$LOG_PREFIX sync ok"
        else
            echo "$LOG_PREFIX deploy.sh failed (exit $?)"
        fi

        # Daily reminder scan: see if any other article lacks TOC
        toc_check
    fi
    sleep "$INTERVAL"
done
