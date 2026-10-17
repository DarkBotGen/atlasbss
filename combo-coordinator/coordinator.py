"""Atlas+ combo coordinator. Standard library only; no game credentials needed."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import math
from pathlib import Path
import re
import secrets
import subprocess
import threading
import time
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parent
NAME = re.compile(r"^[A-Za-z0-9_]{3,20}$")


def point(value):
    if not isinstance(value, list) or len(value) != 3:
        raise ValueError("Invalid position")
    result = tuple(float(v) for v in value)
    if not all(math.isfinite(v) and abs(v) < 100000 for v in result):
        raise ValueError("Invalid position")
    return result


def distance(a, b):
    return math.hypot(a[0] - b[0], a[2] - b[2])


class Coordinator:
    """Bounded, locked, per-Roblox-server state; times are local monotonic seconds."""

    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.rooms = {}
        self.lock = threading.Lock()

    def prune(self, now):
        for server, room in list(self.rooms.items()):
            if now - room["seen"] > 30:
                del self.rooms[server]
                continue
            for name, player in list(room["players"].items()):
                if now - player["seen"] > 3:
                    del room["players"][name]
            for key, target in list(room["targets"].items()):
                if now > target["deadline"] + 0.25 and not target["settled"]:
                    # This is geometric evidence, NOT server-confirmed collection.
                    # Only infer a turn when a fresh sample places the assignee inside.
                    player = room["players"].get(target.get("assigned"))
                    if player and not player["busy"] and abs(player["sample"] - target["deadline"]) < 0.35:
                        if distance(player["pos"], target["pos"]) <= 9 and abs(player["pos"][1] - target["pos"][1]) <= 7:
                            room["turns"][target["owner"]] = (target["assigned"], now)
                    target["settled"] = True
                if now > target["deadline"] + 2:
                    del room["targets"][key]
            for owner, (_, stamp) in list(room["turns"].items()):
                if now - stamp > 30:
                    del room["turns"][owner]

    @staticmethod
    def roster(data):
        main = str(data.get("main", "")).lower()
        alts = [str(n).lower() for n in data.get("alts", [])]
        catchers = [str(n).lower() for n in data.get("catchers", [])]
        names = [main] + alts + catchers
        if len(alts) != 2 or len(catchers) > 3 or len(set(names)) != len(names) or not all(NAME.fullmatch(n) for n in names):
            raise ValueError("Pick one main, two different spawning alts, and up to three outside catchers")
        return {"main": main, "alts": alts, "catchers": catchers, "field": str(data.get("field", ""))[:80]}

    def sync(self, body):
        now = self.clock()
        name = str(body.get("username", "")).lower()
        server = str(body.get("server", ""))
        session = str(body.get("session", ""))[:80]
        seq = int(body.get("seq", 0))
        if not NAME.fullmatch(name) or not 1 <= len(server) <= 128 or not session or seq < 1:
            raise ValueError("Invalid account or server identity")
        pos = point(body.get("pos"))
        speed = float(body.get("speed", 0))
        if not math.isfinite(speed):
            raise ValueError("Invalid speed")
        roster = self.roster(body["roster"])
        members = [roster["main"]] + roster["alts"] + roster["catchers"]
        if name not in members:
            raise ValueError("This account is not in the team")
        observations = body.get("targets") or []
        if not isinstance(observations, list) or len(observations) > 32:
            raise ValueError("Too many target observations")
        # Validate before touching shared state.
        parsed = []
        for item in observations:
            owner = str(item.get("owner", "")).lower()
            ttl = float(item.get("ttl", 0))
            key = str(item.get("key", ""))
            pts = float(item.get("points", 0))
            if owner not in members or not key or len(key) > 200 or not math.isfinite(ttl) or not math.isfinite(pts):
                continue
            if 0 < ttl <= 12:
                parsed.append((key, owner, point(item["pos"]), ttl, pts, str(item.get("field", ""))[:80]))
        with self.lock:
            self.prune(now)
            if server not in self.rooms:
                if len(self.rooms) >= 8:
                    raise ValueError("Too many active servers")
                self.rooms[server] = {"seen": now, "players": {}, "targets": {}, "turns": {}, "roster": roster}
            room = self.rooms[server]
            if name == roster["main"]:
                if room["roster"] != roster:
                    room["targets"].clear()
                    room["turns"].clear()
                    room["players"].clear()
                room["roster"] = roster
            elif room["roster"] != roster:
                return {"ok": False, "message": "Team settings differ; copy the same team code to every account"}
            room["seen"] = now
            previous = room["players"].get(name)
            if previous and previous["session"] != session and now - previous["seen"] < 1.5:
                return {"ok": False, "message": "Another instance is using this account"}
            if previous and previous["session"] == session and seq <= previous["seq"]:
                return {"ok": False, "message": "Old request ignored"}
            elapsed = max(0, min(float(body.get("sample_age", 0)), 2))
            room["players"][name] = {"seen": now, "sample": now - elapsed, "pos": pos,
                "speed": max(1, min(speed, 180)), "busy": body.get("busy") is not False,
                "session": session, "seq": seq}
            for key, owner, target_pos, ttl, pts, field in parsed:
                target = room["targets"].get(key)
                if target and target["deadline"] < now and now + ttl - target["deadline"] > 0.6:
                    target = None
                if not target:
                    # Replication timestamps can differ; match the same owner/point/landing.
                    target = next((t for t in room["targets"].values() if t["owner"] == owner
                        and t["points"] == pts and distance(t["pos"], target_pos) < 1
                        and abs(t["pos"][1] - target_pos[1]) < 2
                        and abs(t["deadline"] - (now + ttl)) < 0.6), None)
                if not target and len(room["targets"]) < 32:
                    target = {"key": key, "owner": owner, "pos": target_pos, "deadline": now + ttl,
                        "points": pts, "field": field, "assigned": None, "settled": False}
                    room["targets"][key] = target
                if target:
                    # Never extend deadlines on repeated reports.
                    target["deadline"] = min(target["deadline"], now + ttl)
            self.assign(room, now)
            jobs = []
            for target in room["targets"].values():
                if target.get("assigned") == name and now < target["deadline"] and not target["settled"]:
                    jobs.append({"key": target["key"], "pos": target["pos"], "owner": target["owner"],
                        "ttl": target["deadline"] - now, "lease": min(0.65, target["deadline"] - now)})
            return {"ok": True, "jobs": jobs[:1], "online": len(room["players"]),
                "message": "Assigned catch" if jobs else "Connected; waiting for a reachable combo"}

    def assign(self, room, now):
        roster = room["roster"]
        used = set()
        targets = sorted(room["targets"].values(), key=lambda t: (t["deadline"], t["key"]))
        for target in targets:
            remaining = target["deadline"] - now
            if remaining <= 0 or target["settled"]:
                continue
            eligible = {}
            for name, player in room["players"].items():
                if name in used or player["busy"] or now - player["seen"] > 0.65:
                    continue
                if name not in [roster["main"]] + roster["alts"] + roster["catchers"]:
                    continue
                if abs(player["pos"][1] - target["pos"][1]) > 12:
                    continue
                travel = max(0, distance(player["pos"], target["pos"]) - 5) / player["speed"]
                if travel + 0.2 < remaining:
                    eligible[name] = travel
            old = target.get("assigned")
            # Keep an assignment for this landing. No last-millisecond main/alt ping-pong.
            if old in eligible:
                used.add(old)
                continue
            if old and now < target.get("handoff_after", 0):
                used.add(old)
                continue
            target["assigned"] = None
            if old:
                # Wait out the old client's lease before another account is allowed to move.
                target["handoff_after"] = now + 0.75
                continue
            if now < target.get("handoff_after", 0):
                continue
            if not eligible:
                continue
            outside = bool(roster["field"] and target["field"] != roster["field"])
            owner = target["owner"]
            last = room["turns"].get(owner, (None, 0))[0]
            if outside and owner != roster["main"] and last != owner:
                priorities = [owner] + roster["catchers"] + [roster["main"]] + roster["alts"]
            elif outside:
                priorities = [roster["main"]] + roster["catchers"] + roster["alts"]
            elif owner == roster["main"]:
                priorities = [roster["main"]] + roster["alts"] + roster["catchers"]
            else:
                priorities = ([roster["main"], owner] if last == owner else [owner, roster["main"]]) + roster["alts"] + roster["catchers"]
            # Nearest catcher within a role, with deterministic name tie-breaks.
            def rank(name):
                tier = priorities.index(roster["catchers"][0]) if outside and name in roster["catchers"] else priorities.index(name)
                return tier, eligible[name], name
            chosen = min(eligible, key=rank)
            target["assigned"] = chosen
            used.add(chosen)


PAGE = r'''<!doctype html><meta charset="utf-8"><title>Atlas+ Coconut Team</title>
<style>body{font:16px system-ui;background:#101623;color:#ecf1ff;max-width:800px;margin:50px auto;padding:20px}textarea{width:100%;height:100px;background:#1c2638;color:white}button{padding:12px;margin:12px 0}small{color:#abb9d1}</style>
<h1>Atlas+ Coconut Team</h1><p>Leave the launcher running on this computer. Run Atlas+ on every account.</p>
<p>In the script, choose the main, two spawning alts and optional outside catchers. Paste this connection code into every account, then copy the team code from the main to the others.</p>
<textarea id="invite" readonly>Starting secure tunnel…</textarea><button onclick="navigator.clipboard.writeText(document.getElementById('invite').value)">Copy connection code</button>
<pre id="status"></pre><small>The temporary connection address changes when you restart the launcher. No Roblox passwords or cookies are used.</small>
<script>async function update(){try{let r=await fetch('/status'+location.search);let s=await r.json();document.getElementById('invite').value=s.invite||'Starting secure tunnel…';document.getElementById('status').textContent=s.message+'\n'+s.accounts.join('\n')}catch(e){document.getElementById('status').textContent='Launcher disconnected'}}setInterval(update,2000);update();</script>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log credentials or high-frequency request bodies.

    def send_json(self, status, value):
        data = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        # The setup page and secret are available only through the loopback Host.
        host = self.headers.get("Host", "")
        local = host == f"127.0.0.1:{self.server.server_port}" and "CF-Ray" not in self.headers
        path, _, query = self.path.partition("?")
        if not local or not hmac.compare_digest(query, "admin=" + self.server.admin):
            return self.send_json(404, {"error": "Not found"})
        if path == "/":
            data = PAGE.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif path == "/status":
            with self.server.coordinator.lock:
                self.server.coordinator.prune(time.monotonic())
                accounts = [f"{name}: {'busy' if p['busy'] else 'ready'}" for r in self.server.coordinator.rooms.values() for name, p in r["players"].items()]
            invite = json.dumps({"url": self.server.public_url, "key": self.server.key}) if self.server.public_url else ""
            self.send_json(200, {"invite": invite, "message": self.server.message, "accounts": accounts})
        else:
            self.send_json(404, {"error": "Not found"})

    def do_POST(self):
        self.connection.settimeout(5)
        if self.path != "/v1/sync":
            return self.send_json(404, {"error": "Not found"})
        if not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + self.server.key):
            return self.send_json(401, {"error": "Wrong connection code"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length <= 32768:
                raise ValueError("Request too large")
            body = json.loads(self.rfile.read(length))
            result = self.server.coordinator.sync(body)
            self.send_json(200, result)
        except (ValueError, TypeError, KeyError, OverflowError, AttributeError) as exc:
            self.send_json(400, {"error": str(exc)[:160]})


def download_tunnel():
    """Download official Cloudflare release and require GitHub's asset SHA-256."""
    target = ROOT / "runtime" / "cloudflared.exe"
    if target.exists():
        return target
    request = urllib.request.Request("https://api.github.com/repos/cloudflare/cloudflared/releases/latest", headers={"User-Agent": "AtlasPlus-Coordinator"})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    asset = next(a for a in release["assets"] if a["name"] == "cloudflared-windows-amd64.exe")
    digest = asset.get("digest", "")
    if not digest.startswith("sha256:"):
        raise RuntimeError("Official download has no checksum; install cloudflared.exe in runtime manually")
    target.parent.mkdir(exist_ok=True)
    temporary = target.with_suffix(".download")
    with urllib.request.urlopen(asset["browser_download_url"], timeout=60) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    if hashlib.sha256(temporary.read_bytes()).hexdigest() != digest[7:]:
        temporary.unlink()
        raise RuntimeError("Cloudflare download checksum mismatch")
    temporary.replace(target)
    return target


