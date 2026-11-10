"""Mia Stream web geliştirme sunucusu.

build/web klasörünü sunar. Tarayıcı başka sunuculara doğrudan istek atamadığı
için (CORS) liste ve kapak istekleri /proxy?url=... ile buradan iletilir.
Yalnızca yerel geliştirme içindir.

Kullanım:
  flutter build web --release
  python3 tool/web/serve.py            # http://localhost:8787
  python3 tool/web/serve.py 9000       # başka port
"""

import sys
import urllib.error
import urllib.parse
import urllib.request
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "build" / "web"
AGENT = "MiaStream"

# Önceki derlemeden kalan önbellek çalışanını kaldırır; her yenilemede güncel sürüm gelir.
RETIRE_WORKER = """
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) await caches.delete(key);
    await self.registration.unregister();
    for (const client of await self.clients.matchAll()) client.navigate(client.url);
  })());
});
"""


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/proxy":
            self._proxy(parsed)
            return
        if parsed.path == "/flutter_service_worker.js" and not (ROOT / "flutter_service_worker.js").exists():
            self._send(RETIRE_WORKER, "text/javascript")
            return
        if not (ROOT / parsed.path.lstrip("/")).exists():
            self.path = "/index.html"
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _send(self, text, kind):
        body = text.encode()
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _proxy(self, parsed):
        target = urllib.parse.parse_qs(parsed.query).get("url", [""])[0]
        if not target.startswith(("http://", "https://")):
            self.send_error(400, "url gerekli")
            return
        request = urllib.request.Request(target, headers={"User-Agent": AGENT, "Accept": "*/*"})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read()
                self.send_response(response.status)
                self.send_header("Content-Type", response.headers.get("Content-Type", "application/octet-stream"))
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
        except urllib.error.HTTPError as error:
            self.send_error(error.code)
        except Exception as error:  # noqa: BLE001
            self.send_error(502, str(error)[:120])

    def log_message(self, fmt, *args):
        if "/proxy" not in (args[0] if args else ""):
            super().log_message(fmt, *args)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    if not ROOT.exists():
        sys.exit("Önce: flutter build web --release")
    server = ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=str(ROOT)))
    print(f"Mia Stream: http://localhost:{port}   TV düzeni: http://localhost:{port}/?tv=1")
    server.serve_forever()


if __name__ == "__main__":
    main()
