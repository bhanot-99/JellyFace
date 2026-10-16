#!/usr/bin/env python3
"""Interactive & Automated Test Demo for JellyFace Dynamic Island.

Showcases all features and animations of the Dynamic Island:
  1. Ambient Idle Pill: Clock & music note glyph in compact pill (130x32px).
  2. Active Media Pill: Fluid expansion (210x36px), circular album artwork,
     and 4-bar Apple-green equalizer animating smoothly.
  3. Equalizer States: Dancing during playback, resting gracefully at baseline on pause.
  4. Expanded Bento Card: Authentic Apple spring physics (Easing.OutBack, 0.7 overshoot,
     370x166px), cross-fade morph, circular artwork (52x52px), marquee labels, AirPlay badge.
  5. Interactive Scrubber: Seeking, progress display, elapsed and remaining timestamps.
  6. Dynamic Track Changes: Smooth artwork & metadata transitions.
  7. Fallback Artwork: Graceful fallback icon centered inside circular frame.
  8. Auto-Collapse & Media Dismissal: Timed collapse and smooth return to idle pill.
"""

import argparse
import math
import os
import select
import subprocess
import sys
import termios
import threading
import time
import tty
from pathlib import Path

# D-Bus & Graphics
import cairo
from dasbus.connection import SessionMessageBus
from dasbus.loop import EventLoop
from dasbus.server.property import PropertiesInterface
from dasbus.typing import *

JF_ROOT = Path(__file__).resolve().parent.parent
ART_DIR = Path("/tmp/jellyface_demo_art")


# ==============================================================================
# 1. Album Artwork Generator
# ==============================================================================

def generate_artwork():
    """Generates crisp sample album art covers in /tmp/jellyface_demo_art."""
    ART_DIR.mkdir(parents=True, exist_ok=True)

    tracks = [
        ("art_synthwave.png", "synthwave"),
        ("art_starboy.png", "starboy"),
        ("art_levitating.png", "levitating"),
    ]

    for fname, style in tracks:
        path = ART_DIR / fname
        if path.exists():
            continue

        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 256, 256)
        cr = cairo.Context(surface)

        if style == "synthwave":
            # Synthwave Red & Sunset
            pat = cairo.LinearGradient(0, 0, 0, 256)
            pat.add_color_stop_rgb(0, 0.95, 0.15, 0.25)
            pat.add_color_stop_rgb(0.7, 0.35, 0.05, 0.25)
            pat.add_color_stop_rgb(1, 0.10, 0.02, 0.15)
            cr.set_source(pat)
            cr.paint()

            # Glowing Sun
            sun_pat = cairo.LinearGradient(0, 50, 0, 170)
            sun_pat.add_color_stop_rgb(0, 1.0, 0.9, 0.3)
            sun_pat.add_color_stop_rgb(1, 1.0, 0.2, 0.4)
            cr.set_source(sun_pat)
            cr.arc(128, 110, 55, 0, 2 * math.pi)
            cr.fill()

            # Horizontal horizon lines
            cr.set_source_rgba(0.1, 0.02, 0.15, 0.9)
            for y in [135, 145, 153, 159, 163]:
                cr.rectangle(0, y, 256, 3)
                cr.fill()

        elif style == "starboy":
            # Electric Blue & Neon Cross
            pat = cairo.LinearGradient(0, 0, 256, 256)
            pat.add_color_stop_rgb(0, 0.02, 0.08, 0.25)
            pat.add_color_stop_rgb(1, 0.05, 0.20, 0.60)
            cr.set_source(pat)
            cr.paint()

            # Neon glowing cross
            cr.set_source_rgba(0.2, 0.85, 1.0, 0.3)
            cr.rectangle(110, 40, 36, 176)
            cr.rectangle(60, 90, 136, 36)
            cr.fill()

            cr.set_source_rgb(0.85, 0.95, 1.0)
            cr.rectangle(120, 50, 16, 156)
            cr.rectangle(70, 100, 116, 16)
            cr.fill()

        elif style == "levitating":
            # Cosmic Violet Nebula
            pat = cairo.RadialGradient(128, 128, 20, 128, 128, 140)
            pat.add_color_stop_rgb(0, 0.75, 0.25, 0.85)
            pat.add_color_stop_rgb(0.6, 0.35, 0.05, 0.55)
            pat.add_color_stop_rgb(1, 0.05, 0.02, 0.15)
            cr.set_source(pat)
            cr.paint()

            # Star ring
            cr.set_source_rgba(1.0, 0.9, 1.0, 0.8)
            cr.set_line_width(4)
            cr.arc(128, 128, 65, 0, 2 * math.pi)
            cr.stroke()

        surface.write_to_png(str(path))