def child_lifetime(process):
    """Kill the tunnel if Windows closes the launcher, even without Python finally."""
    import ctypes
    from ctypes import wintypes
    if not hasattr(ctypes, "WinDLL"):
        return None
    class BASIC(ctypes.Structure):
        _fields_ = [("process_time", ctypes.c_int64), ("job_time", ctypes.c_int64),
            ("flags", wintypes.DWORD), ("min_working_set", ctypes.c_size_t),
            ("max_working_set", ctypes.c_size_t), ("active_processes", wintypes.DWORD),
            ("affinity", ctypes.c_size_t), ("priority", wintypes.DWORD), ("scheduling", wintypes.DWORD)]
    class IO(ctypes.Structure):
        _fields_ = [(n, ctypes.c_uint64) for n in ("read_ops", "write_ops", "other_ops", "read_bytes", "write_bytes", "other_bytes")]
    class EXTENDED(ctypes.Structure):
        _fields_ = [("basic", BASIC), ("io", IO), ("process_memory", ctypes.c_size_t),
            ("job_memory", ctypes.c_size_t), ("peak_process", ctypes.c_size_t), ("peak_job", ctypes.c_size_t)]
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel.CreateJobObjectW.restype = wintypes.HANDLE
    kernel.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.CreateJobObjectW(None, None)
    info = EXTENDED()
    info.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not handle or not kernel.SetInformationJobObject(handle, 9, ctypes.byref(info), ctypes.sizeof(info)):
        if handle:
            kernel.CloseHandle(handle)
        raise RuntimeError("Could not attach tunnel cleanup to launcher")
    if not kernel.AssignProcessToJobObject(handle, wintypes.HANDLE(int(process._handle))):
        kernel.CloseHandle(handle)
        raise RuntimeError("Could not attach tunnel cleanup to launcher")
    return lambda: kernel.CloseHandle(handle)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--local-only", action="store_true", help="Test without starting a tunnel")
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--port", type=int, default=18763)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    server.coordinator = Coordinator()
    server.key, server.admin = secrets.token_urlsafe(32), secrets.token_urlsafe(24)
    server.public_url = ""
    server.message = "Starting tunnel"
    tunnel = None
    close_job = None
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    local_url = f"http://127.0.0.1:{server.server_port}"
    try:
        if not args.local_only:
            server.message = "Downloading/checking the official Cloudflare tunnel helper"
            helper = download_tunnel()
            tunnel = subprocess.Popen([str(helper), "tunnel", "--no-autoupdate", "--url", local_url],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            close_job = child_lifetime(tunnel)
            def read_tunnel():
                for line in tunnel.stdout:
                    match = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", line)
                    if match:
                        server.public_url = match.group()
                        server.message = "Ready. Paste the connection code into Atlas+ on all computers."
                server.message = "Tunnel stopped. Restart the launcher and update the connection code."
                server.public_url = ""
            threading.Thread(target=read_tunnel, daemon=True).start()
        else:
            server.public_url = local_url
            server.message = "Local test mode"
        print("Atlas+ coordinator is running. Close this window to stop.")
        if not args.no_browser:
            webbrowser.open(local_url + "/?admin=" + server.admin)
        while True:
            time.sleep(1)
            with server.coordinator.lock:
                server.coordinator.prune(time.monotonic())
    except KeyboardInterrupt:
        pass
    finally:
        if tunnel:
            tunnel.terminate()
            try:
                tunnel.wait(timeout=5)
            except subprocess.TimeoutExpired:
                tunnel.kill()
            if tunnel.stdout:
                tunnel.stdout.close()
        if close_job:
            close_job()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
