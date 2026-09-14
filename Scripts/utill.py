import os, sys, subprocess, time, random, re, json, glob, select, configparser, shutil, hashlib
from pathlib import Path
from datetime import datetime
import datetime as dt
from urllib.parse import urlparse
from rapidfuzz import fuzz, process

INVALID = [(" &", ",")]
PLAYERS = ["Youtube Music", "Spotify", 'Youtube']
VALID_EXTS = (".png", ".svg", ".xpm")

## Paths
## Resolved from the environment. Override the config directory with
## QUICKSHELL_CONFIG_DIR if the shell lives somewhere other than the default.

HOME = Path(os.environ.get("HOME") or Path.home())
USERNAME = os.environ.get("USER") or os.environ.get("LOGNAME") or HOME.name

XDG_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or (HOME / ".config"))
CONFIG_DIR = Path(os.environ.get("QUICKSHELL_CONFIG_DIR") or (XDG_CONFIG / "quickshell"))

CONFIG_JSON = CONFIG_DIR / "config.json"
ICON_CACHE = CONFIG_DIR / ".icon-path-cache"
DDC_CACHE = CONFIG_DIR / ".ddc-cache"

ICON_ROOTS = [
    "/usr/share/icons",
    "/usr/share/pixmaps",
    "/usr/local/share/icons",
    str(HOME / ".local/share/icons"),
    "/var/lib/flatpak/exports/share/icons",
    str(HOME / ".local/share/flatpak/exports/share/icons"),
]
# ─────────────────────────────────────────────────────────────────────────────


def post(txt: str):
    print(str(txt))
    sys.stdout.flush()