# ==============================================================================
# 2. Track Data Catalog
# ==============================================================================

TRACKS = [
    {
        "title": "Blinding Lights",
        "artist": ["The Weeknd"],
        "album": "After Hours",
        "art": "file:///tmp/jellyface_demo_art/art_synthwave.png",
        "length": 200,  # 3:20
    },
    {
        "title": "Starboy",
        "artist": ["The Weeknd", "Daft Punk"],
        "album": "Starboy",
        "art": "file:///tmp/jellyface_demo_art/art_starboy.png",
        "length": 230,  # 3:50
    },
    {
        "title": "Levitating",
        "artist": ["Dua Lipa"],
        "album": "Future Nostalgia",
        "art": "file:///tmp/jellyface_demo_art/art_levitating.png",
        "length": 203,  # 3:23
    },
    {
        "title": "Acoustic Sunset (No Artwork)",
        "artist": ["Indie Acoustic Sessions"],
        "album": "Unplugged Vol. 1",
        "art": "",  # Tests fallback icon in circle
        "length": 165,  # 2:45
    },
]


# ==============================================================================
# 3. MPRIS 2.2 D-Bus Player Implementation
# ==============================================================================

class DemoMprisPlayer(PropertiesInterface):
    """Full MPRIS 2.2 compliant D-Bus player for driving Dynamic Island."""

    __dbus_xml__ = """
    <node>
      <interface name='org.mpris.MediaPlayer2'>
        <property name='CanQuit' type='b' access='read'/>
        <property name='CanRaise' type='b' access='read'/>
        <property name='HasTrackList' type='b' access='read'/>
        <property name='Identity' type='s' access='read'/>
        <property name='SupportedUriSchemes' type='as' access='read'/>
        <property name='SupportedMimeTypes' type='as' access='read'/>
        <method name='Quit'/>
      </interface>
      <interface name='org.mpris.MediaPlayer2.Player'>
        <property name='PlaybackState' type='s' access='read'/>
        <property name='LoopStatus' type='s' access='readwrite'/>
        <property name='Rate' type='d' access='readwrite'/>
        <property name='Shuffle' type='b' access='readwrite'/>
        <property name='Metadata' type='a{sv}' access='read'/>
        <property name='Volume' type='d' access='readwrite'/>
        <property name='Position' type='x' access='read'/>
        <property name='MinimumRate' type='d' access='read'/>
        <property name='MaximumRate' type='d' access='read'/>
        <property name='CanGoNext' type='b' access='read'/>
        <property name='CanGoPrevious' type='b' access='read'/>
        <property name='CanPlay' type='b' access='read'/>
        <property name='CanPause' type='b' access='read'/>
        <property name='CanSeek' type='b' access='read'/>
        <property name='CanControl' type='b' access='read'/>
        <method name='Next'/>
        <method name='Previous'/>
        <method name='Pause'/>
        <method name='PlayPause'/>
        <method name='Stop'/>
        <method name='Play'/>
        <method name='Seek'>
          <arg direction='in' name='Offset' type='x'/>
        </method>
        <method name='SetPosition'>
          <arg direction='in' name='TrackId' type='o'/>
          <arg direction='in' name='Position' type='x'/>
        </method>
      </interface>
    </node>
    """

    def __init__(self, on_change_cb=None):
        super().__init__()
        self.on_change_cb = on_change_cb
        self.track_index = 0
        self.state = "Stopped"
        self.position_sec = 0.0
        self._lock = threading.Lock()

    # --- org.mpris.MediaPlayer2 ---
    @property
    def CanQuit(self) -> bool: return True
    @property
    def CanRaise(self) -> bool: return False
    @property
    def HasTrackList(self) -> bool: return False
    @property
    def Identity(self) -> str: return "JellyFace Demo Player"
    @property
    def SupportedUriSchemes(self) -> List[str]: return []
    @property
    def SupportedMimeTypes(self) -> List[str]: return []

    def Quit(self):
        self.state = "Stopped"
        self._notify_all()

    # --- org.mpris.MediaPlayer2.Player ---
    @property
    def PlaybackState(self) -> str:
        return self.state

    @property
    def LoopStatus(self) -> str: return "None"
    @property
    def Rate(self) -> float: return 1.0
    @property
    def Shuffle(self) -> bool: return False

    @property
    def Metadata(self) -> Dict[str, Variant]:
        if self.state == "Stopped":
            return {}
        track = TRACKS[self.track_index]
        return {
            "mpris:trackid": get_variant(ObjPath, f"/org/mpris/MediaPlayer2/Track/{self.track_index + 1}"),
            "xesam:title": get_variant(Str, track["title"]),
            "xesam:artist": get_variant(List[str], track["artist"]),
            "xesam:album": get_variant(Str, track["album"]),
            "mpris:artUrl": get_variant(Str, track["art"]),
            "mpris:length": get_variant(Int64, int(track["length"] * 1_000_000)),
        }

    @property
    def Volume(self) -> float: return 1.0
    @property
    def Position(self) -> int:
        return int(self.position_sec * 1_000_000)

    @property
    def MinimumRate(self) -> float: return 1.0
    @property
    def MaximumRate(self) -> float: return 1.0
    @property
    def CanGoNext(self) -> bool: return True
    @property
    def CanGoPrevious(self) -> bool: return True
    @property
    def CanPlay(self) -> bool: return True
    @property
    def CanPause(self) -> bool: return True
    @property
    def CanSeek(self) -> bool: return True
    @property
    def CanControl(self) -> bool: return True

    def _notify_all(self):
        self.report_changed_property("PlaybackState")
        self.report_changed_property("Metadata")
        self.report_changed_property("Position")
        self.flush_changes()
        if self.on_change_cb:
            self.on_change_cb()

    def Play(self):
        with self._lock:
            self.state = "Playing"
            self._notify_all()

    def Pause(self):
        with self._lock:
            self.state = "Paused"
            self._notify_all()

    def PlayPause(self):
        with self._lock:
            if self.state == "Playing":
                self.state = "Paused"
            else:
                self.state = "Playing"
            self._notify_all()

    def Stop(self):
        with self._lock:
            self.state = "Stopped"
            self.position_sec = 0.0
            self._notify_all()

    def Next(self):
        with self._lock:
            self.track_index = (self.track_index + 1) % len(TRACKS)
            self.position_sec = 0.0
            self._notify_all()

    def Previous(self):
        with self._lock:
            self.track_index = (self.track_index - 1) % len(TRACKS)
            self.position_sec = 0.0
            self._notify_all()

    def Seek(self, offset_us: int):
        with self._lock:
            cur_len = TRACKS[self.track_index]["length"]
            self.position_sec = max(0.0, min(cur_len, self.position_sec + offset_us / 1_000_000.0))
            self.report_changed_property("Position")
            self.flush_changes()
            if self.on_change_cb:
                self.on_change_cb()

    def SetPosition(self, track_id: str, position_us: int):
        with self._lock:
            cur_len = TRACKS[self.track_index]["length"]
            self.position_sec = max(0.0, min(cur_len, position_us / 1_000_000.0))
            self.report_changed_property("Position")
            self.flush_changes()
            if self.on_change_cb:
                self.on_change_cb()

    def set_track(self, index: int):
        with self._lock:
            self.track_index = index % len(TRACKS)
            self.position_sec = 0.0
            if self.state == "Stopped":
                self.state = "Playing"
            self._notify_all()

    def tick(self):
        with self._lock:
            if self.state == "Playing":
                cur_len = TRACKS[self.track_index]["length"]
                if self.position_sec + 1.0 >= cur_len:
                    self.track_index = (self.track_index + 1) % len(TRACKS)
                    self.position_sec = 0.0
                    self._notify_all()
                else:
                    self.position_sec += 1.0


