"""Loopback-only static map server. Never serves outside the viewer directory."""
import argparse
import json
import os
import io
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlsplit, unquote

VIEWER = (Path(__file__).resolve().parent / "viewer").resolve()
DATA = (Path(__file__).resolve().parent.parent / 'output/altis/viewer/data.js').resolve()
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs): super().__init__(*args,directory=str(VIEWER),**kwargs)
    def send_head(self):
        if urlsplit(self.path).path == '/data.js':
            if not DATA.is_file(): self.send_error(404); return None
            body = DATA.read_bytes()
            self.send_response(200); self.send_header('Content-Type','text/javascript; charset=utf-8'); self.send_header('Content-Length',str(len(body))); self.end_headers()
            return io.BytesIO(body)
        return super().send_head()
    def do_GET(self):
        if urlsplit(self.path).path == '/__health':
            body=json.dumps({'app':'IVCS RoadNetwork','pid':os.getpid(),'viewer':str(VIEWER)}).encode()
            self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
        if not self.allowed(): self.send_error(404);return
        super().do_GET()
    def do_HEAD(self):
        if not self.allowed(): self.send_error(404);return
        super().do_HEAD()
    def allowed(self):
        if urlsplit(self.path).path == '/data.js': return DATA.is_file()
        path=(VIEWER/unquote(urlsplit(self.path).path).lstrip('/')).resolve()
        if path==VIEWER: return True
        try: path.relative_to(VIEWER)
        except ValueError: return False
        return path.is_file() and path.suffix.lower() in {'.html','.js','.css','.png','.txt'}
    def list_directory(self,path): self.send_error(404)
    def end_headers(self):
        self.send_header('X-IVCS-RoadMap','1')
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Cache-Control','no-cache')
        super().end_headers()
    def log_message(self,*args): pass

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8767);args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    print(f'Road viewer: http://127.0.0.1:{args.port}',flush=True)
    server.serve_forever()
