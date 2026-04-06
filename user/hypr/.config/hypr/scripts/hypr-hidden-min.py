#!/usr/bin/env python3
import argparse
import curses
import json
import os
import socket
import subprocess
import sys
import time
from typing import Dict, List, Optional, Tuple

POLL_INTERVAL_MS = 300

# Optional pinning:
# PIN_MONITOR_NAMES = {"1": "DP-1", "2": "HDMI-A-1"}
PIN_MONITOR_NAMES = {"1": None, "2": None}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "special_name",
        nargs="?",
        default="hidden",
        help="Name of the special workspace to inspect (default: hidden)",
    )
    parser.add_argument(
        "--close-on-focus-lost",
        action="store_true",
        help="Exit when this terminal window loses focus",
    )
    parser.add_argument(
        "--debug-focus-loss",
        action="store_true",
        help="Log focus-loss behavior without closing the window",
    )
    return parser.parse_args()


ARGS = parse_args()
SPECIAL_NAME = ARGS.special_name
CLOSE_ON_FOCUS_LOST = ARGS.close_on_focus_lost
DEBUG_FOCUS_LOSS = ARGS.debug_focus_loss
TRACK_FOCUS_LOSS = CLOSE_ON_FOCUS_LOST or DEBUG_FOCUS_LOSS
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEBUG_LOG_PATH = os.path.join(SCRIPT_DIR, "hypr-hidden-min-focus.log")


def run_json_info(command: str):
    proc = subprocess.run(
        ["hyprctl", "-j", command],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            proc.stderr.strip() or proc.stdout.strip() or f"hyprctl -j {command} failed"
        )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"Could not parse hyprctl JSON for '{command}': {exc}"
        ) from exc


def run_dispatch(dispatcher: str, argument: str) -> Tuple[bool, str]:
    proc = subprocess.run(
        ["hyprctl", "dispatch", dispatcher, argument],
        capture_output=True,
        text=True,
        check=False,
    )
    output = (proc.stdout + proc.stderr).strip()
    return proc.returncode == 0 and output == "ok", output or "unknown hyprctl error"


def shorten(text: str, width: int) -> str:
    text = (text or "").replace("\n", " ").replace("\r", " ")
    if width <= 0:
        return ""
    if len(text) <= width:
        return text
    if width == 1:
        return text[:1]
    return text[: width - 1] + "…"


def normalize_address(address: Optional[str]) -> str:
    normalized = (address or "").strip().lower()
    if normalized.startswith("0x"):
        normalized = normalized[2:]
    return normalized


def monitor_keymap(monitors: List[dict]) -> Dict[str, dict]:
    ordered = sorted(monitors, key=lambda m: (m.get("id", 999999), m.get("name", "")))
    by_name = {m.get("name"): m for m in ordered}

    mapping: Dict[str, dict] = {}

    for key in ("1", "2"):
        wanted = PIN_MONITOR_NAMES.get(key)
        if wanted and wanted in by_name:
            mapping[key] = by_name[wanted]

    remaining = [m for m in ordered if m not in mapping.values()]
    for key in ("1", "2"):
        if key not in mapping and remaining:
            mapping[key] = remaining.pop(0)

    return mapping


def get_state():
    monitors = run_json_info("monitors")
    clients = run_json_info("clients")
    wanted_ws = f"special:{SPECIAL_NAME}" if SPECIAL_NAME else "special"

    hidden = []
    for c in clients:
        ws = c.get("workspace") or {}
        if ws.get("name") != wanted_ws:
            continue

        hidden.append(
            {
                "address": c.get("address", ""),
                "class": c.get("class") or c.get("initialClass") or "?",
                "title": c.get("title") or c.get("initialTitle") or "",
            }
        )

    hidden.sort(
        key=lambda c: (
            (c["title"] or c["class"]).lower(),
            c["class"].lower(),
            c["address"],
        )
    )
    return monitor_keymap(monitors), hidden


def client_label(client: dict) -> str:
    title = client.get("title") or ""
    klass = client.get("class") or "?"
    return title if title else klass


def move_client_to_monitor_workspace(client: dict, monitor: dict) -> Tuple[bool, str]:
    active_ws = monitor.get("activeWorkspace") or {}
    ws_id = active_ws.get("id")
    mon_name = monitor.get("name", "?")

    if not isinstance(ws_id, int) or ws_id < 1:
        return False, f"Monitor {mon_name} has no usable active workspace id"

    ok, msg = run_dispatch(
        "movetoworkspacesilent", f"{ws_id},address:{client['address']}"
    )
    if ok:
        return True, f"Sent to {mon_name} -> {active_ws.get('name', ws_id)}"
    return False, msg


def close_client(client: dict) -> Tuple[bool, str]:
    ok, msg = run_dispatch("closewindow", f"address:{client['address']}")
    if ok:
        return True, f"Closed {client_label(client)}"
    return False, msg


