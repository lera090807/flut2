import argparse
import http.client
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

parser = argparse.ArgumentParser()
parser.add_argument('--directory', default='build/web')
parser.add_argument('--port', type=int, default=5555)
parser.add_argument('--base-path', default='/')
parser.add_argument('--api', default='')
args = parser.parse_args()
root = Path(args.directory).resolve()
base = '/' + args.base_path.strip('/') + '/' if args.base_path.strip('/') else '/'

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(root), **kw)

    def do_GET(self):
        request_path = urlsplit(self.path).path
        if args.api and request_path.startswith('/api/'):
            return self.proxy()
        if not request_path.startswith(base):
            self.send_error(404)
            return
        self.path = '/' + self.path[len(base):]
        file = (root / urlsplit(self.path).path.lstrip('/')).resolve()
        if not file.is_relative_to(root):
            self.send_error(403)
            return
        if not file.is_file():
            if Path(request_path).suffix:
                self.send_error(404)
                return
            self.path = '/index.html'
        super().do_GET()

    def proxy(self):
        upstream = urlsplit(args.api)
        connection = http.client.HTTPConnection(upstream.hostname, upstream.port, timeout=20)
        try:
            body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
            headers = {k: v for k, v in self.headers.items() if k.lower() not in ('host', 'connection')}
            connection.request(self.command, self.path, body, headers)
            response = connection.getresponse()
            payload = response.read()
            self.send_response(response.status)
            for k, v in response.getheaders():
                if k.lower() not in ('transfer-encoding', 'connection', 'content-length'):
                    self.send_header(k, v)
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except OSError:
            self.send_error(502, 'API unavailable')
        finally:
            connection.close()

    def do_POST(self):
        if args.api and self.path.startswith('/api/'):
            self.proxy()
        else:
            self.send_error(405)

    do_PUT = do_POST
    do_DELETE = do_POST

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

print(f'Магазин: http://localhost:{args.port}{base}', flush=True)
ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
