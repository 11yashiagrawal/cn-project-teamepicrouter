#!/usr/bin/env python3
"""Team backend. Same code runs as A or B (both on Mac 2):
   window 1:  python3 server.py A 3001
   window 2:  python3 server.py B 3002
"""
import hashlib, json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NAME = sys.argv[1] if len(sys.argv) > 1 else "A"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 3001

# GET / is identical on A and B, so its ETag matches whichever backend answers.
HOME = b'{"service": "teamepicrouter", "message": "service is running"}\n'
HOME_ETAG = '"' + hashlib.sha256(HOME).hexdigest()[:16] + '"'


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body=None, headers=None):
        self.send_response(code)
        self.send_header("X-Backend", NAME)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        if body is not None:
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body is not None and self.command != "HEAD":
            self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            cache = {"Cache-Control": "public, max-age=60", "ETag": HOME_ETAG}
            if self.headers.get("If-None-Match") == HOME_ETAG:
                return self.reply(304, None, cache)       # conditional request: not modified
            return self.reply(200, HOME, cache)
        if self.path == "/api/status":
            body = (json.dumps({"backend": NAME, "status": "ok"}) + "\n").encode()
            return self.reply(200, body, {"Cache-Control": "no-store"})  # never cached
        self.reply(404, b'{"error": "not found"}\n')

    do_HEAD = do_GET  # curl -I sends HEAD

    def log_message(self, fmt, *args):
        h = getattr(self, "headers", None)
        client = h.get("X-Forwarded-For", "-") if h else "-"
        sys.stderr.write(f"[{NAME}] from {self.client_address[0]} (real client {client}) {fmt % args}\n")


if __name__ == "__main__":
    print(f"Backend {NAME} listening on 0.0.0.0:{PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
