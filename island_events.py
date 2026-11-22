"""Local adapters for transient island events."""

import hashlib
import json
import os
from pathlib import PurePath
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


def opaque_connection(kind, identifier):
    return hashlib.blake2s(f"{kind}:{identifier}".encode(), digest_size=12).hexdigest()


def wifi_profiles(output):
    connected = []
    for line in output.splitlines():
        uuid, separator, details = line.partition(":")
        if separator and details in ("802-11-wireless:activated", "wifi:activated"):
            connected.append(opaque_connection("wifi", uuid))
    return sorted(set(connected))


def bluetooth_headsets(objects):
    connected = []
    for path, interfaces in objects.items():
        device = interfaces.get("org.bluez.Device1", {})
        profiles = {uuid[4:8].lower() for uuid in device.get("UUIDs", [])}
        if device.get("Connected") and profiles & AUDIO_UUIDS:
            connected.append(opaque_connection("headphones", path))
    return sorted(set(connected))


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

    headphones = None
    try:
        from gi.repository import Gio, GLib
    except ImportError:
        return {"wifi": wifi, "headphones": headphones}
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        reply = bus.call_sync(
            "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
            None, None, Gio.DBusCallFlags.NO_AUTO_START, 1200, None,
        )
        headphones = bluetooth_headsets(reply.unpack()[0])
    except GLib.Error:
        pass
    return {"wifi": wifi, "headphones": headphones}


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
