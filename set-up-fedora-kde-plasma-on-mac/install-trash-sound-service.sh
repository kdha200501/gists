#!/usr/bin/env bash

# --- Create a service to play trash sound -----------------------------------
mkdir -p ~/.config/systemd/user ~/.trash-sound

cat > ~/.config/systemd/user/trash-sound.service <<'EOF'
[Unit]
Description=Trash Sound
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 "%h/.trash-sound/trash-sound.py"
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment=PULSE_RUNTIME_PATH=/run/user/%U/pulse

[Install]
WantedBy=graphical-session.target
EOF

cat > ~/.trash-sound/trash-sound.py <<'EOF'
#!/usr/bin/env python3
"""
Monitor KDE trash events via D-Bus and play sounds using Qt Multimedia.

Events:
  - Item moved to trash  → plays "trash-put"
  - Trash emptied        → plays "trash-empty"

Requires: PyQt6 (or PySide6)  — see README.md for installation.
"""
import logging
import signal
import sys
from pathlib import Path

try:
    from PyQt6.QtCore import QCoreApplication, QObject, QUrl, pyqtSlot
    from PyQt6.QtDBus import QDBusConnection
    from PyQt6.QtMultimedia import QAudioOutput, QMediaPlayer
except ImportError:
    from PySide6.QtCore import QCoreApplication, QObject, QUrl, Slot as pyqtSlot
    from PySide6.QtDBus import QDBusConnection
    from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

AUDIO_EXTENSIONS = [".oga", ".ogg", ".wav"]
SOUND_DIRS = [
    Path.home() / ".local/share/sounds",
    Path("/usr/share/sounds"),
]
TRASH_FILES_DIR = Path.home() / ".local/share/Trash/files"
SOUND_THEME = "freedesktop"

# Maps event name → XDG sound name
SOUNDS = {
    "trash-put":   "trash-put",
    "trash-empty": "trash-empty",
}


# ---------------------------------------------------------------------------
# Startup resolution (sound files resolved once at launch)
# ---------------------------------------------------------------------------

def find_sound_file(sound_name: str) -> Path | None:
    for base in SOUND_DIRS:
        for ext in AUDIO_EXTENSIONS:
            for candidate in [
                base / SOUND_THEME / f"{sound_name}{ext}",
                base / SOUND_THEME / "stereo" / f"{sound_name}{ext}",
            ]:
                if candidate.exists():
                    return candidate
    return None


def resolve_sound_files() -> dict[str, Path]:
    """Resolve all event sound files once at startup."""
    resolved = {}
    for event, sound_name in SOUNDS.items():
        path = find_sound_file(sound_name)
        if path:
            resolved[event] = path
            log.info("Event '%s' → %s", event, path)
        else:
            log.warning("Sound file for event '%s' ('%s') not found.", event, sound_name)
    return resolved


def trash_item_count() -> int:
    try:
        return sum(1 for _ in TRASH_FILES_DIR.iterdir())
    except OSError:
        return 0


# ---------------------------------------------------------------------------
# Audio playback
# ---------------------------------------------------------------------------

# Keep strong references so players aren't garbage-collected mid-playback
_active_players: list = []


def play_sound(sound_file: Path) -> None:
    player = QMediaPlayer()
    audio_out = QAudioOutput()
    audio_out.setVolume(1.0)
    player.setAudioOutput(audio_out)
    player.setSource(QUrl.fromLocalFile(str(sound_file)))

    entry = {"player": player, "audio_out": audio_out}
    _active_players.append(entry)

    def on_state_changed(state):
        if state == QMediaPlayer.PlaybackState.StoppedState:
            if entry in _active_players:
                _active_players.remove(entry)

    player.playbackStateChanged.connect(on_state_changed)
    player.play()
    log.info("Playing '%s'.", sound_file.name)


# ---------------------------------------------------------------------------
# D-Bus signal receiver
# ---------------------------------------------------------------------------

class TrashMonitor(QObject):
    """Listens for org.kde.KDirNotify signals on the session bus."""

    def __init__(self, sound_files: dict[str, Path], parent=None):
        super().__init__(parent)
        self._sound_files = sound_files
        self._trash_count = trash_item_count()
        bus = QDBusConnection.sessionBus()

        bus.connect("", "", "org.kde.KDirNotify", "FilesAdded", self.on_files_added)
        bus.connect("", "", "org.kde.KDirNotify", "FilesRemoved", self.on_files_removed)

    @pyqtSlot(str)
    def on_files_added(self, url: str) -> None:
        if not url.startswith("trash:"):
            return
        new_count = trash_item_count()
        if new_count > self._trash_count:
            self._trash_count = new_count
            log.info("Item moved to trash (%d items total).", new_count)
            if sound_file := self._sound_files.get("trash-put"):
                play_sound(sound_file)
        else:
            self._trash_count = new_count

    @pyqtSlot("QStringList")
    def on_files_removed(self, urls: list) -> None:
        trash_physical = str(TRASH_FILES_DIR) + "/"
        trash_urls = [
            u for u in urls
            if u.startswith("trash:") or u.startswith("file://" + trash_physical)
        ]
        if not trash_urls:
            return
        self._trash_count = trash_item_count()
        if len(trash_urls) > 1:
            log.info("Trash emptied (%d items removed).", len(trash_urls))
        else:
            log.info("Item permanently deleted: %s", trash_urls[0])
        if sound_file := self._sound_files.get("trash-empty"):
            play_sound(sound_file)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    app = QCoreApplication(sys.argv)

    # Graceful shutdown on SIGTERM (how systemd stops the service)
    signal.signal(signal.SIGTERM, lambda *_: app.quit())

    log.info("Starting. Sound theme: %s", SOUND_THEME)

    sound_files = resolve_sound_files()
    if not sound_files:
        log.error("No sound files resolved. Exiting.")
        sys.exit(1)

    monitor = TrashMonitor(sound_files)  # noqa: F841 — must stay alive

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
EOF
chmod +x ~/.trash-sound/trash-sound.py

echo "Done. Next steps (manual):"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now trash-sound.service"
echo "  systemctl --user status trash-sound.service"