def clickable_mask() -> int:
    return getattr(curses, "BUTTON1_PRESSED", 0)


def is_left_click(bstate: int) -> bool:
    pressed = getattr(curses, "BUTTON1_PRESSED", 0)
    return bool(pressed and (bstate & pressed))


def get_active_window():
    proc = subprocess.run(
        ["hyprctl", "-j", "activewindow"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return {}
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}


def get_parent_pid(pid: int) -> int:
    try:
        with open(f"/proc/{pid}/status", encoding="utf-8") as proc_status:
            for line in proc_status:
                if line.startswith("PPid:"):
                    return int(line.split()[1])
    except (OSError, ValueError, IndexError):
        pass
    return 0


def process_lineage() -> List[int]:
    lineage: List[int] = []
    pid = os.getpid()
    seen = set()

    while pid > 1 and pid not in seen:
        seen.add(pid)
        lineage.append(pid)
        pid = get_parent_pid(pid)

    return lineage


def find_own_window_address(timeout: float = 2.0) -> str:
    deadline = time.time() + timeout
    lineage = process_lineage()

    while time.time() < deadline:
        try:
            clients = run_json_info("clients")
        except RuntimeError:
            clients = []

        by_pid = {
            client.get("pid"): client.get("address")
            for client in clients
            if client.get("pid") and client.get("address")
        }
        for pid in lineage:
            addr = by_pid.get(pid)
            if addr:
                return addr

        aw = get_active_window()
        addr = aw.get("address")
        if addr and aw.get("pid") in lineage:
            return addr
        time.sleep(0.05)

    raise RuntimeError("Could not identify this window's Hyprland address")


def get_socket2_path() -> str:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not xdg:
        raise RuntimeError("Missing Hyprland socket environment")
    return f"{xdg}/hypr/{sig}/.socket2.sock"


def focus_client(address: str) -> Tuple[bool, str]:
    return run_dispatch("focuswindow", f"address:{address}")


def tui(stdscr):
    curses.curs_set(0)
    stdscr.keypad(True)
    stdscr.timeout(POLL_INTERVAL_MS)
    curses.mousemask(clickable_mask())
    curses.mouseinterval(0)

    selected = 0
    status = ""
    keymap: Dict[str, dict] = {}
    hidden: List[dict] = []
    row_map: Dict[int, int] = {}
    click_targets: Dict[Tuple[int, int], Tuple[str, int]] = {}

    evsock = None
    event_buf = ""
    my_addr = None
    my_addr_norm = ""
    focus_loss_armed = False
    startup_focus_deadline = 0.0
    startup_focus_expired = False
    last_focus_attempt = 0.0
    debug_lines: List[str] = []
    last_focus_miss_addr = ""

    def init_focus_log():
        if not TRACK_FOCUS_LOSS:
            return

        try:
            with open(DEBUG_LOG_PATH, "w", encoding="utf-8") as debug_file:
                debug_file.write(
                    f"{time.strftime('%Y-%m-%d %H:%M:%S')} start pid={os.getpid()} argv={sys.argv!r}\n"
                )
            if DEBUG_FOCUS_LOSS:
                debug_lines.append(f"log file: {DEBUG_LOG_PATH}")
        except OSError as exc:
            if DEBUG_FOCUS_LOSS:
                debug_lines.append(f"log file unavailable: {exc}")

    def log_focus(message: str):
        nonlocal debug_lines

        if not TRACK_FOCUS_LOSS:
            return

        entry = f"{time.strftime('%H:%M:%S')} {message}"
        if DEBUG_FOCUS_LOSS:
            debug_lines.append(entry)
            debug_lines = debug_lines[-8:]

        try:
            with open(DEBUG_LOG_PATH, "a", encoding="utf-8") as debug_file:
                debug_file.write(entry + "\n")
        except OSError:
            pass

    def refresh_state(status_message: Optional[str] = None):
        nonlocal keymap, hidden, selected, status

        old_selected_addr = None
        if hidden and 0 <= selected < len(hidden):
            old_selected_addr = hidden[selected]["address"]

        try:
            keymap, hidden = get_state()

            if old_selected_addr:
                for i, client in enumerate(hidden):
                    if client["address"] == old_selected_addr:
                        selected = i
                        break
                else:
                    selected = min(selected, len(hidden) - 1) if hidden else 0
            else:
                selected = min(selected, len(hidden) - 1) if hidden else 0

            if status_message is not None:
                status = status_message
        except Exception as exc:
            keymap = {}
            hidden = []
            selected = 0
            status = str(exc)

    def setup_focus_loss_tracking():
        nonlocal event_buf, evsock, focus_loss_armed
        nonlocal last_focus_attempt, my_addr, my_addr_norm
        nonlocal startup_focus_deadline, startup_focus_expired, status

        if not TRACK_FOCUS_LOSS:
            return

        try:
            my_addr = find_own_window_address()
            my_addr_norm = normalize_address(my_addr)
            evsock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            evsock.connect(get_socket2_path())
            evsock.setblocking(False)
            event_buf = ""
            startup_focus_deadline = time.time() + 1.5
            startup_focus_expired = False
            active_addr_norm = normalize_address(get_active_window().get("address"))
            focus_loss_armed = active_addr_norm == my_addr_norm
            log_focus(
                f"tracking self={my_addr_norm or '-'} active={active_addr_norm or '-'}"
            )
            if focus_loss_armed:
                log_focus("startup already focused; focus-loss close is armed")
            ok, msg = focus_client(my_addr)
            last_focus_attempt = time.time()
            log_focus(f"startup focus request {'ok' if ok else 'failed'}: {msg}")
            if not ok:
                status = f"focus-loss close waiting for focus: {msg}"
        except Exception as exc:
            status = f"focus-loss close disabled: {exc}"
            log_focus(f"focus-loss close disabled: {exc}")
            evsock = None
            my_addr = None

    def exit_if_unfocused():
        nonlocal event_buf, focus_loss_armed, last_focus_attempt, status
        nonlocal last_focus_miss_addr
        nonlocal startup_focus_expired

        if not TRACK_FOCUS_LOSS or evsock is None or my_addr is None:
            return

        while True:
            try:
                chunk = evsock.recv(4096)
            except BlockingIOError:
                break

            if not chunk:
                break

            event_buf += chunk.decode("utf-8", errors="ignore")

        lines = []
        if "\n" in event_buf:
            lines = event_buf.split("\n")
            event_buf = lines.pop()

        for line in lines:
            if not line:
                continue
            if line.startswith("activewindowv2>>"):
                new_addr = normalize_address(line.split(">>", 1)[1])
                if new_addr == my_addr_norm:
                    if not focus_loss_armed:
                        log_focus("focus confirmed via event; focus-loss close is armed")
                    focus_loss_armed = True
                    last_focus_miss_addr = ""
                elif focus_loss_armed:
                    last_focus_miss_addr = new_addr or "-"
                    log_focus(f"would kill on event focus change to {new_addr or '-'}")
                    if not DEBUG_FOCUS_LOSS:
                        run_dispatch("killwindow", f"address:{my_addr}")
                        raise SystemExit

        active_addr_norm = normalize_address(get_active_window().get("address"))
        if focus_loss_armed:
            if active_addr_norm and active_addr_norm != my_addr_norm:
                if last_focus_miss_addr != active_addr_norm:
                    last_focus_miss_addr = active_addr_norm
                    log_focus(
                        f"would kill on poll focus change to {active_addr_norm or '-'}"
                    )
                if not DEBUG_FOCUS_LOSS:
                    run_dispatch("killwindow", f"address:{my_addr}")
                    raise SystemExit
            return

        if active_addr_norm == my_addr_norm:
            focus_loss_armed = True
            last_focus_miss_addr = ""
            log_focus("focus confirmed via poll; focus-loss close is armed")
            return

        now = time.time()
        if now < startup_focus_deadline and now - last_focus_attempt >= 0.15:
            ok, msg = focus_client(my_addr)
            last_focus_attempt = now
            log_focus(
                f"startup focus retry {'ok' if ok else 'failed'}: {msg}"
                f" active={active_addr_norm or '-'}"
            )
            if not ok:
                status = f"focus-loss close waiting for focus: {msg}"
        elif not startup_focus_expired and now >= startup_focus_deadline:
            startup_focus_expired = True
            log_focus(
                "startup focus window expired without seeing focus"
                f" active={active_addr_norm or '-'}"
            )

    def do_send(target_key: str):
        nonlocal status
        if not hidden:
            status = "Nothing selected"
            return
        mon = keymap.get(target_key)
        if not mon:
            status = f"Monitor {target_key} unavailable"
            return
        client = hidden[selected]
        _, msg = move_client_to_monitor_workspace(client, mon)
        refresh_state(msg)

    def do_close():
        nonlocal status
        if not hidden:
            status = "Nothing selected"
            return
        client = hidden[selected]
        _, msg = close_client(client)
        refresh_state(msg)

    def put(y: int, x: int, text: str, attr: int = 0):
        h, w = stdscr.getmaxyx()
        if 0 <= y < h and x < w:
            stdscr.addnstr(y, x, text, max(0, w - x - 1), attr)

    def draw():
        nonlocal row_map, click_targets
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        row_map = {}
        click_targets = {}

        m1 = keymap.get("1")
        m2 = keymap.get("2")

        m1_name = m1.get("name", "1") if m1 else "1"
        m2_name = m2.get("name", "2") if m2 else "2"

        header = f"special:{SPECIAL_NAME}"
        if DEBUG_FOCUS_LOSS:
            header += " [focus-debug]"
        controls = f"  1:{m1_name}  2:{m2_name}  c:close  q:quit"
        put(0, 0, shorten(header + controls, w - 1), curses.A_BOLD)

        start_y = 2
        debug_rows = min(4, len(debug_lines)) if DEBUG_FOCUS_LOSS else 0
        footer_rows = 1 + debug_rows
        usable_rows = max(1, h - start_y - footer_rows)

        if not hidden:
            put(start_y, 0, "No hidden windows")
            if debug_rows:
                for offset, line in enumerate(debug_lines[-debug_rows:], start=1):
                    put(h - 1 - debug_rows + offset - 1, 0, shorten(line, w - 1), curses.A_DIM)
            if status:
                put(h - 1, 0, shorten(status, w - 1), curses.A_DIM)
            stdscr.refresh()
            return

        start = 0
        if selected >= usable_rows:
            start = selected - usable_rows + 1

        visible = hidden[start : start + usable_rows]

        for screen_row, client in enumerate(visible, start=start_y):
            idx = start + (screen_row - start_y)
            row_map[screen_row] = idx

            is_sel = idx == selected
            attr = curses.A_REVERSE if is_sel else 0

            label = client_label(client)
            m1_text = f"[{m1_name}]"
            m2_text = f"[{m2_name}]"
            close_text = "[close]"

            x_close = max(0, w - 1 - len(close_text))
            x_m2 = max(0, x_close - 1 - len(m2_text))
            x_m1 = max(0, x_m2 - 1 - len(m1_text))
            title_width = max(1, x_m1 - 1)

            title_text = shorten(label, title_width)

            put(screen_row, 0, " " * max(0, w - 1), attr)
            put(screen_row, 0, title_text, attr)
            put(screen_row, x_m1, m1_text, attr)
            put(screen_row, x_m2, m2_text, attr)
            put(screen_row, x_close, close_text, attr)

            for x in range(x_m1, x_m1 + len(m1_text)):
                click_targets[(screen_row, x)] = ("1", idx)
            for x in range(x_m2, x_m2 + len(m2_text)):
                click_targets[(screen_row, x)] = ("2", idx)
            for x in range(x_close, x_close + len(close_text)):
                click_targets[(screen_row, x)] = ("c", idx)

        if debug_rows:
            for offset, line in enumerate(debug_lines[-debug_rows:], start=1):
                put(h - 1 - debug_rows + offset - 1, 0, shorten(line, w - 1), curses.A_DIM)

        if status:
            put(h - 1, 0, shorten(status, w - 1), curses.A_DIM)

        stdscr.refresh()

    init_focus_log()
    refresh_state()
    setup_focus_loss_tracking()

    try:
        while True:
            exit_if_unfocused()

            if hidden:
                selected = max(0, min(selected, len(hidden) - 1))
            else:
                selected = 0

            draw()
            ch = stdscr.getch()

            exit_if_unfocused()

            if ch == -1:
                refresh_state()
                continue

            if ch in (ord("q"), 27):
                break
            elif ch in (curses.KEY_UP, ord("k")):
                if hidden:
                    selected = max(0, selected - 1)
            elif ch in (curses.KEY_DOWN, ord("j")):
                if hidden:
                    selected = min(len(hidden) - 1, selected + 1)
            elif ch == ord("\t"):
                if hidden:
                    selected = (selected + 1) % len(hidden)
            elif ch == curses.KEY_BTAB:
                if hidden:
                    selected = (selected - 1) % len(hidden)
            elif ch == ord("g"):
                selected = 0
            elif ch == ord("G"):
                if hidden:
                    selected = len(hidden) - 1
            elif ch == ord("r"):
                refresh_state("Refreshed")
            elif ch == ord("1"):
                do_send("1")
            elif ch == ord("2"):
                do_send("2")
            elif ch == ord("c"):
                do_close()
            elif ch == curses.KEY_MOUSE:
                try:
                    _id, mx, my, _z, bstate = curses.getmouse()
                except curses.error:
                    continue

                if not is_left_click(bstate):
                    continue

                target = click_targets.get((my, mx))
                if target:
                    action, idx = target
                    if 0 <= idx < len(hidden):
                        selected = idx
                        if action in ("1", "2"):
                            do_send(action)
                        elif action == "c":
                            do_close()
                    continue

                idx = row_map.get(my)
                if idx is not None and 0 <= idx < len(hidden):
                    selected = idx
    finally:
        if evsock is not None:
            evsock.close()


def main():
    try:
        curses.wrapper(tui)
    except KeyboardInterrupt:
        pass
    except SystemExit:
        pass


if __name__ == "__main__":
    main()
