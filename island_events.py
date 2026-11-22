"""Local adapters for transient island events."""

import hashlib
import json
import os
from pathlib import Path, PurePath
import re
import shutil
import subprocess
import sys
import time


CALL_SUMMARY = re.compile(
    r"\b(incoming (?:voice |video )?call|is calling|chamada(?: de (?:voz|v[ií]deo))? recebida|"
    r"chamada de|está (?:te )?ligando|ligação recebida)\b",
    re.IGNORECASE,
)
TRANSFER_SUMMARY = re.compile(r"\b(?:om[ao]?drop|airdrop)\b", re.IGNORECASE)
NOTIFY_RULE = (
    "type='method_call',path='/org/freedesktop/Notifications',"
    "interface='org.freedesktop.Notifications',member='Notify'"
)


def omdrop_action(hint):
    if len(hint) > 8192:
        return False
    try:
        argv = json.loads(hint)
    except (ValueError, RecursionError):
        return False
    # Omdrop's receive toast uses the filename as title and its executable as
    # the first element of Omarchy's default action. Treat it as a label only.
    return (isinstance(argv, list) and len(argv) >= 3 and isinstance(argv[0], str)
            and PurePath(argv[0]).name == "omdrop" and argv[1:3] == ["act", "open"])


def classify(app_name, desktop_entry, category, summary, action=""):
    """Return fixed labels only. Notification text and identities stay out of QML."""
    identity = (app_name[:128] + " " + desktop_entry[:128]).lower()
    category = category[:96].lower()
    summary = summary[:256]
    if re.search(r"\bnotchi\b", identity):
        return None  # Timer completion is already handled by the service.
    if (TRANSFER_SUMMARY.search(identity) or TRANSFER_SUMMARY.match(summary)
            or ("omarchy-action" in identity and omdrop_action(action))):
        return "transfer", "Omdrop"
    if "localsend" in identity:
        return "transfer", "LocalSend"
    chat = next(
        (label for names, label in (
            (("whatsapp", "elecwhat"), "WhatsApp"),
            (("discord", "vesktop"), "Discord"),
        ) if any(name in identity for name in names)),
        None,
    )
    if category == "call.incoming" or (chat and CALL_SUMMARY.search(summary)):
        return "call", chat or "Desktop"
    if chat:
        return "chat", chat
    if category in ("transfer", "transfer.complete"):
        return "transfer", "Desktop"
    if category in ("device.error", "network.error", "system.error"):
        return "report", "Desktop"
    return "notification", "Desktop"


# A2DP sink, HSP headset, HFP hands-free and LE Audio unicast capability.
AUDIO_UUIDS = {"110b", "1108", "111e", "184e"}
EARBUD_NAME = re.compile(r"\b(?:airpods|earbuds?|\w*buds|tws|wave beam|tune beam|live beam|wf[- ]\w+)\b", re.I)


def opaque_connection(kind, identifier):
    return hashlib.blake2s(f"{kind}:{identifier}".encode(), digest_size=12).hexdigest()


def wifi_profiles(output):
    connected = []
    for line in output.splitlines():
        uuid, separator, details = line.partition(":")
        if separator and details in ("802-11-wireless:activated", "wifi:activated"):
            connected.append(opaque_connection("wifi", uuid))
    return sorted(set(connected))


def bluetooth_devices(objects):
    connected = {}
    for path, interfaces in objects.items():
        device = interfaces.get("org.bluez.Device1", {})
        if not device.get("Connected"):
            continue
        profiles = {uuid[4:8].lower() for uuid in device.get("UUIDs", [])}
        icon = device.get("Icon", "")
        audio = bool(profiles & AUDIO_UUIDS) or icon in ("audio-headset", "audio-headphones")
        identifier = opaque_connection("bluetooth", path)
        percentage = interfaces.get("org.bluez.Battery1", {}).get("Percentage")
        batteries = [{"label": "device", "level": percentage}] if (
            type(percentage) is int and 0 <= percentage <= 100
        ) else []
        name = str(device.get("Alias") or device.get("Name") or "")[:100]
        model = str(device.get("Name") or name)
        connected[identifier] = {
            "name": name, "audio": audio, "batteries": batteries,
            "inEar": audio and bool(EARBUD_NAME.search(model)),
        }
    return connected


def bluetooth_headsets(objects):
    return sorted(device_id for device_id, device in bluetooth_devices(objects).items() if device["audio"])


def pipewire_camera(objects):
    for node in objects:
        info = node.get("info") or {}
        props = info.get("props") or {}
        if (node.get("type") == "PipeWire:Interface:Node" and info.get("state") == "running"
                and props.get("media.class") == "Video/Source"
                and props.get("device.api") in ("v4l2", "libcamera")):
            return True
    return False