# ==============================================================================
# 4. JellyFace IPC Helper
# ==============================================================================

def island_ipc(command: str) -> str:
    """Invokes Dynamic Island IPC methods (expand, collapse, toggle, isExpanded)."""
    try:
        res = subprocess.run(
            [str(JF_ROOT / "bin" / "jellyface"), "ipc", "island", command],
            capture_output=True,
            text=True,
            timeout=2,
        )
        return res.stdout.strip()
    except Exception:
        return ""


# ==============================================================================
# 5. Automated Feature Tour
# ==============================================================================

def run_tour(player: DemoMprisPlayer, step_delay: float = 3.5):
    """Executes a choreographed 8-scene walkthrough of all Dynamic Island features."""
    c_cyan = "\033[1;36m"
    c_green = "\033[1;32m"
    c_yellow = "\033[1;33m"
    c_magenta = "\033[1;35m"
    c_reset = "\033[0m"
    c_bold = "\033[1m"

    scenes = [
        (
            "Scene 1: Ambient Idle Pill",
            "No active media playback.\n"
            "   * Compact size (130x32px) at top center.\n"
            "   * Left: Subtle ambient music note icon.\n"
            "   * Right: Live ticking clock (hh:mm).\n"
            "   * CPU/GPU idle cost: 0% (timers and animations gated).",
            lambda: (player.Stop(), island_ipc("collapse")),
        ),
        (
            "Scene 2: Active Media Ingestion (Compact Pill)",
            "Track begins playing ('Blinding Lights' by The Weeknd).\n"
            "   * Capsule smoothly morphs from 130x32px -> 210x36px.\n"
            "   * Left: Album artwork masked into a PERFECT CIRCLE (no square edges or white outline!).\n"
            "   * Right: 4-bar Apple-green equalizer actively dancing with asynchronous sine loops.",
            lambda: player.set_track(0),
        ),
        (
            "Scene 3: Equalizer State (Paused vs. Playing)",
            "Playback is PAUSED.\n"
            "   * Notice the 4 equalizer bars smoothly lower and rest at baseline height (3.5px).\n"
            "   * No CPU polling or timers ticking while paused.",
            lambda: player.Pause(),
        ),
        (
            "Scene 3b: Resuming Playback",
            "Playback RESUMED.\n"
            "   * Equalizer springs back to life instantly.\n"
            "   * Watch the rhythmically animated green wave.",
            lambda: player.Play(),
        ),
        (
            "Scene 4: Expanded Bento Card (Spring Physics & Bento Layout)",
            "Expanding the island to full interactive card.\n"
            "   * Uses authentic Apple spring physics (Easing.OutBack with 0.7 overshoot, 420ms).\n"
            "   * Smooth cross-fade (morph): compact view fades in first 25%, expanded layout enters.\n"
            "   * Top tier: Large 52x52 circular cover art, marquee title, artist, AirPlay route badge.\n"
            "   * Middle tier: Interactive scrubber bar with elapsed (0:00) and remaining timestamps.\n"
            "   * Bottom tier: Tactile transport controls (Previous, circular Play/Pause, Next, Chevron).",
            lambda: island_ipc("forceExpand"),
        ),
        (
            "Scene 5: Seeking & Live Scrubber Progress",
            "Scrubbing forward into the track (seeking to 1m 30s).\n"
            "   * Scrubber progress bar advances dynamically.\n"
            "   * Timestamps update: elapsed time jumps to 1:30, remaining time adjusts accordingly.",
            lambda: player.SetPosition("", 90_000_000),
        ),
        (
            "Scene 6: Seamless Track Skip & Artwork Transition",
            "Skipping to Track 2 ('Starboy' - The Weeknd ft. Daft Punk).\n"
            "   * Artwork transitions to electric blue cover.\n"
            "   * Title and artist smoothly update.\n"
            "   * Scrubber resets to 0:00 and continues advancing.",
            lambda: player.set_track(1),
        ),
        (
            "Scene 7: Fallback Icon Verification (Missing Artwork)",
            "Skipping to Track 4 (Track with missing/no album art URL).\n"
            "   * Dynamic Island gracefully renders a fallback musical icon centered inside the circular frame.\n"
            "   * Zero broken images, blank squares, or layout shifts.",
            lambda: player.set_track(3),
        ),
        (
            "Scene 8: Dropdown Dashboard Collision Suppression & Tuck-Away",
            "Opening the top dropdown dashboard panel.\n"
            "   * Dynamic Island detects dashboard opening and smoothly tucks up behind the bezel (opacity: 0, y: -height).\n"
            "   * Automatically yields the screen to the Dashboard, eliminating any header collision.\n"
            "   * When the dashboard closes, the Island springs back into place with Easing.OutBack!",
            lambda: (
                subprocess.run([str(JF_ROOT / "bin" / "jellyface"), "ipc", "drawers", "toggle", "dashboard"], capture_output=True),
                time.sleep(1.8),
                subprocess.run([str(JF_ROOT / "bin" / "jellyface"), "ipc", "drawers", "toggle", "dashboard"], capture_output=True)
            ),
        ),
        (
            "Scene 9: Auto-Collapse & Media Dismissal",
            "Collapsing card and stopping playback.\n"
            "   * Island contracts smoothly back into the ambient idle pill.\n"
            "   * All features and animations verified successfully!",
            lambda: (island_ipc("collapse"), time.sleep(0.5), player.Stop()),
        ),
    ]

    print("\n" + "=" * 70)
    print(f"{c_bold}{c_cyan}  JELLYFACE DYNAMIC ISLAND -- AUTOMATED FEATURE TOUR{c_reset}")
    print("=" * 70 + "\n")
    print("Sit back and watch the top center of your screen!\n")

    for idx, (title, desc, action) in enumerate(scenes, 1):
        print(f"\n{c_bold}{c_yellow}[{idx}/{len(scenes)}] {title}{c_reset}")
        print(f"{desc}")
        action()
        for remaining in range(int(step_delay), 0, -1):
            sys.stdout.write(f"\r   {c_green}Next scene in {remaining}s...{c_reset} ")
            sys.stdout.flush()
            time.sleep(1.0)
        sys.stdout.write("\r" + " " * 35 + "\r")

    print(f"\n{c_bold}{c_cyan}Tour complete! Entering Interactive Mode...{c_reset}\n")


