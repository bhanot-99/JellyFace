#!/usr/bin/env python3
"""Minimal fake greetd for testing the greeter UI without touching the real login.
Usage: mock-greetd.py SOCKET_PATH [PASSWORD]   (default password: test)"""
import json, os, socket, struct, sys

path, pw = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "test")

def recv(c):
    h = c.recv(4)
    if len(h) < 4:
        return None
    (n,) = struct.unpack("=I", h)
    b = b""
    while len(b) < n:
        b += c.recv(n - len(b))
    return json.loads(b)

def send(c, o):
    b = json.dumps(o).encode()
    c.sendall(struct.pack("=I", len(b)) + b)

if os.path.exists(path):
    os.unlink(path)
srv = socket.socket(socket.AF_UNIX)
srv.bind(path)
srv.listen(4)
print("mock greetd on", path, flush=True)
while True:
    c, _ = srv.accept()
    while (m := recv(c)) is not None:
        t = m.get("type")
        print("<-", t, {k: ("***" if k == "response" else v) for k, v in m.items()}, flush=True)
        if t == "create_session":
            send(c, {"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password: "})
        elif t == "post_auth_message_response":
            if m.get("response") == pw:
                send(c, {"type": "success"})
            else:
                send(c, {"type": "error", "error_type": "auth_error", "description": "Authentication failed"})
        elif t == "start_session":
            send(c, {"type": "success"})
        elif t == "cancel_session":
            send(c, {"type": "success"})