def camera_in_use():
    """Read graph and descriptor metadata without opening the camera."""
    try:
        result = subprocess.run(["pw-dump"], capture_output=True, timeout=1.2, check=True)
        if pipewire_camera(json.loads(result.stdout)):
            return True
    except (OSError, ValueError, subprocess.SubprocessError):
        pass

    # V4L2 applications such as browsers can bypass PipeWire. Ignore the
    # descriptor held by the graph manager and devices used only for metadata.
    cameras = set()
    for device in Path("/sys/class/video4linux").glob("video*"):
        try:
            is_capture = (device / "index").read_text().strip() == "0"
            if is_capture and device.resolve().is_relative_to("/sys/devices/virtual"):
                continue
            if is_capture:
                cameras.add("/dev/" + device.name)
        except OSError:
            continue
    if not cameras:
        return False
    for process in Path("/proc").iterdir():
        if not process.name.isdecimal():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            if (process / "comm").read_text().strip().startswith(("pipewire", "wireplumber")):
                continue
            for descriptor in (process / "fd").iterdir():
                try:
                    if os.readlink(descriptor) in cameras:
                        return True
                except OSError:
                    continue
        except OSError:
            continue
    return False


def connections():
    wifi = None
    try:
        result = subprocess.run(
            ["nmcli", "--terse", "--fields", "UUID,TYPE,STATE", "connection", "show", "--active"],
            env={**os.environ, "LC_ALL": "C"}, capture_output=True, text=True, timeout=2, check=True,
        )
        wifi = wifi_profiles(result.stdout)
    except (OSError, subprocess.SubprocessError):
        pass

    devices = None
    try:
        from gi.repository import Gio, GLib
    except ImportError:
        return {"wifi": wifi, "devices": devices}
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        reply = bus.call_sync(
            "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
            None, None, Gio.DBusCallFlags.NO_AUTO_START, 1200, None,
        )
        devices = bluetooth_devices(reply.unpack()[0])
    except GLib.Error:
        pass
    return {"wifi": wifi, "devices": devices}


def session_available():
    from daily import session_active

    if session_active() is not True:
        return False
    if shutil.which("omarchy-hyprland-session-locked"):
        try:
            return subprocess.run(
                ["omarchy-hyprland-session-locked"], timeout=2, check=False,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            ).returncode != 0
        except (OSError, subprocess.TimeoutExpired):
            return False
    return True


def monitor(Gio, GLib):
    bus = Gio.DBusConnection.new_for_address_sync(
        Gio.dbus_address_get_for_bus_sync(Gio.BusType.SESSION, None),
        Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT
        | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
        None, None,
    )
    loop = GLib.MainLoop()
    bus.connect("closed", lambda *_: loop.quit())
    last_sent = {}

    def receive(_connection, message, incoming, _data):
        if not incoming or message.get_message_type() != Gio.DBusMessageType.METHOD_CALL:
            return message
        if (message.get_interface(), message.get_member(), message.get_path()) == (
            "org.freedesktop.Notifications", "Notify", "/org/freedesktop/Notifications"
        ):
            body = message.get_body()
            if body and body.get_type_string() == "(susssasa{sv}i)":
                hints = body.get_child_value(6)
                entry = hints.lookup_value("desktop-entry", GLib.VariantType.new("s"))
                category = hints.lookup_value("category", GLib.VariantType.new("s"))
                action = hints.lookup_value("omarchy-exec-argv", GLib.VariantType.new("s"))
                event = classify(
                    body.get_child_value(0).get_string(), entry.get_string() if entry else "",
                    category.get_string() if category else "", body.get_child_value(3).get_string(),
                    action.get_string() if action else "",
                )
                now = time.monotonic()
                if event and now - last_sent.get(event, float("-inf")) >= 2:
                    last_sent[event] = now
                    print(json.dumps({"kind": event[0], "source": event[1]}), flush=True)
        # A monitor must never reply to calls destined for the actual daemon.
        return None

    bus.add_filter(receive, None)
    bus.call_sync(
        "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus.Monitoring", "BecomeMonitor",
        GLib.Variant("(asu)", ([NOTIFY_RULE], 0)), None,
        Gio.DBusCallFlags.NONE, 3000, None,
    )
    loop.run()


if __name__ == "__main__":
    if sys.argv[1:] == ["connections"]:
        print(json.dumps(connections()))
        sys.exit(0)
    if sys.argv[1:] == ["camera"]:
        print(json.dumps(camera_in_use()))
        sys.exit(0)
    if sys.argv[1:] == ["session"]:
        sys.exit(0 if session_available() else 1)
    try:
        from gi.repository import Gio, GLib
    except ImportError:
        sys.exit(1)
    try:
        monitor(Gio, GLib)
    except (GLib.Error, OSError):
        sys.exit(1)