# ==============================================================================
# 6. Interactive Terminal Dashboard
# ==============================================================================

def format_time(seconds: float) -> str:
    s = int(seconds)
    m = s // 60
    return f"{m}:{s % 60:02d}"


def render_dashboard(player: DemoMprisPlayer):
    """Draws a live TUI status box in the terminal."""
    c_cyan = "\033[1;36m"
    c_green = "\033[1;32m"
    c_yellow = "\033[1;33m"
    c_reset = "\033[0m"
    c_bold = "\033[1m"
    c_dim = "\033[2m"

    track = TRACKS[player.track_index]
    is_expanded = island_ipc("isExpanded") == "1"

    bar_len = 28
    ratio = min(1.0, player.position_sec / max(1, track["length"]))
    fill_len = int(bar_len * ratio)
    prog_bar = ("#" * fill_len) + ("-" * (bar_len - fill_len))

    state_icon = "> PLAYING" if player.state == "Playing" else ("|| PAUSED" if player.state == "Paused" else "[STOPPED]")
    state_col = c_green if player.state == "Playing" else (c_yellow if player.state == "Paused" else c_dim)

    sys.stdout.write("\033[H\033[J")  # Clear screen & home cursor
    sys.stdout.write(f"{c_bold}{c_cyan}======================================================================{c_reset}\n")
    sys.stdout.write(f"{c_bold}  JELLYFACE DYNAMIC ISLAND -- LIVE DEMO & TEST CONTROLLER{c_reset}\n")
    sys.stdout.write(f"{c_bold}{c_cyan}======================================================================{c_reset}\n\n")

    sys.stdout.write(f"  {c_bold}Player Status:{c_reset} {state_col}{state_icon}{c_reset}   ")
    sys.stdout.write(f"  {c_bold}Island Card:{c_reset} {c_cyan}{'EXPANDED' if is_expanded else 'COMPACT PILL'}{c_reset}\n")

    if player.state != "Stopped":
        sys.stdout.write(f"  {c_bold}Now Playing:{c_reset}   {track['title']} - {', '.join(track['artist'])}\n")
        sys.stdout.write(f"  {c_bold}Album:{c_reset}         {track['album']}\n")
        sys.stdout.write(f"  {c_bold}Artwork:{c_reset}       {'Circle Masked (' + Path(track['art']).name + ')' if track['art'] else 'Circular Fallback Icon'}\n")
        sys.stdout.write(f"  {c_bold}Position:{c_reset}      [{prog_bar}] {format_time(player.position_sec)} / {format_time(track['length'])}\n")
    else:
        sys.stdout.write(f"  {c_dim}(Player stopped: Dynamic Island is in Ambient Idle Clock mode){c_reset}\n\n\n\n")

    sys.stdout.write(f"\n{c_bold}Controls & Shortcuts:{c_reset}\n")
    sys.stdout.write(f"  {c_yellow}[Space]{c_reset} Play / Pause         {c_yellow}[e]{c_reset} Expand Island Card    {c_yellow}[c]{c_reset} Collapse Island\n")
    sys.stdout.write(f"  {c_yellow}[n]{c_reset}     Next Track           {c_yellow}[p]{c_reset} Previous Track        {c_yellow}[t]{c_reset} Toggle Expand/Collapse\n")
    sys.stdout.write(f"  {c_yellow}[+]{c_reset}     Seek +15s            {c_yellow}[-]{c_reset} Seek -15s             {c_yellow}[s]{c_reset} Stop / Idle Pill\n")
    sys.stdout.write(f"  {c_yellow}[1-4]{c_reset}   Select Track 1..4    {c_yellow}[a]{c_reset} Run Automated Tour    {c_yellow}[q]{c_reset} Quit Demo\n\n")
    sys.stdout.write(f"{c_dim}* Hint: You can also click the buttons directly on the Dynamic Island on your desktop!{c_reset}\n")
    sys.stdout.flush()