class Utill():

    def get_now(self):
        return datetime.now()

    def blank(self, *args):
        print(f"Whoops this '{args[0]}' function does not exist")

    def call(self, function: str, *args):
        func = getattr(
            self,
            function,
            lambda *xtra, f=function: self.blank(f, *xtra)
        )
        if func.__callable:
            return func(*args)
        else:
            return "NO"

    def argfunc(func):
        def wrapper(*args, **kwargs):
            return func(*args, **kwargs)
        wrapper.__callable = True
        return wrapper

    # ── DATE / TIME ──────────────────────────────────────────────────────────

    @argfunc
    def format(self, format_txt: str, *args):
        return self.get_now().strftime(format_txt)

    # ── AUDIO ────────────────────────────────────────────────────────────────

    @argfunc
    def togglemic(self, *args):
        result = subprocess.run(['amixer', "set", "Capture", "toggle"], capture_output=True, text=True)
        mic_mute = "off"
        found_block = False
        for line in result.stdout.split('\n'):
            if "Capture" in line: found_block = True
            if found_block and '%' in line:
                mic_mute = line.split('[')[-1].split("]")[0].strip()
                break
        return mic_mute

    @argfunc
    def togglevol(self, *args):
        result = subprocess.run(['amixer', "set", "Master", "toggle"], capture_output=True, text=True)
        vol_mute = "off"
        found_block = False
        for line in result.stdout.split('\n'):
            if "Master" in line: found_block = True
            if found_block and '%' in line:
                vol_mute = line.split('[')[-1].split("]")[0].strip()
                break
        return vol_mute

    @argfunc
    def getaudio(self, *args):
        result = subprocess.run(['amixer'], capture_output=True, text=True)
        lines = result.stdout.split('\n')
        found_vol = found_mic = False
        found_vol_block = found_mic_block = False
        volume = volume_mute = mic_volume = mic_mute = ""
        for line in lines:
            if "Master" in line: found_vol_block = True
            if found_vol_block and '%' in line and not found_vol:
                volume = line.split('[', 1)[-1].split("]")[0].strip()
                volume_mute = line.split('[')[-1].split("]")[0].strip()
                found_vol = True
            if "Capture" in line: found_mic_block = True
            if found_mic_block and '%' in line and not found_mic:
                mic_mute = line.split('[')[-1].split("]")[0].strip()
                mic_volume = line.split('[', 1)[-1].split("]")[0].strip()
                found_mic = True
        return volume, volume_mute, mic_volume, mic_mute

    @argfunc
    def getaudiodevices(self, *args):
        result = subprocess.run(['wpctl', 'status'], capture_output=True, text=True)
        BAR = "│"
        in_audio = in_capture = False
        devices = ''
        dev_type = None

        def get_data(raw):
            raw = raw.replace(BAR, "").strip()
            if not raw: return None
            default = raw.startswith("*")
            parts = (raw[1:].strip() if default else raw).split(".", 1)
            if len(parts) < 2: return None
            return [parts[0].strip(), default, parts[1].split("[", 1)[0].strip()]

        for line in result.stdout.split("\n"):
            if "Audio" == line.strip(): in_audio = True; continue
            if in_audio:
                if "Sinks:" in line:   dev_type = "output"; in_capture = True; continue
                if "Sources:" in line: dev_type = "input";  in_capture = True; continue
                if in_capture:
                    data = get_data(line)
                    if data:
                        data.insert(1, dev_type)
                        devices += ','.join([str(v) for v in data]) + "|"
                    else:
                        in_capture = False

        return devices.rstrip("|")

    @argfunc
    def setaudiodevice(self, *args):
        return subprocess.run(['wpctl', 'set-default', args[0]], capture_output=True, text=True).stdout.strip()

    # ── NETWORK ──────────────────────────────────────────────────────────────


    @argfunc
    def getnetworkinfo(self, *args):
        """Returns full network info:
        interface|type|vpn|rx_bytes|tx_bytes|rx_speed|tx_speed
        type: wired, wireless, unknown
        vpn: connection name or "no"
        speeds in bytes/sec
        """
        import time

        # VPN device name patterns — tun/tap (OpenVPN), wg (WireGuard), pia
        VPN_DEV_PREFIXES = ("tun", "tap", "wg", "ppp", "pia", "proton", "nord")

        # Get all active connections
        result = subprocess.run(
            ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "con", "show", "--active"],
            capture_output=True, text=True
        )

        interface = "unknown"
        conn_type = "unknown"
        vpn       = "no"

        for line in result.stdout.splitlines():
            # nmcli uses : as separator but connection names can contain :
            # Split from right to get fixed trailing fields
            parts = line.rsplit(":", 3)
            if len(parts) < 4: continue
            name, typ, device, state = parts[0], parts[1], parts[2], parts[3]
            if state != "activated": continue

            typ_lower = typ.lower()
            dev_lower = device.lower()

            # Detect VPN by type or device name pattern
            is_vpn = (
                "vpn" in typ_lower
                or "wireguard" in typ_lower
                or any(dev_lower.startswith(p) for p in VPN_DEV_PREFIXES)
            )

            if is_vpn:
                vpn = name if name else device
                continue

            if "wireless" in typ_lower or "wifi" in typ_lower or "802-11" in typ_lower:
                interface = device or name
                conn_type = "wireless"
            elif "ethernet" in typ_lower or "802-3" in typ_lower:
                interface = device or name
                conn_type = "wired"
            elif conn_type == "unknown":
                interface = device or name
                conn_type = "external"

        # Also check /proc/net/dev for any tun/wg device even if nmcli missed it
        if vpn == "no":
            try:
                with open("/proc/net/dev", "r") as f:
                    for line in f:
                        dev = line.split(":")[0].strip()
                        if any(dev.startswith(p) for p in VPN_DEV_PREFIXES) and dev != "":
                            vpn = dev
                            break
            except Exception:
                pass

        # Get SSID if wireless
        if conn_type == "wireless":
            ssid_result = subprocess.run(
                ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
                capture_output=True, text=True
            )
            for line in ssid_result.stdout.splitlines():
                if line.startswith("yes:"):
                    ssid = line[4:].strip()
                    if ssid: interface = ssid
                    break

        # Get network speeds from /proc/net/dev
        def read_net_stats(iface):
            try:
                with open("/proc/net/dev", "r") as f:
                    for line in f:
                        if iface in line:
                            cols = line.split()
                            return int(cols[1]), int(cols[9])  # rx, tx bytes
            except Exception:
                pass
            return 0, 0

        # Find best active device for speed stats
        # Prefer the VPN tunnel device if active, else main interface
        dev_result = subprocess.run(
            ["nmcli", "-t", "-f", "DEVICE,STATE", "dev"],
            capture_output=True, text=True
        )
        active_dev = ""
        for line in dev_result.stdout.splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[1] == "connected" and parts[0] not in ("lo",):
                active_dev = parts[0]
                break

        rx1, tx1 = read_net_stats(active_dev)
        time.sleep(0.5)
        rx2, tx2 = read_net_stats(active_dev)

        rx_speed = max(0, (rx2 - rx1) * 2)
        tx_speed = max(0, (tx2 - tx1) * 2)

        return f"{interface}|{conn_type}|{vpn}|{rx2}|{tx2}|{rx_speed}|{tx_speed}"

    # ── FILESYSTEM UTILS ─────────────────────────────────────────────────────

    @argfunc
    def run(self, *args):
        return subprocess.run(list(args), capture_output=True, text=True).stdout

    @argfunc
    def findin(self, *args):
        func = args[0]
        lines, targets = [], []
        if func == "cmd":
            command, args = [], args[1:]
            for i, arg in enumerate(args):
                if arg == "/": targets = args[i+1:]; break
                command.append(arg)
            lines = subprocess.run(command, capture_output=True, text=True).stdout.split("\n")
        elif func == "file":
            targets = args[2:]
            with open(Path(args[1]), "r") as f: lines = f.readlines()
        for line in lines:
            if all(t in line for t in targets): return line

    @argfunc
    def replacein(self, *args):
        path = Path(args[0])
        data = ' '.join(args[1:]).split(" / ")
        filters, replacement = data[0].split(","), data[1]
        with open(path, "r") as f: lines = f.readlines()
        for i, line in enumerate(lines):
            if all(flt in line for flt in filters) and replacement != line:
                lines[i] = replacement
        with open(path, "w") as f:
            for line in lines: f.write(f"{line.strip()}\n")
        return ""

    @argfunc
    def randomfile(self, *args):
        files = list(Path(args[0]).iterdir())
        count = 1 if len(args) == 1 else int(args[1])
        choices = []
        while len(choices) < count:
            c = str(random.choice(files))
            if c not in choices: choices.append(c)
        return choices

    # ── MEDIA / MPRIS ────────────────────────────────────────────────────────

    def get_app_name(self, service):
        return service.replace("org.mpris.MediaPlayer2.", "").split(".instance")[0]

    def get_identity(self, service):
        try:
            return subprocess.check_output(
                ["qdbus", service, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Identity"],
                text=True
            ).strip()
        except subprocess.CalledProcessError:
            return ""

    def get_site_name(self, url):
        try: return urlparse(url).netloc.replace("www.", "")
        except: return ""

    @argfunc
    def getcurrentplaying(self, *args):
        try:
            services = [l.strip() for l in subprocess.check_output(["qdbus"], text=True).splitlines()
                        if "org.mpris.MediaPlayer2" in l]
        except subprocess.CalledProcessError:
            return "  ?    ?    ?    ?    ?    ?    ?  Nothing"

        for service in services:
            try:
                status = subprocess.check_output(
                    ["qdbus", service, "/org/mpris/MediaPlayer2",
                     "org.mpris.MediaPlayer2.Player.PlaybackStatus"], text=True
                ).strip()
                if status not in ["Playing", "Paused"]: continue

                metadata = subprocess.check_output(
                    ["qdbus", service, "/org/mpris/MediaPlayer2",
                     "org.mpris.MediaPlayer2.Player.Metadata"], text=True
                )
                data = {"title": "", "artist": "", "album": "", "length": "", "art": "", "url": ""}
                for line in metadata.splitlines():
                    line = line.strip()
                    if "xesam:title" in line:   data["title"]  = line.split(":", 2)[-1].strip()
                    elif "xesam:artist" in line: data["artist"] = line.split(":")[-1].strip()
                    elif "xesam:album" in line:  data["album"]  = line.split(":")[-1].strip()
                    elif "mpris:length" in line: data["length"] = line.split(":")[-1].strip()
                    elif "mpris:artUrl" in line: data["art"]    = line.split(":")[-1].strip()
                    elif "xesam:url" in line or "mpris:url" in line:
                        data["url"] = line.split("url:", 1)[-1].strip()

                app  = self.get_identity(service) or self.get_app_name(service)
                site = self.get_site_name(data.get("url", ""))
                app_display = site if site else (f"Browser ({app})" if app.lower() in ["chromium", "brave", "firefox"] else app)
                return f"{data['title']}  ?  {data['artist']}  ?  {data['album']}  ?  {data['length']}  ?  {data['art']}  ?  {data['url']}  ?  {app_display}  ?  {status}"
            except subprocess.CalledProcessError:
                continue

        return "  ?    ?    ?    ?    ?    ?    ?  Nothing"

    @argfunc
    def getcurrentplayingstatus(self, *args):
        try:
            services = [l.strip() for l in subprocess.check_output(["qdbus"], text=True).splitlines()
                        if "org.mpris.MediaPlayer2" in l]
        except subprocess.CalledProcessError:
            return "Nothing"
        for service in services:
            try:
                status = subprocess.check_output(
                    ["qdbus", service, "/org/mpris/MediaPlayer2",
                     "org.mpris.MediaPlayer2.Player.PlaybackStatus"], text=True
                ).strip()
                if status in ["Playing", "Paused", "Stopped"]: return status
            except subprocess.CalledProcessError:
                continue
        return "Nothing"

    # ── THEME ────────────────────────────────────────────────────────────────


    # ── HYPRLAND / WINDOWS ───────────────────────────────────────────────────



    ## ── HYPRLAND CONFIG ──────────────────────────────────────────────────────

    @argfunc
    def hyprconfig(self, *args):
        ## Reports what the user's own Hyprland config already says about
        ## monitors, so the shell can show where it is being overridden rather
        ## than silently fighting a line the user forgot about.
        base = Path(os.environ.get("HYPRLAND_CONFIG_DIR")
                    or (XDG_CONFIG / "hypr"))

        result = {"dir": str(base), "files": [], "entries": []}
        if not base.is_dir():
            return json.dumps(result)

        paths = []
        for pattern in ("*.lua", "*.conf"):
            paths.extend(sorted(base.rglob(pattern)))

        for path in paths:
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue

            result["files"].append(str(path))
            lines = text.split("\n")
            index = 0

            while index < len(lines):
                raw = lines[index]
                stripped = raw.strip()

                if stripped.startswith("--") or stripped.startswith("#"):
                    index += 1
                    continue

                entry = None

                if "hl.monitor" in stripped or "hl.dsp.monitor" in stripped:
                    ## A Lua block can span many lines, so read until the
                    ## parentheses balance again
                    block = []
                    depth = 0
                    cursor = index
                    while cursor < len(lines) and cursor < index + 30:
                        block.append(lines[cursor])
                        depth += lines[cursor].count("(") - lines[cursor].count(")")
                        if depth <= 0 and len(block) > 0:
                            break
                        cursor += 1

                    joined = " ".join(l.strip() for l in block)
                    name = ""
                    match = re.search(r'name\s*=\s*"([^"]+)"', joined)
                    if not match:
                        match = re.search(r'hl\.monitor\s*\(\s*"([^"]+)"', joined)
                    if match:
                        name = match.group(1)

                    entry = {"kind": "lua", "name": name,
                             "raw": joined[:400], "line": index + 1}
                    index = cursor

                elif re.match(r'monitor\s*=', stripped):
                    value = stripped.split("=", 1)[1].strip()
                    entry = {"kind": "hyprlang",
                             "name": value.split(",")[0].strip(),
                             "raw": stripped[:400], "line": index + 1}

                if entry:
                    entry["file"] = str(path)
                    result["entries"].append(entry)

                index += 1

        return json.dumps(result)

    ## ── HYPRLAND LUA CONFIG ──────────────────────────────────────────────────
    ## Surgical edits only. Everything outside the field being changed is left
    ## byte for byte, including comments, spacing, and keys the shell does not
    ## know about such as bitdepth. Every write takes a timestamped backup.

    LUA_STRING_KEYS = {"output", "mode", "position", "scale"}

    def lua_files(self):
        base = Path(os.environ.get("XDG_CONFIG_HOME") or (HOME / ".config")) / "hypr"
        if not base.exists():
            return []

        ## Skipped by name, because a copy of the config sitting in the same
        ## folder is still a .lua file and every rule in it showed up twice
        skip = ("bak", "backup", "old", "orig", "copy", "save", "disabled")

        chosen = {}
        for path in sorted(base.rglob("*.lua")):
            if not path.is_file():
                continue

            lowered = path.name.lower()
            if lowered.endswith("~"):
                continue
            if any(word in lowered for word in skip):
                continue
            if any(part.lower() in skip for part in path.parts):
                continue

            try:
                resolved = str(path.resolve())
            except Exception:
                resolved = str(path)
            if resolved in chosen:
                continue

            ## Identical content by a different name is a copy too
            try:
                digest = hashlib.sha1(path.read_bytes()).hexdigest()
            except Exception:
                digest = resolved
            if digest in chosen:
                continue

            chosen[resolved] = path
            chosen[digest] = path

        seen = set()
        out = []
        for key in sorted(chosen):
            path = chosen[key]
            if str(path) in seen:
                continue
            seen.add(str(path))
            out.append(path)
        return out

    def lua_blocks(self, text, call="hl.monitor"):
        blocks = []
        for m in re.finditer(re.escape(call) + r"\s*\(\s*\{", text):
            depth = 0
            i = m.end() - 1
            while i < len(text):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            if depth != 0:
                continue
            blocks.append({
                "start": m.start(),
                "end": i,
                "inner_start": m.end(),
                "inner_end": i,
                "inner": text[m.end():i],
            })
        return blocks

    def lua_fields(self, inner):
        fields = {}
        pattern = r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|[^,\n}]+)'
        for fm in re.finditer(pattern, inner):
            fields[fm.group(1)] = {
                "raw": fm.group(2).strip().rstrip(",").strip(),
                "span": fm.span(2),
            }
        return fields

    def lua_unquote(self, raw):
        if raw[:1] in ("'", '"') and raw[-1:] == raw[:1]:
            return raw[1:-1]
        return raw

    def lua_value(self, key, value, previous_raw=None):
        if previous_raw is not None:
            quoted = previous_raw[:1] in ("'", '"')
        else:
            quoted = key in Utill.LUA_STRING_KEYS
        if quoted:
            return '"%s"' % str(value).replace('"', '\\"')
        if isinstance(value, bool):
            return "true" if value else "false"
        return str(value)

    def lua_strip(self, text):
        ## Brackets inside strings and comments are not structure. Counting them
        ## made a perfectly valid config look unbalanced, because a single "("
        ## in a comment or an exec_cmd string is enough to skew the totals.
        out = []
        i = 0
        n = len(text)
        while i < n:
            ch = text[i]

            if ch == "-" and text[i:i + 2] == "--":
                if text[i:i + 4] == "--[[":
                    close = text.find("]]", i + 4)
                    i = n if close == -1 else close + 2
                else:
                    close = text.find("\n", i)
                    i = n if close == -1 else close
                continue

            if text[i:i + 2] == "[[":
                close = text.find("]]", i + 2)
                i = n if close == -1 else close + 2
                continue

            if ch in ("'", '"'):
                quote = ch
                i += 1
                while i < n:
                    if text[i] == "\\":
                        i += 2
                        continue
                    if text[i] == quote:
                        i += 1
                        break
                    i += 1
                continue

            out.append(ch)
            i += 1

        return "".join(out)

    def lua_balance(self, text):
        stripped = self.lua_strip(text)
        return (stripped.count("{") - stripped.count("}"),
                stripped.count("(") - stripped.count(")"))

    def lua_commit(self, path, new_text):
        ## Compared against the original rather than demanding absolute balance,
        ## so an edit is judged on what it changed, not on the file it inherited
        before = self.lua_balance(path.read_text())
        after = self.lua_balance(new_text)

        if before != after:
            return ("error:refused, edit changed bracket balance "
                    "(braces %d->%d, parens %d->%d)"
                    % (before[0], after[0], before[1], after[1]))

        backup = path.with_suffix(path.suffix + ".bak-%d" % int(time.time()))
        shutil.copy2(str(path), str(backup))
        path.write_text(new_text)

        ## Every drag release writes, so these accumulate quickly
        try:
            existing = sorted(path.parent.glob(path.name + ".bak-*"))
            for stale in existing[:-5]:
                stale.unlink()
        except Exception:
            pass

        return "ok:" + str(backup)

    ## ── CLOCK ────────────────────────────────────────────────────────────────
    ## Alarms, timers and how long applications have been open. Tracking totals
    ## are written incrementally rather than at exit, so a crash, an update or a
    ## reboot costs at most one tick.

    def clock_path(self):
        return self.state_path("clock.json")

    def clock_load(self):
        path = self.clock_path()
        if not path.exists():
            return {"alarms": [], "timers": [], "tracking": {}, "reminders": []}
        try:
            data = json.loads(path.read_text(errors="replace"))
        except Exception:
            return {"alarms": [], "timers": [], "tracking": {}, "reminders": []}

        data.setdefault("alarms", [])
        data.setdefault("timers", [])
        data.setdefault("tracking", {})
        data.setdefault("reminders", [])
        return data

    def clock_save(self, data):
        path = self.clock_path()

        ## Written beside and moved into place, so a kill mid write cannot
        ## leave a half a file behind
        temp = path.with_suffix(".json.tmp")
        temp.write_text(json.dumps(data, indent=2))
        temp.replace(path)
        try:
            path.chmod(0o600)
        except Exception:
            pass
        return True

    ## ── Alarms ───────────────────────────────────────────────────────────────

    @argfunc
    def alarms(self, *args):
        data = self.clock_load()
        rows = []
        for alarm in data.get("alarms", []):
            rows.append("\x1f".join([
                str(alarm.get("id", "")),
                str(alarm.get("label", "")),
                str(alarm.get("time", "")),
                ",".join(str(d) for d in alarm.get("days", [])),
                "1" if alarm.get("enabled", True) else "0",
                "1" if alarm.get("popup", False) else "0",
            ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def alarmadd(self, *args):
        ## --alarmadd <label> <time> [days] [popup]
        if len(args) < 2:
            return "error:label and time required"

        data = self.clock_load()
        days = []
        if len(args) > 2 and args[2]:
            for piece in args[2].split(","):
                if piece.strip().isdigit():
                    days.append(int(piece.strip()))

        entry = {
            "id": "alarm-%d" % int(time.time() * 1000),
            "label": args[0],
            "time": args[1],
            "days": days,
            "enabled": True,
            "popup": len(args) > 3 and args[3] == "1",
        }
        data["alarms"].append(entry)
        self.clock_save(data)
        return "ok:" + entry["id"]

    @argfunc
    def alarmset(self, *args):
        ## --alarmset <id> <field> <value>
        if len(args) < 3:
            return "error:id, field and value required"

        data = self.clock_load()
        for alarm in data.get("alarms", []):
            if str(alarm.get("id")) != args[0]:
                continue
            if args[1] in ("enabled", "popup"):
                alarm[args[1]] = args[2] == "1"
            elif args[1] == "days":
                alarm["days"] = [int(p) for p in args[2].split(",") if p.strip().isdigit()]
            else:
                alarm[args[1]] = args[2]
            self.clock_save(data)
            return "ok"
        return "error:not found"

    @argfunc
    def alarmdelete(self, *args):
        if not args:
            return "error:no id"
        data = self.clock_load()
        data["alarms"] = [a for a in data["alarms"] if str(a.get("id")) != args[0]]
        self.clock_save(data)
        return "ok"

    ## ── Timers ───────────────────────────────────────────────────────────────

    @argfunc
    def timers(self, *args):
        data = self.clock_load()
        rows = []
        for timer in data.get("timers", []):
            rows.append("\x1f".join([
                str(timer.get("id", "")),
                str(timer.get("label", "")),
                str(timer.get("seconds", 0)),
                "1" if timer.get("popup", False) else "0",
            ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def timeradd(self, *args):
        ## --timeradd <label> <seconds> [popup]
        if len(args) < 2:
            return "error:label and seconds required"

        data = self.clock_load()
        entry = {
            "id": "timer-%d" % int(time.time() * 1000),
            "label": args[0],
            "seconds": int(args[1]) if str(args[1]).isdigit() else 60,
            "popup": len(args) > 2 and args[2] == "1",
        }
        data["timers"].append(entry)
        self.clock_save(data)
        return "ok:" + entry["id"]

    @argfunc
    def timerdelete(self, *args):
        if not args:
            return "error:no id"
        data = self.clock_load()
        data["timers"] = [t for t in data["timers"] if str(t.get("id")) != args[0]]
        self.clock_save(data)
        return "ok"

    ## ── Reminders ────────────────────────────────────────────────────────────
    ## Tied to an application, optionally narrowed to windows whose title
    ## contains a fragment — so "the browser" and "that one document" are both
    ## expressible without inventing a rule language.

    @argfunc
    def reminders(self, *args):
        data = self.clock_load()
        rows = []
        for entry in data.get("reminders", []):
            rows.append("\x1f".join([
                str(entry.get("id", "")),
                str(entry.get("label", "")),
                str(entry.get("appClass", "")),
                str(entry.get("match", "")),
                str(entry.get("seconds", 0)),
                "1" if entry.get("popup", False) else "0",
                "1" if entry.get("auto", True) else "0",
            ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def reminderadd(self, *args):
        ## --reminderadd <label> <appClass> <match> <seconds> [popup] [auto]
        if len(args) < 4:
            return "error:label, class and duration required"

        data = self.clock_load()
        entry = {
            "id": "remind-%d" % int(time.time() * 1000),
            "label": args[0],
            "appClass": args[1],
            "match": args[2],
            "seconds": int(args[3]) if str(args[3]).isdigit() else 3600,
            "popup": len(args) > 4 and args[4] == "1",
            "auto": len(args) < 6 or args[5] == "1",
        }
        data["reminders"].append(entry)
        self.clock_save(data)
        return "ok:" + entry["id"]

    @argfunc
    def reminderset(self, *args):
        ## --reminderset <id> <field> <value>
        if len(args) < 3:
            return "error:id, field and value required"

        data = self.clock_load()
        for entry in data.get("reminders", []):
            if str(entry.get("id")) != args[0]:
                continue
            if args[1] in ("popup", "auto"):
                entry[args[1]] = args[2] == "1"
            elif args[1] == "seconds":
                entry["seconds"] = int(args[2]) if str(args[2]).isdigit() else 3600
            else:
                entry[args[1]] = args[2]
            self.clock_save(data)
            return "ok"
        return "error:not found"

    @argfunc
    def reminderdelete(self, *args):
        if not args:
            return "error:no id"
        data = self.clock_load()
        data["reminders"] = [r for r in data["reminders"]
                             if str(r.get("id")) != args[0]]
        self.clock_save(data)
        return "ok"

    ## ── Application tracking ─────────────────────────────────────────────────
    ## Lifetime totals per window class. The shell itself is never counted.

    TRACK_IGNORE = {"quickshell", "qs"}

    @argfunc
    def tracking(self, *args):
        data = self.clock_load()
        rows = []
        for name, entry in sorted(data.get("tracking", {}).items(),
                                  key=lambda kv: -kv[1].get("total", 0)):
            rows.append("\x1f".join([
                name,
                str(int(entry.get("total", 0))),
                str(int(entry.get("sessions", 0))),
                str(entry.get("reminder", "")),
                "1" if entry.get("popup", False) else "0",
                str(int(entry.get("lastSeen", 0))),
            ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def tracktick(self, *args):
        ## --tracktick <seconds> <class> [class...]
        if len(args) < 2:
            return "ok"

        try:
            step = int(args[0])
        except Exception:
            return "error:bad step"

        data = self.clock_load()
        stamp = int(time.time())

        for name in args[1:]:
            key = str(name).strip()
            if not key or key.lower() in Utill.TRACK_IGNORE:
                continue

            entry = data["tracking"].setdefault(
                key, {"total": 0, "sessions": 0, "lastSeen": 0})
            entry["total"] = int(entry.get("total", 0)) + step
            entry["lastSeen"] = stamp

        self.clock_save(data)
        return "ok"

    @argfunc
    def tracksession(self, *args):
        ## --tracksession <class> — a fresh launch, not a continuation
        if not args:
            return "error:no class"
        key = str(args[0]).strip()
        if not key or key.lower() in Utill.TRACK_IGNORE:
            return "ok"

        data = self.clock_load()
        entry = data["tracking"].setdefault(
            key, {"total": 0, "sessions": 0, "lastSeen": 0})
        entry["sessions"] = int(entry.get("sessions", 0)) + 1
        entry["lastSeen"] = int(time.time())
        self.clock_save(data)
        return "ok"

    @argfunc
    def trackset(self, *args):
        ## --trackset <class> <reminderMinutes> <popup>
        if len(args) < 2:
            return "error:class and value required"

        data = self.clock_load()
        entry = data["tracking"].setdefault(
            args[0], {"total": 0, "sessions": 0, "lastSeen": 0})
        entry["reminder"] = args[1]
        entry["popup"] = len(args) > 2 and args[2] == "1"
        self.clock_save(data)
        return "ok"

    @argfunc
    def trackreset(self, *args):
        if not args:
            return "error:no class"
        data = self.clock_load()
        data["tracking"].pop(args[0], None)
        self.clock_save(data)
        return "ok"

    ## ── CALENDAR ─────────────────────────────────────────────────────────────
    ## Local events and subscribed feeds are kept apart in the store. A failed
    ## or emptied sync can only ever clear its own cache, never anything typed
    ## by hand.

    ## ── Private state ────────────────────────────────────────────────────────
    ## Calendar feeds carry secret ical urls and the clock file records what has
    ## been open and for how long. Neither belongs in .config, which people copy
    ## into dotfile repositories — this lives under the data directory instead.

    def state_dir(self):
        base = Path(os.environ.get("XDG_DATA_HOME") or (HOME / ".local/share"))
        path = base / "quickshell"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def state_path(self, name):
        path = self.state_dir() / name

        ## Anything left in the old location is moved once, so an existing
        ## install keeps its data and stops leaking it
        if not path.exists():
            legacy = (Path(os.environ.get("XDG_CONFIG_HOME") or (HOME / ".config"))
                      / "quickshell" / name)
            if legacy.exists():
                try:
                    shutil.move(str(legacy), str(path))
                    path.chmod(0o600)
                except Exception:
                    pass

        return path

    def cal_path(self):
        return self.state_path("calendar.json")

    def cal_load(self):
        path = self.cal_path()
        if not path.exists():
            return {"events": [], "subscriptions": [], "synced": {}}
        try:
            data = json.loads(path.read_text(errors="replace"))
        except Exception:
            return {"events": [], "subscriptions": [], "synced": {}}

        data.setdefault("events", [])
        data.setdefault("subscriptions", [])
        data.setdefault("synced", {})
        return data

    def cal_save(self, data):
        path = self.cal_path()

        if path.exists():
            backup = path.with_suffix(".json.bak")
            try:
                shutil.copy2(str(path), str(backup))
            except Exception:
                pass

        path.write_text(json.dumps(data, indent=2))
        try:
            path.chmod(0o600)
        except Exception:
            pass
        return True

    ## ── iCal parsing ─────────────────────────────────────────────────────────

    def ical_unfold(self, text):
        ## Continuation lines begin with a space or tab and belong to the line
        ## before them
        out = []
        for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
            if raw[:1] in (" ", "\t") and out:
                out[-1] += raw[1:]
            else:
                out.append(raw)
        return out

    def ical_unescape(self, value):
        return (value.replace("\\n", "\n").replace("\\N", "\n")
                     .replace("\\,", ",").replace("\\;", ";")
                     .replace("\\\\", "\\"))

    def ical_split(self, line):
        ## DTSTART;TZID=America/Chicago:20260804T143000
        ##   -> ("DTSTART", {"TZID": "..."}, "20260804T143000")
        head, _, value = line.partition(":")
        parts = head.split(";")
        name = parts[0].upper()

        params = {}
        for chunk in parts[1:]:
            key, _, val = chunk.partition("=")
            params[key.upper()] = val.strip('"')

        return name, params, value

    def ical_stamp(self, value, params):
        ## Returns (date, time) as YYYY-MM-DD and HH:MM, time empty for all day
        value = value.strip()
        if not value:
            return "", ""

        if params.get("VALUE", "").upper() == "DATE" or len(value) == 8:
            return "%s-%s-%s" % (value[0:4], value[4:6], value[6:8]), ""

        if "T" not in value:
            return "", ""

        date_part, _, time_part = value.partition("T")
        if len(date_part) != 8:
            return "", ""

        stamp = "%s-%s-%s" % (date_part[0:4], date_part[4:6], date_part[6:8])
        clock = "%s:%s" % (time_part[0:2], time_part[2:4])

        ## A trailing Z is UTC; shift into local time
        if time_part.endswith("Z"):
            try:
                moment = dt.datetime(
                    int(date_part[0:4]), int(date_part[4:6]), int(date_part[6:8]),
                    int(time_part[0:2]), int(time_part[2:4]),
                    tzinfo=dt.timezone.utc).astimezone()
                stamp = moment.strftime("%Y-%m-%d")
                clock = moment.strftime("%H:%M")
            except Exception:
                pass

        return stamp, clock

    def ical_rrule(self, value):
        out = {}
        for chunk in value.split(";"):
            key, _, val = chunk.partition("=")
            if key:
                out[key.upper()] = val
        return out

    def ical_events(self, text):
        events = []
        current = None

        for line in self.ical_unfold(text):
            stripped = line.strip()
            if stripped == "BEGIN:VEVENT":
                current = {}
                continue
            if stripped == "END:VEVENT":
                if current is not None:
                    events.append(current)
                current = None
                continue
            if current is None or ":" not in stripped:
                continue

            name, params, value = self.ical_split(stripped)
            if name in ("EXDATE", "RDATE"):
                current.setdefault(name, []).append((params, value))
            else:
                current[name] = (params, value)

        return events

    ## ── Recurrence ───────────────────────────────────────────────────────────
    ## Enough of RRULE to cover what real calendars emit: FREQ with INTERVAL,
    ## COUNT or UNTIL, and BYDAY for weekly rules. Anything stranger falls back
    ## to the single starting occurrence rather than guessing.

    WEEKDAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}

    def cal_expand(self, start_date, rule, window_start, window_end, exdates=None):
        try:
            first = dt.date.fromisoformat(start_date)
        except Exception:
            return []

        if not rule:
            return [start_date] if window_start <= start_date <= window_end else []

        exdates = set(exdates or [])
        freq = rule.get("FREQ", "").upper()
        interval = max(1, int(rule.get("INTERVAL", "1") or 1))
        count = int(rule["COUNT"]) if rule.get("COUNT", "").isdigit() else None

        until = None
        if rule.get("UNTIL"):
            raw = rule["UNTIL"][:8]
            try:
                until = dt.date(int(raw[0:4]), int(raw[4:6]), int(raw[6:8]))
            except Exception:
                until = None

        stop = dt.date.fromisoformat(window_end)
        if until and until < stop:
            stop = until

        days = []
        if freq == "WEEKLY" and rule.get("BYDAY"):
            for token in rule["BYDAY"].split(","):
                token = token.strip()[-2:].upper()
                if token in Utill.WEEKDAYS:
                    days.append(Utill.WEEKDAYS[token])

        out = []
        produced = 0
        cursor = first
        steps = 0
        guard = 0

        while cursor <= stop and guard < 2000:
            guard += 1

            if freq == "WEEKLY" and days:
                ## Every matching weekday inside this interval's week
                monday = cursor - dt.timedelta(days=cursor.weekday())
                for offset in sorted(days):
                    moment = monday + dt.timedelta(days=offset)
                    if moment < first or moment > stop:
                        continue
                    stamp = moment.isoformat()
                    if stamp in exdates:
                        continue
                    produced += 1
                    if count is not None and produced > count:
                        return out
                    if stamp >= window_start:
                        out.append(stamp)
                cursor = cursor + dt.timedelta(weeks=interval)
                continue

            stamp = cursor.isoformat()
            if stamp not in exdates:
                produced += 1
                if count is not None and produced > count:
                    return out
                if stamp >= window_start:
                    out.append(stamp)

            if freq == "DAILY":
                cursor = cursor + dt.timedelta(days=interval)
            elif freq == "WEEKLY":
                cursor = cursor + dt.timedelta(weeks=interval)
            elif freq in ("MONTHLY", "YEARLY"):
                ## Measured from the original day, not from the last clamped
                ## one — advancing from the clamp made the 31st drift to the
                ## 28th permanently after a February
                steps += 1
                months = interval * steps * (12 if freq == "YEARLY" else 1)
                month = first.month - 1 + months
                year = first.year + month // 12
                month = month % 12 + 1
                day = min(first.day, self.cal_month_length(year, month))
                cursor = dt.date(year, month, day)
            else:
                break

        return out

    def cal_month_length(self, year, month):
        if month == 12:
            nxt = dt.date(year + 1, 1, 1)
        else:
            nxt = dt.date(year, month + 1, 1)
        return (nxt - dt.timedelta(days=1)).day

    ## ── Subscriptions ────────────────────────────────────────────────────────

    def cal_fetch_url(self, url):
        text = str(url).strip()
        if text.startswith("webcal://"):
            text = "https://" + text[len("webcal://"):]

        ## Google's cid link sits directly under the iCal address in its own
        ## settings, so it is the likeliest wrong thing to paste — and it
        ## fetches an HTML page perfectly, which would look like a clean sync of
        ## nothing. The parameter is the calendar's address in base64, so the
        ## conversion is exact rather than a guess.
        import base64, urllib.parse
        found = re.search(
            r"calendar\.google\.com/calendar/[^?]*\?.*\bcid=([^&]+)", text, re.I)
        if found:
            raw = urllib.parse.unquote(found.group(1))
            try:
                address = base64.b64decode(
                    raw + "=" * (-len(raw) % 4)).decode("utf-8")
                if "@" in address:
                    return ("https://calendar.google.com/calendar/ical/"
                            + urllib.parse.quote(address, safe="")
                            + "/public/basic.ics")
            except Exception:
                pass

        return text

    def cal_sync_one(self, sub):
        url = self.cal_fetch_url(sub.get("url", ""))
        if not url:
            return None, "no url"

        ## curl first, then urllib, so a machine without curl still syncs. The
        ## real reason is reported rather than a bare "fetch failed", which said
        ## nothing about whether it was the network, the url or a missing tool.
        text = ""
        reason = ""

        try:
            command = ["curl", "-fsSL", "--max-time", "45",
                       "-H", "User-Agent: Mozilla/5.0"]
            if sub.get("user"):
                command += ["-u", "%s:%s" % (sub.get("user"), sub.get("password", ""))]
            command.append(url)

            result = subprocess.run(command, capture_output=True,
                                    text=True, timeout=60)
            if result.returncode == 0:
                text = result.stdout
            else:
                reason = (result.stderr or "").strip().split("\n")[-1]
                if not reason:
                    reason = "curl exit %d" % result.returncode
        except FileNotFoundError:
            reason = "curl not installed"
        except Exception as error:
            reason = str(error)

        if not text.strip():
            try:
                import urllib.request
                request = urllib.request.Request(
                    url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(request, timeout=45) as response:
                    text = response.read().decode("utf-8", "replace")
                reason = ""
            except Exception as error:
                if not reason:
                    reason = str(error)

        if not text.strip():
            ## 401 and 403 mean the address itself is fine but it is not public
            if "401" in reason:
                reason = ("needs credentials — use the private or secret "
                          "address, or add a username and password")
            elif "403" in reason:
                reason = "refused — the calendar is not shared publicly"
            return None, reason or "empty response"

        if "BEGIN:VCALENDAR" not in text and "BEGIN:VEVENT" not in text:
            return None, "not an ical feed"

        result = type("Result", (), {"stdout": text, "returncode": 0})()

        raw = self.ical_events(result.stdout)

        ## A recurring series and its edited instances arrive as separate
        ## VEVENTs sharing a UID. The overrides are applied over the series
        ## rather than listed alongside it.
        overrides = {}
        for event in raw:
            if "RECURRENCE-ID" not in event:
                continue
            uid = event.get("UID", ({}, ""))[1]
            params, value = event["RECURRENCE-ID"]
            date, _ = self.ical_stamp(value, params)
            overrides[(uid, date)] = event

        out = []
        for event in raw:
            if "RECURRENCE-ID" in event:
                continue

            summary = self.ical_unescape(event.get("SUMMARY", ({}, ""))[1]).strip()
            if not summary:
                continue

            params, value = event.get("DTSTART", ({}, ""))
            date, clock = self.ical_stamp(value, params)
            if not date:
                continue

            end_clock = ""
            if "DTEND" in event:
                end_params, end_value = event["DTEND"]
                _, end_clock = self.ical_stamp(end_value, end_params)

            rule = None
            if "RRULE" in event:
                rule = self.ical_rrule(event["RRULE"][1])

            exdates = []
            for ex_params, ex_value in event.get("EXDATE", []):
                for piece in ex_value.split(","):
                    ex_date, _ = self.ical_stamp(piece, ex_params)
                    if ex_date:
                        exdates.append(ex_date)

            ## An edited instance replaces its original date. Without this the
            ## series still produced that day and the moved copy was added
            ## beside it, so the event appeared twice.
            uid = event.get("UID", ({}, ""))[1]
            for (other_uid, moved_from) in overrides:
                if other_uid == uid and moved_from not in exdates:
                    exdates.append(moved_from)

            out.append({
                "uid": uid,
                "title": summary,
                "date": date,
                "time": clock,
                "endTime": end_clock,
                "notes": self.ical_unescape(
                    event.get("DESCRIPTION", ({}, ""))[1]).strip()[:400],
                "location": self.ical_unescape(
                    event.get("LOCATION", ({}, ""))[1]).strip(),
                "rrule": rule,
                "exdates": exdates,
                "source": sub.get("key", ""),
            })

        ## Overrides become plain one-off entries on their own date
        for (uid, date), event in overrides.items():
            params, value = event.get("DTSTART", ({}, ""))
            moved, clock = self.ical_stamp(value, params)
            if not moved:
                continue
            out.append({
                "uid": uid + "@" + date,
                "title": self.ical_unescape(event.get("SUMMARY", ({}, ""))[1]).strip(),
                "date": moved,
                "time": clock,
                "endTime": "",
                "notes": "",
                "location": "",
                "rrule": None,
                "exdates": [],
                "source": sub.get("key", ""),
                "overrides": date,
            })

        return out, ""

    @argfunc
    def calsync(self, *args):
        data = self.cal_load()
        subs = data.get("subscriptions", [])
        wanted = args[0] if args else ""

        results = []
        for sub in subs:
            if wanted and sub.get("key") != wanted:
                continue
            if sub.get("enabled") is False:
                continue

            events, error = self.cal_sync_one(sub)
            if events is None:
                ## The cache is left alone — a failed fetch must not empty a
                ## calendar that was working a moment ago
                results.append("%s\x1f0\x1f%s" % (sub.get("key", ""), error))
                continue

            data["synced"][sub.get("key", "")] = events
            results.append("%s\x1f%d\x1f" % (sub.get("key", ""), len(events)))

        self.cal_save(data)
        return "\x1e".join(results) if results else "none"

    ## ── Store operations ─────────────────────────────────────────────────────

    @argfunc
    def calevents(self, *args):
        ## --calevents <from> <to>
        if len(args) < 2:
            return "error:range required"

        window_start, window_end = args[0], args[1]
        data = self.cal_load()

        pool = []
        for event in data.get("events", []):
            pool.append(event)
        for key, events in data.get("synced", {}).items():
            for event in events:
                pool.append(event)

        rows = []
        for event in pool:
            rule = event.get("rrule")
            dates = self.cal_expand(event.get("date", ""), rule,
                                    window_start, window_end,
                                    event.get("exdates"))
            for date in dates:
                rows.append("\x1f".join([
                    str(event.get("id", event.get("uid", ""))),
                    date,
                    str(event.get("time", "")),
                    str(event.get("endTime", "")),
                    str(event.get("title", "")).replace("\x1f", " "),
                    str(event.get("notes", "")).replace("\x1f", " ")[:200],
                    str(event.get("location", "")),
                    str(event.get("source", "")),
                    str(event.get("remind", "")),
                    "1" if rule else "0",
                ]))

        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def caladd(self, *args):
        ## --caladd <title> <date> [time] [endTime] [notes] [remind] [repeat]
        if len(args) < 2:
            return "error:title and date required"

        data = self.cal_load()
        rule = None
        repeat = args[6] if len(args) > 6 else ""
        if repeat and repeat != "none":
            rule = {"FREQ": repeat.upper()}

        entry = {
            "id": "local-%d" % int(time.time() * 1000),
            "title": args[0],
            "date": args[1],
            "time": args[2] if len(args) > 2 else "",
            "endTime": args[3] if len(args) > 3 else "",
            "notes": args[4] if len(args) > 4 else "",
            "remind": args[5] if len(args) > 5 else "",
            "rrule": rule,
            "exdates": [],
            "source": "",
        }
        data["events"].append(entry)
        self.cal_save(data)
        return "ok:" + entry["id"]

    @argfunc
    def caledit(self, *args):
        ## --caledit <id> <title> <date> [time] [endTime] [notes] [remind] [repeat]
        if len(args) < 3:
            return "error:id, title and date required"

        data = self.cal_load()
        target = None
        for event in data.get("events", []):
            if str(event.get("id")) == args[0]:
                target = event
                break

        if target is None:
            return "error:not found"

        repeat = args[7] if len(args) > 7 else ""
        target["title"] = args[1]
        target["date"] = args[2]
        target["time"] = args[3] if len(args) > 3 else ""
        target["endTime"] = args[4] if len(args) > 4 else ""
        target["notes"] = args[5] if len(args) > 5 else ""
        target["remind"] = args[6] if len(args) > 6 else ""
        target["rrule"] = ({"FREQ": repeat.upper()}
                           if repeat and repeat != "none" else None)

        self.cal_save(data)
        return "ok:" + str(target["id"])

    @argfunc
    def caldelete(self, *args):
        if not args:
            return "error:no id"
        data = self.cal_load()
        before = len(data["events"])
        data["events"] = [e for e in data["events"] if str(e.get("id")) != args[0]]
        self.cal_save(data)
        return "ok" if len(data["events"]) != before else "error:not found"

    @argfunc
    def calsubs(self, *args):
        data = self.cal_load()
        rows = []
        for sub in data.get("subscriptions", []):
            key = sub.get("key", "")
            rows.append("\x1f".join([
                key,
                sub.get("name", ""),
                sub.get("url", ""),
                "1" if sub.get("enabled", True) else "0",
                str(len(data.get("synced", {}).get(key, []))),
                sub.get("colour", ""),
            ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def calsubadd(self, *args):
        ## --calsubadd <url> [name] [user] [password]
        if not args:
            return "error:no url"

        data = self.cal_load()
        key = "sub-%d" % int(time.time() * 1000)
        data["subscriptions"].append({
            "key": key,
            "url": args[0],
            "name": args[1] if len(args) > 1 else args[0][:40],
            "user": args[2] if len(args) > 2 else "",
            "password": args[3] if len(args) > 3 else "",
            "enabled": True,
        })
        self.cal_save(data)
        return "ok:" + key

    @argfunc
    def calsubcolour(self, *args):
        ## --calsubcolour <key> <#rrggbb>
        if len(args) < 2:
            return "error:key and colour required"

        data = self.cal_load()
        for sub in data.get("subscriptions", []):
            if sub.get("key") == args[0]:
                sub["colour"] = args[1]
                self.cal_save(data)
                return "ok"
        return "error:not found"

    @argfunc
    def calsubremove(self, *args):
        if not args:
            return "error:no key"
        data = self.cal_load()
        data["subscriptions"] = [
            sub for sub in data.get("subscriptions", [])
            if sub.get("key") != args[0]
        ]
        data.get("synced", {}).pop(args[0], None)
        self.cal_save(data)
        return "ok"

    ## ── PACKAGES ─────────────────────────────────────────────────────────────
    ## Read only. Installing, updating and removing are handed to a terminal so
    ## the command is visible and confirmed rather than run silently as root.

    def pkg_run(self, args, timeout=30):
        try:
            return subprocess.run(args, capture_output=True, text=True,
                                  timeout=timeout).stdout
        except Exception:
            return ""

    def pkg_parse_qi(self, text):
        ## pacman -Qi prints "Key : Value" blocks with indented continuations
        packages = []
        current = {}
        key = ""
        for line in text.split("\n"):
            if not line.strip():
                if current:
                    packages.append(current)
                    current = {}
                    key = ""
                continue
            if line.startswith(" ") and key:
                current[key] += " " + line.strip()
                continue
            if " : " in line:
                key, value = line.split(" : ", 1)
                key = key.strip()
                current[key] = value.strip()
            elif line.rstrip().endswith(":"):
                key = line.rstrip().rstrip(":").strip()
                current[key] = ""
        if current:
            packages.append(current)
        return packages

    @argfunc
    def pkglist(self, *args):
        rows = []

        ## Explicitly installed, not pulled in as a dependency
        explicit = self.pkg_run(["pacman", "-Qqe"]).split()
        foreign = set(self.pkg_run(["pacman", "-Qqem"]).split())

        if explicit:
            info = self.pkg_run(["pacman", "-Qi"] + explicit, timeout=60)
            for pkg in self.pkg_parse_qi(info):
                name = pkg.get("Name", "")
                if not name:
                    continue
                depends = pkg.get("Depends On", "")
                if depends in ("None", ""):
                    depends = ""
                rows.append("\x1f".join([
                    "aur" if name in foreign else "repo",
                    name,
                    pkg.get("Version", ""),
                    pkg.get("Install Date", ""),
                    pkg.get("Description", "").replace("\x1f", " "),
                    depends.replace("\x1f", " "),
                    pkg.get("Installed Size", ""),
                ]))

        ## Flatpak applications, not runtimes
        flat = self.pkg_run(
            ["flatpak", "list", "--app",
             "--columns=application,name,version,origin,size"])
        for line in flat.split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            rows.append("\x1f".join([
                "flatpak",
                parts[0].strip(),
                parts[2].strip() if len(parts) > 2 else "",
                "",
                parts[1].strip(),
                parts[3].strip() if len(parts) > 3 else "",
                parts[4].strip() if len(parts) > 4 else "",
            ]))

        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def pkgupdates(self, *args):
        rows = []

        ## checkupdates does not touch the sync database, unlike pacman -Sy
        for line in self.pkg_run(["checkupdates"], timeout=60).split("\n"):
            parts = line.split()
            if len(parts) >= 4 and parts[2] == "->":
                rows.append("\x1f".join(["repo", parts[0], parts[1], parts[3]]))

        helper = ""
        for candidate in ("yay", "paru"):
            if self.pkg_run(["which", candidate]).strip():
                helper = candidate
                break

        if helper:
            for line in self.pkg_run([helper, "-Qua"], timeout=90).split("\n"):
                parts = line.split()
                if len(parts) >= 4 and parts[2] == "->":
                    rows.append("\x1f".join(["aur", parts[0], parts[1], parts[3]]))

        for line in self.pkg_run(
                ["flatpak", "remote-ls", "--updates", "--app",
                 "--columns=application,version"], timeout=60).split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t")
            rows.append("\x1f".join([
                "flatpak", parts[0].strip(), "",
                parts[1].strip() if len(parts) > 1 else "",
            ]))

        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def pkghelper(self, *args):
        ## Which AUR helper is available, so the UI can say what it will run
        for candidate in ("yay", "paru"):
            if self.pkg_run(["which", candidate]).strip():
                return candidate
        return "none"

    ## ── NETWORK ──────────────────────────────────────────────────────────────
    ## nmcli with tabular output. Fields are escaped with backslashes rather
    ## than quoted, so splitting has to respect them.

    def nm_split(self, line):
        out, current, escaped = [], "", False
        for ch in line:
            if escaped:
                current += ch
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == ":":
                out.append(current)
                current = ""
            else:
                current += ch
        out.append(current)
        return out

    def nm(self, args, timeout=12):
        try:
            return subprocess.run(["nmcli"] + args, capture_output=True,
                                  text=True, timeout=timeout).stdout
        except Exception:
            return ""

    @argfunc
    def netdevices(self, *args):
        text = self.nm(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"])
        rows = []
        for line in text.split("\n"):
            if not line.strip():
                continue
            parts = self.nm_split(line)
            if len(parts) < 4:
                continue
            if parts[1] in ("loopback",):
                continue
            rows.append("\x1f".join(parts[:4]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def netconnections(self, *args):
        text = self.nm(["-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE", "connection", "show"])
        rows = []
        for line in text.split("\n"):
            if not line.strip():
                continue
            parts = self.nm_split(line)
            if len(parts) < 5:
                continue
            rows.append("\x1f".join(parts[:5]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def netwifi(self, *args):
        text = self.nm(["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID",
                        "device", "wifi", "list"], timeout=20)
        rows = []
        seen = []
        for line in text.split("\n"):
            if not line.strip():
                continue
            parts = self.nm_split(line)
            if len(parts) < 4:
                continue
            ssid = parts[1].strip()
            if not ssid or ssid in seen:
                continue
            seen.append(ssid)
            rows.append("\x1f".join([
                "yes" if parts[0].strip() == "*" else "no",
                ssid,
                parts[2].strip(),
                parts[3].strip(),
            ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def netwifiscan(self, *args):
        self.nm(["device", "wifi", "rescan"], timeout=20)
        return "ok"

    @argfunc
    def netradio(self, *args):
        ## --netradio            reports wifi on/off
        ## --netradio on|off     sets it
        if args and args[0] in ("on", "off"):
            self.nm(["radio", "wifi", args[0]])
            return "ok"
        state = self.nm(["-t", "radio", "wifi"]).strip()
        return state if state else "unknown"

    @argfunc
    def netconnect(self, *args):
        if not args:
            return "error:no target given"

        if len(args) >= 2 and args[0] == "wifi":
            ssid = args[1]
            command = ["device", "wifi", "connect", ssid]
            if len(args) > 2 and args[2]:
                command += ["password", args[2]]
            out = self.nm(command, timeout=45)
        else:
            out = self.nm(["connection", "up", args[0]], timeout=45)

        lowered = out.lower()
        if "successfully" in lowered:
            return "ok"
        return "error:" + (out.strip().split("\n")[-1] if out.strip() else "connection failed")

    @argfunc
    def netdisconnect(self, *args):
        if not args:
            return "error:no target given"
        out = self.nm(["connection", "down", args[0]], timeout=30)
        lowered = out.lower()
        if "successfully" in lowered:
            return "ok"
        return "error:" + (out.strip().split("\n")[-1] if out.strip() else "disconnect failed")

    @argfunc
    def netforget(self, *args):
        if not args:
            return "error:no target given"
        out = self.nm(["connection", "delete", args[0]], timeout=30)
        if "successfully" in out.lower():
            return "ok"
        return "error:" + (out.strip().split("\n")[-1] if out.strip() else "delete failed")

    ## ── MIME HANDLERS ────────────────────────────────────────────────────────

    def mime_config_path(self):
        base = Path(os.environ.get("XDG_CONFIG_HOME") or (HOME / ".config"))
        return base / "mimeapps.list"

    def mime_read_defaults(self):
        ## [Default Applications] in mimeapps.list is what the user has chosen
        path = self.mime_config_path()
        defaults = {}
        if not path.exists():
            return defaults

        section = ""
        for line in path.read_text(errors="replace").split("\n"):
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                section = stripped[1:-1]
                continue
            if section != "Default Applications" or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            entries = [v for v in value.strip().split(";") if v]
            if entries:
                defaults[key.strip()] = entries[0]
        return defaults

    def mime_read_added(self):
        ## [Added Associations] is how an application is told it can open a type
        ## it never declared. Without it a default silently does not apply.
        path = self.mime_config_path()
        added = {}
        if not path.exists():
            return added

        section = ""
        for line in path.read_text(errors="replace").split("\n"):
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                section = stripped[1:-1]
                continue
            if section != "Added Associations" or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            added[key.strip()] = [v for v in value.strip().split(";") if v]
        return added

    def mime_read_candidates(self):
        ## mimeinfo.cache maps a type to every application that claims it
        candidates = {}
        roots = [
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications"),
            HOME / ".local/share/applications",
            Path("/var/lib/flatpak/exports/share/applications"),
            HOME / ".local/share/flatpak/exports/share/applications",
        ]
        for root in roots:
            cache = root / "mimeinfo.cache"
            if not cache.exists():
                continue
            for line in cache.read_text(errors="replace").split("\n"):
                if "=" not in line or line.startswith("["):
                    continue
                key, value = line.split("=", 1)
                for entry in value.strip().split(";"):
                    if not entry:
                        continue
                    candidates.setdefault(key.strip(), [])
                    if entry not in candidates[key.strip()]:
                        candidates[key.strip()].append(entry)
        return candidates

    def mime_globs(self):
        ## Extensions make a type far easier to recognise than its name alone
        path = Path("/usr/share/mime/globs")
        out = {}
        if not path.exists():
            return out
        for line in path.read_text(errors="replace").split("\n"):
            if not line or line.startswith("#") or ":" not in line:
                continue
            mime, pattern = line.split(":", 1)
            pattern = pattern.strip()
            if pattern.startswith("*."):
                pattern = pattern[1:]
            out.setdefault(mime.strip(), [])
            if pattern not in out[mime.strip()] and len(out[mime.strip()]) < 6:
                out[mime.strip()].append(pattern)
        return out

    def mime_all_types(self):
        listing = Path("/usr/share/mime/types")
        if listing.exists():
            return [t.strip() for t in listing.read_text(errors="replace").split("\n") if t.strip()]
        return []

    @argfunc
    def mimetypes(self, *args):
        defaults = self.mime_read_defaults()
        candidates = self.mime_read_candidates()
        added = self.mime_read_added()

        ## Anything claimed by hand is a candidate too
        for mime, ids in added.items():
            candidates.setdefault(mime, [])
            for entry in ids:
                if entry not in candidates[mime]:
                    candidates[mime].append(entry)

        known = self.mime_all_types()
        for key in candidates:
            if key not in known:
                known.append(key)
        for key in defaults:
            if key not in known:
                known.append(key)

        globs = self.mime_globs()

        rows = []
        for mime in sorted(set(known)):
            rows.append("\x1f".join([
                mime,
                defaults.get(mime, ""),
                ",".join(candidates.get(mime, [])),
                " ".join(globs.get(mime, [])),
                ",".join(added.get(mime, [])),
            ]))
        return "\x1e".join(rows) if rows else "none"

    def mime_write_sections(self, defaults, added):
        path = self.mime_config_path()
        path.parent.mkdir(parents=True, exist_ok=True)

        lines = path.read_text(errors="replace").split("\n") if path.exists() else []

        managed = ("Default Applications", "Added Associations")
        out = []
        in_managed = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                in_managed = stripped[1:-1] in managed
                if in_managed:
                    continue
                out.append(line)
                continue
            if in_managed:
                continue
            out.append(line)

        while out and out[-1].strip() == "":
            out.pop()

        if added:
            if out:
                out.append("")
            out.append("[Added Associations]")
            for key in sorted(added):
                if added[key]:
                    out.append("%s=%s;" % (key, ";".join(added[key])))

        if out:
            out.append("")
        out.append("[Default Applications]")
        for key in sorted(defaults):
            out.append("%s=%s" % (key, defaults[key]))

        text = "\n".join(out)
        if not text.endswith("\n"):
            text += "\n"

        if path.exists():
            backup = path.with_suffix(path.suffix + ".bak-%d" % int(time.time()))
            shutil.copy2(str(path), str(backup))
            try:
                stale = sorted(path.parent.glob(path.name + ".bak-*"))
                for old in stale[:-5]:
                    old.unlink()
            except Exception:
                pass

        path.write_text(text)
        return "ok"

    def mime_write_defaults(self, defaults):
        path = self.mime_config_path()
        path.parent.mkdir(parents=True, exist_ok=True)

        lines = path.read_text(errors="replace").split("\n") if path.exists() else []

        ## Drop the old section entirely, header included, then append a fresh
        ## one. Emitting the existing header and appending another produced two
        ## [Default Applications] blocks.
        out = []
        in_section = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                in_section = stripped[1:-1] == "Default Applications"
                if in_section:
                    continue
                out.append(line)
                continue
            if in_section:
                continue
            out.append(line)

        while out and out[-1].strip() == "":
            out.pop()

        if out:
            out.append("")
        out.append("[Default Applications]")
        for key in sorted(defaults):
            out.append("%s=%s" % (key, defaults[key]))

        text = "\n".join(out)
        if not text.endswith("\n"):
            text += "\n"

        if path.exists():
            backup = path.with_suffix(path.suffix + ".bak-%d" % int(time.time()))
            shutil.copy2(str(path), str(backup))
            try:
                stale = sorted(path.parent.glob(path.name + ".bak-*"))
                for old in stale[:-5]:
                    old.unlink()
            except Exception:
                pass

        path.write_text(text)
        return "ok"

    @argfunc
    def mimeset(self, *args):
        ## --mimeset <type> <desktopid> [claim]
        if len(args) < 2:
            return "error:not enough arguments"

        mime, desktop = args[0], args[1]
        claim = len(args) > 2 and args[2] == "claim"

        defaults = self.mime_read_defaults()
        added = self.mime_read_added()
        candidates = self.mime_read_candidates()

        defaults[mime] = desktop

        ## An application that never declared this type needs an explicit
        ## association, otherwise the default is ignored
        declared = desktop in candidates.get(mime, [])
        if claim or not declared:
            added.setdefault(mime, [])
            if desktop not in added[mime]:
                added[mime].insert(0, desktop)

        return self.mime_write_sections(defaults, added)

    @argfunc
    def mimeclear(self, *args):
        if not args:
            return "error:no type given"

        mime = args[0]
        drop_claim = len(args) > 1 and args[1] == "unclaim"

        defaults = self.mime_read_defaults()
        added = self.mime_read_added()

        if mime in defaults:
            del defaults[mime]
        if drop_claim and mime in added:
            del added[mime]

        return self.mime_write_sections(defaults, added)

    ## ── LUA KEYBINDS ─────────────────────────────────────────────────────────

    def lua_split_args(self, inner):
        args, depth, start, i, n = [], 0, 0, 0, len(inner)
        while i < n:
            ch = inner[i]
            if ch in ("'", '"'):
                quote = ch
                i += 1
                while i < n:
                    if inner[i] == "\\":
                        i += 2
                        continue
                    if inner[i] == quote:
                        break
                    i += 1
            elif ch in "({[":
                depth += 1
            elif ch in ")}]":
                depth -= 1
            elif ch == "," and depth == 0:
                args.append(inner[start:i].strip())
                start = i + 1
            i += 1
        tail = inner[start:].strip()
        if tail:
            args.append(tail)
        return args

    def lua_calls(self, text, call="hl.bind"):
        out = []
        for m in re.finditer(re.escape(call) + r"\s*\(", text):
            depth, i, n = 0, m.end() - 1, len(text)
            while i < n:
                ch = text[i]
                if ch in ("'", '"'):
                    quote = ch
                    i += 1
                    while i < n:
                        if text[i] == "\\":
                            i += 2
                            continue
                        if text[i] == quote:
                            break
                        i += 1
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            if depth != 0:
                continue
            out.append({
                "start": m.start(),
                "end": i + 1,
                "inner": text[m.end():i],
                "line": text[:m.start()].count("\n") + 1,
            })
        return out

    def lua_consts(self, text):
        out = {}
        for m in re.finditer(r'local\s+(\w+)\s*=\s*"([^"]*)"', text):
            out[m.group(1)] = m.group(2)
        return out

    def lua_key_display(self, expr, consts):
        parts = [p.strip() for p in expr.split("..")]
        resolved = []
        for part in parts:
            if part[:1] in ("'", '"') and part[-1:] == part[:1]:
                resolved.append(part[1:-1])
            elif part in consts:
                resolved.append(consts[part])
            else:
                resolved.append(part)
        return re.sub(r"\s*\+\s*", " + ", "".join(resolved).strip())

    def lua_key_expr(self, display, consts):
        ## Rebuild using whatever constant the config already uses, so edits keep
        ## the author's style instead of inlining SUPER everywhere.
        ##
        ## Either form is accepted in the one field: the resolved value
        ## ("SUPER + Space") or the variable itself ("mainMod + Space"). Both
        ## come back out as `mainMod .. " + Space"`.
        text = str(display).strip()

        ## Written as the variable
        for name in consts:
            if text == name:
                return name
            if text.startswith(name + " ") or text.startswith(name + "+"):
                rest = text[len(name):]
                if not rest.strip():
                    return name
                return '%s .. "%s"' % (name, rest)

        ## Written as the value the variable holds
        for name, value in consts.items():
            if text == value:
                return name
            if text.startswith(value + " + "):
                rest = text[len(value):]
                return '%s .. "%s"' % (name, rest)
        return '"%s"' % display.replace('"', '\\"')

    def lua_action_kind(self, expr):
        m = re.match(r'hl\.dsp\.exec_cmd\(\s*"((?:[^"\\]|\\.)*)"\s*\)$', expr.strip())
        if m:
            return "exec", m.group(1)
        m = re.match(r"hl\.dsp\.([\w.]+)", expr.strip())
        if m:
            return m.group(1), ""
        return "raw", expr.strip()

    ## ── LUA STARTUP BLOCK ────────────────────────────────────────────────────
    ## hl.on("hyprland.start", function() ... end) — edits stay inside that body

    def lua_startup_body(self, text):
        ## The walk has to start on the opening paren, not after the first
        ## argument, or the depth counter never opens and the scan runs off
        for m in re.finditer(r'hl\.on\s*\(', text):
            after = text[m.end():m.end() + 40]
            if '"hyprland.start"' not in after and "'hyprland.start'" not in after:
                continue
            depth, i, n = 0, m.end() - 1, len(text)
            while i < n:
                ch = text[i]
                if ch in ("'", '"'):
                    quote = ch
                    i += 1
                    while i < n:
                        if text[i] == "\\":
                            i += 2
                            continue
                        if text[i] == quote:
                            break
                        i += 1
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            if depth != 0:
                continue

            call_end = i
            body_open = text.find("function", m.end())
            if body_open == -1 or body_open > call_end:
                continue
            body_open = text.find(")", body_open)
            body_close = text.rfind("end", body_open, call_end)
            if body_open == -1 or body_close == -1:
                continue
            return {
                "start": m.start(),
                "end": call_end + 1,
                "body_start": body_open + 1,
                "body_end": body_close,
            }
        return None

    @argfunc
    def luastartup(self, *args):
        rows = []
        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            block = self.lua_startup_body(text)
            if not block:
                continue

            body = text[block["body_start"]:block["body_end"]]
            offset = block["body_start"]
            for m in re.finditer(r'hl\.exec_cmd\s*\(\s*"((?:[^"\\]|\\.)*)"\s*\)', body):
                line = text[:offset + m.start()].count("\n") + 1
                rows.append("\x1f".join([str(path), str(line), m.group(1)]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def luaaddstartup(self, *args):
        if not args:
            return "error:no command given"
        command = args[0]

        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            block = self.lua_startup_body(text)
            if not block:
                continue

            body = text[block["body_start"]:block["body_end"]]
            indent = "    "
            im = re.search(r"\n(\s+)hl\.exec_cmd", body)
            if im:
                indent = im.group(1)

            trimmed = body.rstrip()
            if not trimmed.endswith("\n"):
                trimmed += "\n"
            addition = '%shl.exec_cmd("%s")\n' % (indent, command.replace('"', '\\"'))

            new_body = body.rstrip("\n \t") + "\n" + addition
            new_text = (text[:block["body_start"]] + new_body
                        + text[block["body_end"]:])
            return self.lua_commit(path, new_text)

        return "error:no hyprland.start block found"

    @argfunc
    def luadeletestartup(self, *args):
        if len(args) < 2:
            return "error:not enough arguments"

        path = Path(args[0])
        line = int(args[1])
        if not path.exists():
            return "error:no such file"

        text = path.read_text()
        lines = text.split("\n")
        if line < 1 or line > len(lines):
            return "error:line out of range"
        if "hl.exec_cmd" not in lines[line - 1]:
            return "error:no hl.exec_cmd on that line"

        del lines[line - 1]
        return self.lua_commit(path, "\n".join(lines))

    @argfunc
    def luawritestartup(self, *args):
        if len(args) < 3:
            return "error:not enough arguments"

        path = Path(args[0])
        line = int(args[1])
        command = args[2]
        if not path.exists():
            return "error:no such file"

        text = path.read_text()
        lines = text.split("\n")
        if line < 1 or line > len(lines):
            return "error:line out of range"

        current = lines[line - 1]
        if "hl.exec_cmd" not in current:
            return "error:no hl.exec_cmd on that line"

        indent = re.match(r"\s*", current).group(0)
        lines[line - 1] = '%shl.exec_cmd("%s")' % (indent, command.replace('"', '\\"'))
        return self.lua_commit(path, "\n".join(lines))

    @argfunc
    def luaconsts(self, *args):
        ## The local string variables a key expression may use
        rows = []
        seen = []
        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            for name, value in self.lua_consts(text).items():
                if name in seen:
                    continue
                seen.append(name)
                rows.append("\x1f".join([name, value]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def luabinds(self, *args):
        rows = []
        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            consts = self.lua_consts(text)
            for call in self.lua_calls(text):
                parts = self.lua_split_args(call["inner"])
                if len(parts) < 2:
                    continue
                kind, detail = self.lua_action_kind(parts[1])
                rows.append("\x1f".join([
                    str(path),
                    str(call["line"]),
                    self.lua_key_display(parts[0], consts),
                    kind,
                    detail,
                    parts[1],
                    parts[2] if len(parts) > 2 else "",
                ]))
        return "\x1e".join(rows) if rows else "none"

    def lua_bind_text(self, key_expr, action_expr, options_expr):
        out = "hl.bind(%s, %s" % (key_expr, action_expr)
        if options_expr:
            out += ", %s" % options_expr
        return out + ")"

    @argfunc
    def luawritebind(self, *args):
        ## --luawritebind <file> <line> <key> <action> [options]
        if len(args) < 4:
            return "error:not enough arguments"

        path = Path(args[0])
        line = int(args[1])
        key_display = args[2]
        action_expr = args[3]
        options_expr = args[4] if len(args) > 4 else ""

        if not path.exists():
            return "error:no such file"

        text = path.read_text()
        consts = self.lua_consts(text)

        target = None
        for call in self.lua_calls(text):
            if call["line"] == line:
                target = call
                break
        if target is None:
            return "error:no hl.bind on that line"

        replacement = self.lua_bind_text(
            self.lua_key_expr(key_display, consts), action_expr, options_expr)
        new_text = text[:target["start"]] + replacement + text[target["end"]:]
        return self.lua_commit(path, new_text)

    @argfunc
    def luadeletebind(self, *args):
        if len(args) < 2:
            return "error:not enough arguments"

        path = Path(args[0])
        line = int(args[1])
        if not path.exists():
            return "error:no such file"

        text = path.read_text()
        target = None
        for call in self.lua_calls(text):
            if call["line"] == line:
                target = call
                break
        if target is None:
            return "error:no hl.bind on that line"

        begin = text.rfind("\n", 0, target["start"]) + 1
        finish = target["end"]
        while finish < len(text) and text[finish] != "\n":
            finish += 1
        finish += 1

        return self.lua_commit(path, text[:begin] + text[finish:])

    @argfunc
    def luaaddbind(self, *args):
        ## --luaaddbind <key> <action> [options] — grouped after the last bind
        if len(args) < 2:
            return "error:not enough arguments"

        key_display = args[0]
        action_expr = args[1]
        options_expr = args[2] if len(args) > 2 else ""

        target_path = None
        last_call = None
        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            calls = self.lua_calls(text)
            if calls:
                target_path = path
                last_call = calls[-1]

        if target_path is None:
            return "error:no hl.bind calls found to group with"

        text = target_path.read_text()
        consts = self.lua_consts(text)
        replacement = self.lua_bind_text(
            self.lua_key_expr(key_display, consts), action_expr, options_expr)

        insert_at = last_call["end"]
        while insert_at < len(text) and text[insert_at] != "\n":
            insert_at += 1
        insert_at += 1

        return self.lua_commit(target_path, text[:insert_at] + replacement + "\n" + text[insert_at:])

    @argfunc
    def luamonitors(self, *args):
        rows = []
        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            for b in self.lua_blocks(text):
                fields = self.lua_fields(b["inner"])
                if "output" not in fields:
                    continue
                flat = ";".join(
                    "%s=%s" % (k, self.lua_unquote(v["raw"]))
                    for k, v in fields.items()
                )
                rows.append("\x1f".join([
                    str(path),
                    str(text[:b["start"]].count("\n") + 1),
                    self.lua_unquote(fields["output"]["raw"]),
                    flat,
                ]))
        return "\x1e".join(rows) if rows else "none"

    @argfunc
    def luawritemonitor(self, *args):
        ## --luawritemonitor <output> key=value key=value ...
        if len(args) < 2:
            return "error:no fields given"

        output = args[0]
        updates = {}
        for pair in args[1:]:
            if "=" not in pair:
                continue
            key, value = pair.split("=", 1)
            updates[key] = value

        target_path = None
        target_block = None
        last_path = None
        last_block = None

        for path in self.lua_files():
            try:
                text = path.read_text(errors="replace")
            except Exception:
                continue
            for b in self.lua_blocks(text):
                fields = self.lua_fields(b["inner"])
                if "output" not in fields:
                    continue
                last_path, last_block = path, b
                if self.lua_unquote(fields["output"]["raw"]) == output:
                    target_path, target_block = path, b

        if target_path is None:
            if last_path is None:
                return "error:no hl.monitor rules found to group with"
            return self.lua_append_monitor(last_path, last_block, output, updates)

        text = target_path.read_text()
        inner = target_block["inner"]
        fields = self.lua_fields(inner)

        edits = []
        additions = []
        for key, value in updates.items():
            if key in fields:
                edits.append((fields[key]["span"],
                              self.lua_value(key, value, fields[key]["raw"])))
            else:
                additions.append((key, value))

        for (begin, finish), replacement in sorted(edits, key=lambda e: -e[0][0]):
            inner = inner[:begin] + replacement + inner[finish:]

        if additions:
            indent = "    "
            im = re.search(r"\n(\s*)\w+\s*=", target_block["inner"])
            if im:
                indent = im.group(1)
            stripped = inner.rstrip()
            if not stripped.endswith(","):
                stripped += ","
            for key, value in additions:
                stripped += "\n%s%s = %s," % (indent, key, self.lua_value(key, value))
            inner = stripped + "\n"

        new_text = (text[:target_block["inner_start"]] + inner
                    + text[target_block["inner_end"]:])
        return self.lua_commit(target_path, new_text)

    def lua_append_monitor(self, path, last_block, output, updates):
        text = path.read_text()
        body = ['    output = "%s",' % output]
        for key, value in updates.items():
            body.append("    %s = %s," % (key, self.lua_value(key, value)))
        block = "hl.monitor({\n" + "\n".join(body) + "\n})\n"

        insert_at = last_block["end"]
        while insert_at < len(text) and text[insert_at] != "\n":
            insert_at += 1
        insert_at += 1

        new_text = text[:insert_at] + "\n" + block + text[insert_at:]
        return self.lua_commit(path, new_text)

    @argfunc
    def getcommands(self, *args):
        ## Reads /proc/<pid>/cmdline for specific pids. The old path scanned the
        ## whole process table with ps on every app bar tick; this is called only
        ## for windows that have not been seen before.
        out = []
        for pid in args:
            cmd = ""
            try:
                with open(f"/proc/{int(pid)}/cmdline", "rb") as handle:
                    raw = handle.read()
                cmd = raw.replace(b"\x00", b" ").decode("utf-8", "replace").strip()
            except Exception:
                cmd = ""
            cmd = cmd.replace("|", " ").replace(",", " ")
            out.append(f"{pid}:{cmd}")
        return "|".join(out)

    @argfunc
    def closehyprwindow(self, *args):
        full_arg_str = ' '.join(args)
        clients = json.loads(subprocess.run(['hyprctl', 'clients', '-j'],
                                            capture_output=True, text=True).stdout)
        results = ""
        for i, target_title in enumerate(full_arg_str.split(",")):
            target_title = target_title.strip()
            if not target_title: continue
            found = False
            for client in clients:
                matches = process.extract(client['title'], [target_title], scorer=fuzz.WRatio, limit=20)
                for n, score, _ in matches:
                    if score >= 92:
                        subprocess.run(['hyprctl', 'dispatch', 'closewindow', f"address:{client['address']}"])
                        results += f"{i}:ok|"
                        found = True
            if not found: results += f"{i}:no|"
        return results.rstrip("|")

    # ── ICON LOOKUP ──────────────────────────────────────────────────────────

    def extract_size(self, path):
        match = re.search(r"/(\d+)x\d+/", path)
        if match: return int(match.group(1))
        return 9999 if "scalable" in path else 0

    def build_icon_index(self):
        index = []
        for ROOT in ICON_ROOTS:
            if not os.path.isdir(ROOT):
                continue
            # followlinks=True is essential — Flatpak export dirs are symlink trees
            for dirpath, _, files in os.walk(ROOT, followlinks=True):
                for file in files:
                    if not file.endswith(VALID_EXTS): continue
                    full = os.path.join(dirpath, file)
                    name = os.path.splitext(file)[0].lower()
                    index.append((name, full, self.extract_size(full)))
        return index

    @staticmethod
    def _icon_roots_fingerprint():
        """Hash of ICON_ROOTS + their mtimes so the cache auto-rebuilds
        when directories are added/changed (e.g. new Flatpak installed)."""
        parts = []
        for r in ICON_ROOTS:
            try:
                parts.append(f"{r}:{os.path.getmtime(r):.0f}")
            except OSError:
                parts.append(f"{r}:missing")
        return "|".join(parts)

    def _pick_best_icon(self, candidates):
        """From a list of (name, path, size) tuples, pick the best icon.

        Prefers:
          1. Icons inside an 'apps' directory
          2. Scalable (size 9999) or largest raster ≥ 48
          3. PNG over SVG over XPM for raster; SVG fine for scalable
        """
        if not candidates:
            return None

        def sort_key(entry):
            _, path, size = entry
            in_apps = 1 if "/apps/" in path else 0
            # Prefer hicolor as the universal fallback theme
            in_hicolor = 1 if "/hicolor/" in path else 0
            return (in_apps, in_hicolor, size)

        return max(candidates, key=sort_key)

    def resolve_icon_name(self, icon_name, index=None):
        """Resolve a freedesktop icon name (or full path) to an icon file path.

        Lookup order:
          1. Already a valid file path → return as-is
          2. /usr/share/pixmaps/ exact match (case-insensitive, any valid ext)
          3. Exact name match in icon index (case-insensitive)
          4. If name contains dots (e.g. org.gnome.Nautilus), try the last segment
          5. If name contains hyphens (e.g. utilities-terminal), try last segment
          6. Fuzzy match with high threshold (≥ 85) as last resort
        Returns the path or empty string on failure.
        """
        if not icon_name:
            return ""

        # 1. Already a full path?
        if os.path.isfile(icon_name):
            return icon_name

        # 2. Check /usr/share/pixmaps/ (many apps install icons here directly)
        pixmaps_dir = "/usr/share/pixmaps"
        if os.path.isdir(pixmaps_dir):
            icon_lower = icon_name.lower()
            for f in os.listdir(pixmaps_dir):
                if not f.endswith(VALID_EXTS):
                    continue
                if os.path.splitext(f)[0].lower() == icon_lower:
                    return os.path.join(pixmaps_dir, f)

        # Build or reuse index
        if index is None:
            index = self.build_icon_index()

        icon_lower = icon_name.lower()

        # 3. Exact match in icon index
        exact = [e for e in index if e[0] == icon_lower]
        if exact:
            best = self._pick_best_icon(exact)
            if best:
                return best[1]

        # 4. Dotted names (e.g. com.hytale.Launcher, org.gnome.Nautilus)
        #    Try segments from most-specific to least:
        #    com.hytale.Launcher → try "launcher", then "hytale", then "com"
        #    Also try joining the last two: "hytale.launcher" / "hytale-launcher"
        if "." in icon_name:
            segments = icon_name.split(".")
            # Try individual segments from the right (skip single-char or too-short)
            for seg in reversed(segments):
                seg_lower = seg.lower()
                if len(seg_lower) < 2 or seg_lower == icon_lower:
                    continue
                seg_exact = [e for e in index if e[0] == seg_lower]
                if seg_exact:
                    best = self._pick_best_icon(seg_exact)
                    if best:
                        return best[1]
            # Try "appname-subname" style (e.g. "hytale-launcher")
            if len(segments) >= 2:
                hyphenated = (segments[-2] + "-" + segments[-1]).lower()
                hyp_exact = [e for e in index if e[0] == hyphenated]
                if hyp_exact:
                    best = self._pick_best_icon(hyp_exact)
                    if best:
                        return best[1]

        # 5. Try last segment of hyphenated names (utilities-terminal → terminal)
        if "-" in icon_name:
            last_seg = icon_name.rsplit("-", 1)[-1].lower()
            if last_seg and last_seg != icon_lower:
                seg_exact = [e for e in index if e[0] == last_seg]
                if seg_exact:
                    best = self._pick_best_icon(seg_exact)
                    if best:
                        return best[1]

        # 6. Fuzzy match as last resort — high threshold to avoid wrong icons
        names = [e[0] for e in index]
        matches = process.extract(icon_lower, names, scorer=fuzz.WRatio, limit=10)
        candidates = [index[idx] for _, score, idx in matches if score >= 85]
        if candidates:
            best = self._pick_best_icon(candidates)
            if best:
                return best[1]

        return ""

    @argfunc
    def getappicons(self, *args):
        # Optional first arg: "--clearcache" removes cached entries for
        # the requested class names so they get re-looked up fresh.
        # Useful when a newly pinned app returned a wrong or missing icon.
        args = list(args)
        clear_cache = False
        if args and args[0] == "--clearcache":
            clear_cache = True
            args = args[1:]

        classnames = args
        results    = []
        cache      = {"apps": {}, "index": []}
        save_cache = False
        cachepath  = ICON_CACHE
        fingerprint = self._icon_roots_fingerprint()

        if cachepath.exists():
            try:
                with open(cachepath, "r") as f: cache = json.load(f)
            except (json.JSONDecodeError, Exception):
                # Cache is corrupted — delete and rebuild from scratch
                cachepath.unlink(missing_ok=True)
                save_cache = True
                cache = {"apps": {}, "index": self.build_icon_index(), "_roots": fingerprint}

            # Invalidate index if ICON_ROOTS changed (new dirs, new Flatpak, etc.)
            if cache.get("_roots") != fingerprint:
                cache["index"] = self.build_icon_index()
                cache["_roots"] = fingerprint
                # Clear all cached app→icon mappings so they re-resolve
                cache["apps"] = {}
                save_cache = True

            # Remove requested classes from cache so they get re-resolved
            if clear_cache:
                for cls in classnames:
                    if cls in cache['apps']:
                        del cache['apps'][cls]
                        save_cache = True

            for key in list(cache['apps'].keys()):
                if key in classnames:
                    classnames.remove(key)
                    results.append(f"{key}:{cache['apps'][key]}")
        else:
            save_cache = True
            cache['index'] = self.build_icon_index()
            cache['_roots'] = fingerprint

        # Rebuild index if empty (e.g. cache existed but index was cleared)
        if not cache['index']:
            cache['index'] = self.build_icon_index()
            cache['_roots'] = fingerprint
            save_cache = True

        index = cache['index']
        for cls in classnames:
            resolved = self.resolve_icon_name(cls, index)
            if resolved:
                cache['apps'][cls] = resolved
                save_cache = True
                results.append(f"{cls}:{resolved}")

        if save_cache:
            with open(cachepath, "w") as f: json.dump(cache, f, indent=4)
        return ",".join(results)

    @argfunc
    def setappicon(self, *args):
        """Write a specific icon to the cache for a class name.
        This lets the 'Add from Installed Apps' flow use the .desktop icon directly.
        Args: className iconNameOrPath
        The icon can be a system icon name (e.g. 'code') or a full path.
        If it's a name, we resolve it to a path via the icon index first.
        Returns: the resolved icon path or empty string on failure.
        """
        if len(args) < 2:
            return ""
        cls  = args[0].strip()
        icon = args[1].strip()

        cachepath = ICON_CACHE
        fingerprint = self._icon_roots_fingerprint()

        # Load or build cache
        cache = {"apps": {}, "index": []}
        if cachepath.exists():
            try:
                with open(cachepath, "r") as f:
                    cache = json.load(f)
            except Exception:
                cachepath.unlink(missing_ok=True)
                cache = {"apps": {}, "index": []}

        # Rebuild index if stale or missing
        if not cache.get("index") or cache.get("_roots") != fingerprint:
            cache["index"] = self.build_icon_index()
            cache["_roots"] = fingerprint

        resolved = self.resolve_icon_name(icon, cache["index"])
        if resolved:
            cache["apps"][cls] = resolved
            with open(cachepath, "w") as f:
                json.dump(cache, f, indent=4)
            return resolved

        return ""



    @argfunc
    def getdesktopapps(self, *args):
        """Parse .desktop files. Returns newline-separated: name|exec|icon|className|comment"""
        search_paths = [
            "/usr/share/applications/*.desktop",
            "/usr/local/share/applications/*.desktop",
            "/var/lib/flatpak/exports/share/applications/*.desktop",
            os.path.expanduser("~/.local/share/applications/*.desktop"),
            os.path.expanduser("~/.local/share/flatpak/exports/share/applications/*.desktop"),
        ]
        results, seen = [], set()

        for pattern in search_paths:
            # follow_symlinks via glob — Flatpak desktop files are symlinks
            for path in sorted(glob.glob(pattern, recursive=False)):
                # Resolve symlink so we read the actual file
                path = os.path.realpath(path)
                if not os.path.isfile(path): continue
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        raw = f.read()
                    config = configparser.RawConfigParser()
                    config.read_string(raw)
                    if not config.has_section("Desktop Entry"): continue
                    entry = config["Desktop Entry"]

                    # Only skip truly hidden/nodisplay apps
                    if entry.get("NoDisplay", "false").lower() == "true": continue
                    if entry.get("Hidden",    "false").lower() == "true": continue
                    # Keep Terminal apps — user may want to pin them
                    # (they just open in a terminal window)

                    # Must have a name and exec
                    name = entry.get("Name", "").strip()
                    if not name: continue

                    # Deduplicate by name
                    if name in seen: continue
                    seen.add(name)

                    exec_raw   = entry.get("Exec", "").strip()
                    if not exec_raw: continue

                    # Strip field codes and env prefixes
                    exec_clean = re.sub(r'\s*%[fFuUdDnNickvmBb]\s*', ' ', exec_raw).strip()
                    exec_clean = re.sub(r'^env\s+\S+=\S+\s+', '', exec_clean).strip()

                    icon    = entry.get("Icon",    "").strip()
                    comment = entry.get("Comment", "").strip().replace("|", "-").replace("\n", " ")

                    # Try StartupWMClass first — most reliable for window matching
                    class_name = entry.get("StartupWMClass", "").strip()
                    if not class_name:
                        # For Flatpak: Exec starts with "flatpak run com.app.Name"
                        # Use the app ID as class name since that's what Hyprland sees
                        exec_parts = exec_clean.split()
                        if len(exec_parts) >= 3 and exec_parts[0] == "flatpak" and exec_parts[1] == "run":
                            class_name = exec_parts[2]  # e.g. com.discordapp.Discord
                        else:
                            binary     = exec_parts[0] if exec_parts else ""
                            class_name = os.path.basename(binary) if binary else name
                            class_name = re.sub(r"^.*/", "", class_name)

                    results.append(f"{name}|{exec_clean}|{icon}|{class_name}|{comment}")
                except Exception:
                    continue

        results.sort(key=lambda x: x.split("|")[0].lower())
        return "\n".join(results) if results else "none"

    # ── BLUETOOTH ────────────────────────────────────────────────────────────

    @argfunc
    def btpower(self, *args):
        action = args[0] if args else 'toggle'
        if action == 'toggle':
            result  = subprocess.run(['bluetoothctl', 'show'], capture_output=True, text=True)
            action  = 'off' if 'Powered: yes' in result.stdout else 'on'
        subprocess.run(['bluetoothctl', 'power', action], capture_output=True)
        return action

    @argfunc
    def btstate(self, *args):
        result = subprocess.run(['bluetoothctl', 'show'], capture_output=True, text=True)
        powered      = 'yes' if 'Powered: yes'     in result.stdout else 'no'
        scanning     = 'yes' if 'Discovering: yes'  in result.stdout else 'no'
        discoverable = 'yes' if 'Discoverable: yes' in result.stdout else 'no'
        name = ''
        for line in result.stdout.splitlines():
            if 'Name:' in line: name = line.split('Name:', 1)[1].strip(); break

        ## Connected devices were never reported, so anything reading this
        ## always believed nothing was connected
        connected = 0
        first = ''
        try:
            listing = subprocess.run(['bluetoothctl', 'devices', 'Connected'],
                                     capture_output=True, text=True, timeout=6).stdout
            for line in listing.splitlines():
                line = line.strip()
                if not line.startswith('Device '):
                    continue
                connected += 1
                if not first:
                    parts = line.split(' ', 2)
                    first = parts[2].strip() if len(parts) > 2 else ''
        except Exception:
            pass

        first = first.replace(',', ' ')
        return (f"powered:{powered},scanning:{scanning},discoverable:{discoverable},"
                f"connected:{connected},device:{first},name:{name}")

    @argfunc
    def btdevices(self, *args):
        paired_out    = subprocess.run(['bluetoothctl', 'devices', 'Paired'],    capture_output=True, text=True).stdout.strip()
        connected_out = subprocess.run(['bluetoothctl', 'devices', 'Connected'], capture_output=True, text=True).stdout.strip()
        connected_macs = {l.strip().split(' ', 2)[1] for l in connected_out.splitlines() if len(l.strip().split(' ', 2)) >= 2}
        devices = []
        for line in paired_out.splitlines():
            parts = line.strip().split(' ', 2)
            if len(parts) < 3: continue
            mac, name = parts[1], parts[2]
            info = subprocess.run(['bluetoothctl', 'info', mac], capture_output=True, text=True).stdout
            battery = alias = icon = ''
            alias = name
            for l in info.splitlines():
                l = l.strip()
                if l.startswith('Battery Percentage:'):
                    try: battery = l.split('(')[1].split(')')[0].strip()
                    except: pass
                elif l.startswith('Icon:'):   icon  = l.split(':', 1)[1].strip()
                elif l.startswith('Alias:'):  alias = l.split(':', 1)[1].strip()
            devices.append(f"{mac}|{name}|{alias}|{'yes' if mac in connected_macs else 'no'}|{battery}|{icon}")
        return '\n'.join(devices) if devices else 'none'

    @argfunc
    def btscan(self, *args):
        action = args[0] if args else 'on'
        if action == 'on':
            subprocess.Popen(['bluetoothctl', '--timeout', '10', 'scan', 'on'],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return 'scanning'
        subprocess.run(['bluetoothctl', 'scan', 'off'], capture_output=True)
        return 'stopped'

    @argfunc
    def btscanresults(self, *args):
        all_devs   = subprocess.run(['bluetoothctl', 'devices'],        capture_output=True, text=True).stdout.strip()
        paired_out = subprocess.run(['bluetoothctl', 'devices', 'Paired'], capture_output=True, text=True).stdout.strip()
        paired_macs = {l.strip().split(' ', 2)[1] for l in paired_out.splitlines() if len(l.strip().split(' ', 2)) >= 2}
        results = []
        for line in all_devs.splitlines():
            parts = line.strip().split(' ', 2)
            if len(parts) < 3: continue
            if parts[1] not in paired_macs:
                results.append(f"{parts[1]}|{parts[2]}")
        return '\n'.join(results) if results else 'none'

    @argfunc
    def btconnect(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        result  = subprocess.run(['bluetoothctl', 'connect', mac], capture_output=True, text=True, timeout=15)
        success = 'Connection successful' in result.stdout or 'Connected: yes' in result.stdout
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth',
                        f'Connected to {name}' if success else f'Failed to connect to {name}'])
        return 'ok' if success else 'fail'

    @argfunc
    def btdisconnect(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        subprocess.run(['bluetoothctl', 'disconnect', mac], capture_output=True)
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth', f'Disconnected {name}'])
        return 'ok'

    @argfunc
    def btforget(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        subprocess.run(['bluetoothctl', 'remove', mac], capture_output=True)
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth', f'Forgot {name}'])
        return 'ok'

    @argfunc
    def btpair(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        subprocess.run(['bluetoothctl', 'trust', mac], capture_output=True)
        result  = subprocess.run(['bluetoothctl', 'pair', mac], capture_output=True, text=True, timeout=30)
        success = 'Pairing successful' in result.stdout or 'Failed' not in result.stdout
        if success: subprocess.run(['bluetoothctl', 'connect', mac], capture_output=True)
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth',
                        f'Paired with {name}' if success else f'Failed to pair with {name}'])
        return 'ok' if success else 'fail'

    # ── DDC / DISPLAY BRIGHTNESS ─────────────────────────────────────────────


    @argfunc
    def ddcmapping(self, *args):
        """Returns DDC display number to connector name mapping.
        Parses 'ddcutil detect' output to map DDC num -> connector name.
        Returns: connector:ddcnum|connector:ddcnum|...
        e.g. HDMI-A-1:1|DP-1:2|DP-2:3
        """
        result = subprocess.run(
            ["ddcutil", "detect"],
            capture_output=True, text=True, timeout=10
        )

        mapping = {}
        current_num = None
        current_connector = None

        for line in result.stdout.splitlines():
            ls = line.strip()

            if ls.startswith("Display "):
                # Save previous
                if current_num is not None and current_connector is not None:
                    mapping[current_connector] = current_num
                try:
                    current_num = int(ls.split()[1])
                except:
                    current_num = None
                current_connector = None

            elif "DRM_connector:" in ls and current_num is not None:
                # Format: "DRM_connector:  card1-HDMI-A-1"
                parts = ls.split("DRM_connector:")
                if len(parts) >= 2:
                    # Strip "card1-" or "card0-" prefix
                    connector = parts[1].strip()
                    connector = re.sub(r"^card\d+-", "", connector)
                    current_connector = connector

        # Save last
        if current_num is not None and current_connector is not None:
            mapping[current_connector] = current_num

        return "|".join([f"{conn}:{num}" for conn, num in mapping.items()]) if mapping else "none"


    @argfunc
    def ddcgetbrightness(self, *args):
        detect   = subprocess.run(["ddcutil", "detect", "--brief"], capture_output=True, text=True, timeout=10)
        displays = [l.strip().split()[1] for l in detect.stdout.splitlines()
                    if l.strip().startswith("Display ")]
        results  = []
        for d in displays:
            try:
                out  = subprocess.run(["ddcutil", "--display", d, "getvcp", "10"],
                                       capture_output=True, text=True, timeout=5).stdout.strip()
                cur  = next((int(p.split("=")[-1].strip()) for p in out.split(",") if "current value" in p), 0)
                mx   = next((int(p.split("=")[-1].strip()) for p in out.split(",") if "max value"     in p), 100)
                results.append(f"{d}:{cur}:{mx}")
            except Exception:
                results.append(f"{d}:0:100")
        return "|".join(results)

    ## ddcutil talks over I2C and is slow — a detect is seconds, a getvcp is
    ## hundreds of milliseconds. The display list is cached and every per-display
    ## call is issued in parallel so the cost is one round trip, not N.

    def ddc_displays(self, refresh=False):
        if not refresh:
            try:
                cached = json.loads(DDC_CACHE.read_text())
                if cached.get("displays"):
                    return cached["displays"], cached.get("names", {})
            except Exception:
                pass

        result = subprocess.run(["ddcutil", "detect"],
                                capture_output=True, text=True, timeout=20)
        displays, names = [], {}
        num, model = None, None
        for line in result.stdout.splitlines():
            ls = line.strip()
            if ls.startswith("Display "):
                if num is not None:
                    displays.append(num)
                    names[str(num)] = model or f"Display {num}"
                try:
                    num = int(ls.split()[1])
                except Exception:
                    num = None
                model = None
            elif ls.startswith("Model:") and num is not None:
                model = ls.split(":", 1)[1].strip()
        if num is not None:
            displays.append(num)
            names[str(num)] = model or f"Display {num}"

        try:
            DDC_CACHE.write_text(json.dumps({"displays": displays, "names": names}))
        except Exception:
            pass
        return displays, names

    def ddc_get_one(self, display):
        try:
            out = subprocess.run(["ddcutil", "--display", str(display), "getvcp", "10"],
                                 capture_output=True, text=True, timeout=8).stdout.strip()
            cur = next((int(p.split("=")[-1].strip())
                        for p in out.split(",") if "current value" in p), 0)
            mx = next((int(p.split("=")[-1].strip())
                       for p in out.split(",") if "max value" in p), 100)
            return display, cur, mx
        except Exception:
            return display, 0, 100

    def ddc_set_one(self, display, value):
        try:
            subprocess.run(["ddcutil", "--display", str(display), "setvcp", "10", str(value)],
                           capture_output=True, timeout=8)
            return True
        except Exception:
            return False

    @argfunc
    def ddcrefresh(self, *args):
        displays, names = self.ddc_displays(refresh=True)
        if not displays:
            return "none"
        return "|".join([f"{d}:{names.get(str(d), d)}" for d in displays])

    @argfunc
    def ddcstatus(self, *args):
        from concurrent.futures import ThreadPoolExecutor

        displays, names = self.ddc_displays()
        if not displays:
            return "none"

        with ThreadPoolExecutor(max_workers=len(displays)) as pool:
            results = list(pool.map(self.ddc_get_one, displays))

        percents = []
        parts = []
        for display, cur, mx in results:
            pct = round((cur / mx) * 100) if mx > 0 else 0
            percents.append(pct)
            parts.append(f"{display}:{pct}:{names.get(str(display), display)}")

        average = round(sum(percents) / len(percents)) if percents else 0
        return f"{average}#" + "|".join(parts)

    @argfunc
    def ddcsetall(self, *args):
        from concurrent.futures import ThreadPoolExecutor

        if not args:
            return "fail"
        value = max(0, min(100, int(float(args[0]))))

        displays, _ = self.ddc_displays()
        if not displays:
            return "none"

        with ThreadPoolExecutor(max_workers=len(displays)) as pool:
            list(pool.map(lambda d: self.ddc_set_one(d, value), displays))
        return "ok"

    @argfunc
    def ddcsetbrightness(self, *args):
        if len(args) < 2: return "fail"
        display, value = str(args[0]), max(0, min(100, int(float(args[1]))))
        try:
            subprocess.run(["ddcutil", "--display", display, "setvcp", "10", str(value)],
                           capture_output=True, timeout=5)
            return "ok"
        except Exception:
            return "fail"

    # ── USB ──────────────────────────────────────────────────────────────────

    @argfunc
    def usbmountcheck(self, *args):
        """Check if device is mounted; mount via udisksctl if not.
        Returns: mountpoint|label  or  none
        """
        if not args: return "none"
        devName = args[0].strip()
        devPath = "/dev/" + devName

        def get_mountpoint(dev):
            result = subprocess.run(["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT", dev],
                                    capture_output=True, text=True)
            try:
                data = json.loads(result.stdout.strip())
                for d in data.get("blockdevices", []):
                    for c in [d] + d.get("children", []):
                        mp = c.get("mountpoint") or ""
                        lb = c.get("label") or devName
                        if mp.startswith("/"): return mp, lb
            except Exception: pass
            return "", devName

        mp, lb = get_mountpoint(devPath)
        if mp: return f"{mp}|{lb}"

        mount = subprocess.run(["udisksctl", "mount", "-b", devPath, "--no-user-interaction"],
                               capture_output=True, text=True, timeout=10)
        if "Mounted" in mount.stdout or mount.returncode == 0:
            mp, lb = get_mountpoint(devPath)
            if mp: return f"{mp}|{lb}"
            for line in mount.stdout.splitlines():
                if " at " in line:
                    mp = line.split(" at ", 1)[-1].strip().rstrip(".")
                    if mp.startswith("/"): return f"{mp}|{devName}"
        return "none"

    # ── COMMAND HISTORY ──────────────────────────────────────────────────────

    @argfunc
    def getcommandhistory(self, *args):
        """Read shell command history, filter out system/package/sudo commands.
        Checks bash, zsh, and fish history files.
        Returns newline-separated unique commands, most recent first.

        NOTE: This filter is intentionally heavy — it strips sudo, package managers,
        system utilities, git, file operations, shell builtins, and single-word commands.
        The intent is to surface app launches and custom scripts only.
        If a command you expect to see is missing, it is almost certainly being filtered.
        To reduce filtering, edit the FILTER_PREFIXES list below.
        """
        # Commands to filter out — system, package management, sudo, etc.
        FILTER_PREFIXES = (
            "sudo", "pacman", "yay", "paru", "apt", "dnf", "brew",
            "systemctl", "journalctl", "service", "chown", "chmod",
            "rm ", "rmdir", "mv ", "cp ", "ln ", "mount", "umount",
            "dd ", "mkfs", "fdisk", "parted",
            "git ", "pip ", "npm ", "cargo", "make", "cmake",
            "ssh", "scp", "rsync",
            "cat ", "less", "more", "tail", "head", "grep", "awk", "sed",
            "ls", "cd ", "pwd", "echo", "export", "source", ".",
            "kill", "pkill", "killall",
            "man ", "help", "which", "whereis",
            "#",  # comments
        )

        # History file locations
        history_files = [
            Path(os.path.expanduser("~/.bash_history")),
            Path(os.path.expanduser("~/.zsh_history")),
            Path(os.path.expanduser("~/.local/share/fish/fish_history")),
        ]

        commands = []
        seen = set()

        for hfile in history_files:
            if not hfile.exists():
                continue
            try:
                with open(hfile, "r", encoding="utf-8", errors="ignore") as f:
                    lines = f.readlines()

                # Fish history format: "- cmd: command" / "  when: timestamp"
                is_fish = "fish" in str(hfile)

                for line in reversed(lines):
                    line = line.strip()
                    if not line:
                        continue

                    if is_fish:
                        if line.startswith("- cmd:"):
                            cmd = line[6:].strip()
                        else:
                            continue
                    else:
                        # zsh history has timestamps: ": 1234567890:0;command"
                        if line.startswith(":") and ";" in line:
                            cmd = line.split(";", 1)[-1].strip()
                        else:
                            cmd = line

                    if not cmd or len(cmd) < 3:
                        continue

                    # Filter out system commands
                    skip = False
                    for prefix in FILTER_PREFIXES:
                        if cmd.lower().startswith(prefix.lower()):
                            skip = True
                            break

                    # Also skip commands that are just a single word (bare builtins)
                    if not skip and " " not in cmd and "/" not in cmd:
                        skip = True

                    if skip or cmd in seen:
                        continue

                    seen.add(cmd)
                    commands.append(cmd)

                    if len(commands) >= 100:
                        break

            except Exception:
                continue

        return "\n".join(commands) if commands else "none"

    # ── SMART CROP ───────────────────────────────────────────────────────────

    @argfunc
    def smartcrop(self, *args):
        """Crop a wallpaper to fit a vertical monitor, centering on the most
        visually interesting horizontal region.

        Args: wallpaper_path monitor_width monitor_height

        Returns: path to cropped temp file, or original path if no crop needed.
        The caller is responsible for deleting the temp file after use.
        """
        if len(args) < 3:
            return args[0] if args else ""

        wallpaper_path = args[0]
        try:
            mon_w = int(args[1])
            mon_h = int(args[2])
        except ValueError:
            return wallpaper_path

        try:
            from PIL import Image
            import numpy as np
            import tempfile
        except ImportError:
            return wallpaper_path

        # Only process vertical monitors
        if mon_h <= mon_w:
            return wallpaper_path

        try:
            img = Image.open(wallpaper_path)
        except Exception:
            return wallpaper_path

        img_w, img_h = img.size
        mon_ratio  = mon_w / mon_h
        img_ratio  = img_w / img_h

        # Check if crop is needed — skip if ratios are close enough
        # Threshold: within 15% relative difference
        ratio_diff = abs(img_ratio - mon_ratio) / mon_ratio
        if ratio_diff < 0.15:
            return wallpaper_path

        # ── Saliency: find most interesting horizontal region ─────────────────
        # Downsample for speed, convert to grayscale, compute column variance
        thumb_h = 200
        scale   = thumb_h / img_h
        thumb_w = max(1, int(img_w * scale))
        thumb   = img.resize((thumb_w, thumb_h), Image.LANCZOS).convert("L")
        arr     = np.array(thumb, dtype=np.float32)

        # Column variance — high variance = interesting content
        col_variance = np.var(arr, axis=0)  # shape: (thumb_w,)

        # Check if variance is too balanced (flat/uniform image) — leave alone
        var_max  = col_variance.max()
        var_mean = col_variance.mean()
        if var_max == 0 or (var_max - var_mean) / (var_max + 1e-6) < 0.1:
            # Variance is too uniform — content is spread evenly, don't crop
            return wallpaper_path

        # Find center of mass of variance — weighted average of column positions
        cols      = np.arange(thumb_w, dtype=np.float32)
        salient_x = np.sum(cols * col_variance) / np.sum(col_variance)

        # Map salient_x back to original image coordinates
        salient_x_orig = salient_x / scale

        # ── Determine crop dimensions ─────────────────────────────────────────
        # Target width that matches monitor aspect ratio at full image height
        target_w = int(img_h * mon_ratio)

        if target_w >= img_w:
            # Image is narrower than needed — scale to fit width, crop height
            # (landscape on a portrait monitor: center vertically)
            target_h = int(img_w / mon_ratio)
            top  = max(0, (img_h - target_h) // 2)
            box  = (0, top, img_w, top + target_h)
        else:
            # Image is wider than target — crop width, centering on salient_x
            half_w  = target_w / 2
            crop_x1 = salient_x_orig - half_w
            crop_x2 = salient_x_orig + half_w

            # Clamp to image bounds
            if crop_x1 < 0:
                crop_x2 -= crop_x1
                crop_x1  = 0
            if crop_x2 > img_w:
                crop_x1 -= (crop_x2 - img_w)
                crop_x2  = img_w
            crop_x1 = max(0, int(crop_x1))
            crop_x2 = min(img_w, int(crop_x2))
            box = (crop_x1, 0, crop_x2, img_h)

        # ── Crop and save to temp file ────────────────────────────────────────
        cropped = img.crop(box)
        ext     = os.path.splitext(wallpaper_path)[1] or ".png"
        tmp     = tempfile.NamedTemporaryFile(
            suffix=ext,
            prefix="qs_wallpaper_",
            dir="/tmp",
            delete=False
        )
        tmp.close()

        # Preserve format
        fmt_map = {".jpg": "JPEG", ".jpeg": "JPEG", ".png": "PNG",
                   ".webp": "WEBP", ".bmp": "BMP"}
        fmt = fmt_map.get(ext.lower(), "PNG")
        cropped.save(tmp.name, fmt)

        return tmp.name



    # ── COLOR HISTORY ────────────────────────────────────────────────────────

    @argfunc
    def addcolor(self, *args):
        """Add a hex color to history in config.json colorHistory array.
        Keeps last 10, deduplicates. Args: hex color (e.g. #ff00aa)
        Returns the updated comma-separated color list.
        """
        if not args: return ""
        color = args[0].strip().lower()
        if not color.startswith("#"): color = "#" + color

        config_path = CONFIG_JSON
        try:
            with open(config_path, "r") as f:
                config = json.load(f)
        except Exception:
            return ""

        history = config.get("colorHistory", [])

        # Deduplicate — remove if already exists so it moves to front
        history = [c for c in history if c.lower() != color]
        history.insert(0, color)
        history = history[:10]

        config["colorHistory"] = history

        with open(config_path, "w") as f:
            json.dump(config, f, indent=4)

        return ",".join(history)

    @argfunc
    def getcolors(self, *args):
        """Get color history from config.json.
        Returns comma-separated hex colors.
        """
        config_path = CONFIG_JSON
        try:
            with open(config_path, "r") as f:
                config = json.load(f)
            return ",".join(config.get("colorHistory", []))
        except Exception:
            return ""

    @argfunc
    def clearcolors(self, *args):
        """Clear color history."""
        config_path = CONFIG_JSON
        try:
            with open(config_path, "r") as f:
                config = json.load(f)
            config["colorHistory"] = []
            with open(config_path, "w") as f:
                json.dump(config, f, indent=4)
        except Exception:
            pass
        return ""


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        post("Error: lacking --cmd <args>")
        sys.exit(1)

    cmd = args[0]

    # ── Batch mode ───────────────────────────────────────────────────────────
    # Usage: --batch -func1 arg1 arg2 -func2 arg1
    # Each -funcname starts a new command; args follow until the next -funcname
    # Returns one line per command: funcname:result
    if cmd == "--batch":
        utill = Utill()
        # Parse: split on tokens starting with "-" (single dash = command name)
        commands = []   # list of (funcname, [args])
        current_func = None
        current_args = []
        for token in args[1:]:
            if token.startswith("-") and not token.startswith("--"):
                if current_func is not None:
                    commands.append((current_func, current_args))
                current_func = token[1:]  # strip leading -
                current_args = []
            else:
                if current_func is not None:
                    current_args.append(token)
        if current_func is not None:
            commands.append((current_func, current_args))

        results = []
        for func, fargs in commands:
            try:
                result = utill.call(func, *fargs)
                if result is None:
                    result = ""
                elif isinstance(result, (list, tuple)):
                    result = ','.join([str(v) for v in result])
                elif isinstance(result, dict):
                    result = ','.join([f"{k}:{v}" for k, v in result.items()])
                else:
                    result = str(result)
                results.append(f"{func}:{result}")
            except Exception as e:
                results.append(f"{func}:error:{e}")

        post(" BATCHED ".join(results))
        sys.exit(0)

    # ── Single command mode ───────────────────────────────────────────────────
    if cmd:
        raw = False
        newline = None
        if cmd.startswith("--"):
            cmd = cmd.replace("--", "").strip()
            if cmd.endswith(':raw'):
                cmd = cmd[0:-4]
                raw = True
            elif cmd.endswith(":newline"):
                cmd        = cmd[0:-8]
                newline    = True, args[1]
                args       = args[1:]
            result = Utill().call(cmd, *args[1:])
            if result:
                if not raw and newline is None:
                    if isinstance(result, (list, tuple)):
                        post(','.join([str(v) for v in result]))
                    elif isinstance(result, dict):
                        post(','.join([f"{k}:{v}" for k, v in result.items()]))
                    else:
                        post(result)
                elif raw:
                    post(result)
                elif newline:
                    post(result.replace(newline[1], "\n"))
        else:
            post(f"Error: lacking --cmd <args>")