import http.server
import socketserver
import threading
import time
import os

PORT = 8081
DIRECTORY = r'E:\Games\clone\roblox-openworld-codex\snapshots\CodexAvanceTest_Current'

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

httpd = socketserver.TCPServer(("127.0.0.1", PORT), Handler)
thread = threading.Thread(target=httpd.serve_forever)
thread.daemon = True
thread.start()

print("Server started on port 8081")
time.sleep(60) # Keep server alive for 60 seconds
