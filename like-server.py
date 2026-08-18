#!/usr/bin/env python3
"""Blog + Like API server with per-user voter tracking.

Serves static files from /var/www/blog/public/ and handles
/api/like/* endpoints. Stores like counts AND voter lists per
URL so the "is liked" state can be shared across devices via
anonymous UID (cookie + localStorage).

likes.json schema:
{
  "/archives/2026/08/hugo-lumenveil/": {
    "count": 5,
    "voters": ["uuid1", "uuid2", ...]
  }
}
"""
import json
import os
import re
import sys
import uuid
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PUBLIC_DIR = '/var/www/blog/public'
LIKE_FILE = '/var/www/blog/likes.json'
PORT = 1313
COOKIE_NAME = 'lumenveil_uid'
COOKIE_MAX_AGE = 31536000  # 1 year

PAGE_KEY_RE = re.compile(r'^[a-zA-Z0-9/_.-]+$')
UID_RE = re.compile(r'^[a-zA-Z0-9-]{8,64}$')

def load_likes():
    if not os.path.exists(LIKE_FILE):
        return {}
    try:
        with open(LIKE_FILE, 'r') as f:
            data = json.load(f)
        # Migrate old format (int) to new format (dict with voters)
        for key, value in list(data.items()):
            if isinstance(value, int):
                data[key] = {"count": value, "voters": []}
        return data
    except (json.JSONDecodeError, IOError):
        return {}

def save_likes(likes):
    tmp = LIKE_FILE + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(likes, f, indent=2)
    os.replace(tmp, LIKE_FILE)

def get_or_create_uid(cookie_header):
    """Extract UID from cookie header, or generate a new one."""
    if cookie_header:
        for c in cookie_header.split(';'):
            c = c.strip()
            if c.startswith(COOKIE_NAME + '='):
                uid = c[len(COOKIE_NAME) + 1:]
                if UID_RE.match(uid):
                    return uid, False
    return uuid.uuid4().hex, True

def set_cookie_header(uid):
    return f"{COOKIE_NAME}={uid}; Path=/; Max-Age={COOKIE_MAX_AGE}; SameSite=Lax"

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PUBLIC_DIR, **kwargs)

    def log_message(self, format, *args):
        pass

    def _send_json(self, status, data, set_cookie=None):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        if set_cookie:
            self.send_header('Set-Cookie', set_cookie)
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def _validate_key(self, key):
        if not key or len(key) > 200:
            return False
        return bool(PAGE_KEY_RE.match(key))

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path.startswith('/api/like/state'):
            qs = parse_qs(parsed.query)
            key = qs.get('key', [''])[0]
            if not self._validate_key(key):
                return self._send_json(400, {'error': 'invalid key'})
            uid, is_new = get_or_create_uid(self.headers.get('Cookie'))
            likes = load_likes()
            entry = likes.get(key, {"count": 0, "voters": []})
            liked = uid in entry["voters"]
            cookie = set_cookie_header(uid) if is_new else None
            return self._send_json(200, {'count': entry["count"], 'liked': liked}, set_cookie=cookie)
        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path.startswith('/api/like/up'):
            qs = parse_qs(parsed.query)
            key = qs.get('key', [''])[0]
            if not self._validate_key(key):
                return self._send_json(400, {'error': 'invalid key'})
            uid, is_new = get_or_create_uid(self.headers.get('Cookie'))
            cookie = set_cookie_header(uid) if is_new else None

            likes = load_likes()
            entry = likes.setdefault(key, {"count": 0, "voters": []})

            if uid in entry["voters"]:
                # Already liked — no-op, return current state
                return self._send_json(200, {'count': entry["count"], 'liked': True, 'already': True}, set_cookie=cookie)

            entry["voters"].append(uid)
            entry["count"] += 1
            save_likes(likes)
            return self._send_json(200, {'count': entry["count"], 'liked': True}, set_cookie=cookie)
        self.send_response(404)
        self.end_headers()

if __name__ == '__main__':
    server = ThreadingHTTPServer(('0.0.0.0', PORT), Handler)
    print(f'Blog + Like API on 0.0.0.0:{PORT}', flush=True)
    sys.stdout.flush()
    server.serve_forever()
