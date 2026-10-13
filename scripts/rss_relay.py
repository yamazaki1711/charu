#!/usr/bin/env python3
"""RSS-ретранслятор для эмулятора CHARU.
Эмулятор берёт фиды с http://10.0.2.2:8090/<имя>.xml (алиас хоста),
ретранслятор скачивает их с реальных источников и отдаёт приложению.
Запуск: launchd агент local.rss-relay (порт 8090, хост-лупбэк).
"""
import http.server
import socketserver
import urllib.request
import ssl

PORT = 8090
UPSTREAM = {
    "/life.xml": "https://www.chinanews.com.cn/rss/life.xml",
    "/sh.xml": "https://www.chinanews.com.cn/rss/sh.xml",
    "/scroll-news.xml": "https://www.chinanews.com.cn/rss/scroll-news.xml",
}
# Не доверять перехвату TLS через старые корневые — контекст по умолчанию ок,
# но на всякий случай не жёстко.
CTX = ssl.create_default_context()


class Relay(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?")[0]
        upstream = UPSTREAM.get(path)
        if not upstream:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"not found")
            return
        try:
            req = urllib.request.Request(
                upstream,
                headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"},
            )
            with urllib.request.urlopen(req, timeout=20, context=CTX) as r:
                body = r.read()
            self.send_response(200)
            self.send_header("Content-Type", r.headers.get("Content-Type", "application/xml"))
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            body = f"<error>{e}</error>".encode()
            self.send_response(502)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass  # тихий режим


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with Server(("127.0.0.1", PORT), Relay) as httpd:
        httpd.serve_forever()