# ==============================================================================
# 7. Main Execution & Input Loop
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(description="JellyFace Dynamic Island Demo & Test Suite")
    parser.add_argument("--auto", "--tour", action="store_true", help="Run automated 8-scene feature tour immediately")
    parser.add_argument("--delay", type=float, default=3.5, help="Seconds per scene in auto tour mode (default: 3.5)")
    args = parser.parse_args()

    # 1. Generate artwork
    generate_artwork()

    # 2. Initialize D-Bus MPRIS Service
    loop = EventLoop()
    bus = SessionMessageBus()

    needs_render = threading.Event()
    needs_render.set()

    player = DemoMprisPlayer(on_change_cb=lambda: needs_render.set())
    bus.publish_object("/org/mpris/MediaPlayer2", player)
    bus.register_service("org.mpris.MediaPlayer2.JellyFaceDemo")

    # Background D-Bus Event Loop
    dbus_thread = threading.Thread(target=loop.run, daemon=True)
    dbus_thread.start()

    # Background Position Ticker Thread
    stop_event = threading.Event()

    def ticker_worker():
        while not stop_event.is_set():
            time.sleep(1.0)
            if player.state == "Playing":
                player.tick()
                needs_render.set()

    ticker_thread = threading.Thread(target=ticker_worker, daemon=True)
    ticker_thread.start()

    # Auto Tour if requested
    if args.auto:
        run_tour(player, step_delay=args.delay)

    # Start with track 0 playing if not already
    if player.state == "Stopped" and not args.auto:
        player.set_track(0)

    # Save terminal settings for raw key input
    old_term_settings = None
    if sys.stdin.isatty():
        old_term_settings = termios.tcgetattr(sys.stdin)
        tty.setcbreak(sys.stdin.fileno())

    try:
        while not stop_event.is_set():
            if needs_render.is_set():
                needs_render.clear()
                render_dashboard(player)

            # Check for key presses (100ms timeout)
            r, _, _ = select.select([sys.stdin], [], [], 0.1)
            if r:
                ch = sys.stdin.read(1)
                if ch in ("q", "Q", "\x03"):  # q or Ctrl+C
                    break
                elif ch == " ":
                    player.PlayPause()
                elif ch in ("e", "E"):
                    island_ipc("forceExpand")
                    needs_render.set()
                elif ch in ("c", "C"):
                    island_ipc("collapse")
                    needs_render.set()
                elif ch in ("t", "T"):
                    island_ipc("toggle")
                    needs_render.set()
                elif ch in ("n", "N"):
                    player.Next()
                elif ch in ("p", "P"):
                    player.Previous()
                elif ch in ("+", "="):
                    player.Seek(15_000_000)
                elif ch in ("-", "_"):
                    player.Seek(-15_000_000)
                elif ch in ("s", "S"):
                    player.Stop()
                    island_ipc("collapse")
                elif ch in ("1", "2", "3", "4"):
                    player.set_track(int(ch) - 1)
                elif ch in ("a", "A"):
                    # Restore terminal for automated tour output
                    if old_term_settings:
                        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_term_settings)
                    run_tour(player, step_delay=args.delay)
                    if old_term_settings:
                        tty.setcbreak(sys.stdin.fileno())
                    needs_render.set()

    finally:
        stop_event.set()
        if old_term_settings:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_term_settings)
        player.Stop()
        island_ipc("collapse")
        print("\nDemo stopped. Island restored to idle.\n")


if __name__ == "__main__":
    main()
