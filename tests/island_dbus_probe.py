"""Use a disposable dbus-run-session to test passive desktop event delivery."""
import json
from pathlib import Path
import select
import subprocess

from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
NAME = "org.freedesktop.Notifications"
PATH = "/org/freedesktop/Notifications"
PRIVATE = "PRIVATE SYNTHETIC MESSAGE"


def verify():
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    reply = conn.call_sync(
        "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
        "RequestName", GLib.Variant("(su)", (NAME, 4)), None, Gio.DBusCallFlags.NONE, 2000, None,
    )
    assert reply.unpack() == (1,), "Run this probe in a disposable bus"
    args = "".join(f'<arg type="{kind}" direction="in"/>' for kind in ("s", "u", "s", "s", "s", "as", "a{sv}", "i"))
    node = Gio.DBusNodeInfo.new_for_xml(
        f'<node><interface name="{NAME}"><method name="Notify">{args}'
        '<arg type="u" direction="out"/></method></interface></node>'
    )
    received = []

    def notify(_conn, _sender, _path, _interface, _method, params, invocation):
        received.append(params.get_child_value(4).get_string())
        invocation.return_value(GLib.Variant("(u)", (41,)))

    conn.register_object(PATH, node.interfaces[0], notify, None, None)
    with subprocess.Popen(
        ["/usr/bin/python3", str(ROOT / "island_events.py")],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    ) as monitor:
        try:
            loop = GLib.MainLoop()
            replies = []
            deadline = GLib.timeout_add(5000, lambda: (loop.quit(), False)[1])

            def done(connection, result):
                replies.append(connection.call_finish(result).unpack())
                loop.quit()

            def send():
                conn.call(
                    NAME, PATH, NAME, "Notify",
                    GLib.Variant("(susssasa{sv}i)", (
                        "Vesktop", 0, "", "A contact is calling", PRIVATE,
                        [], {"category": GLib.Variant("s", "call.incoming")}, 3000,
                    )), None, Gio.DBusCallFlags.NONE, 2000, None, done,
                )
                return False

            GLib.timeout_add(400, send)
            loop.run()
            GLib.source_remove(deadline)
            assert replies == [(41,)] and received == [PRIVATE], (replies, received)
            assert select.select([monitor.stdout], [], [], 2)[0], "Monitor received no event"
            line = monitor.stdout.readline()
            assert json.loads(line) == {"kind": "call", "source": "Discord"}, line
            assert PRIVATE not in line
        finally:
            monitor.terminate()


if __name__ == "__main__":
    verify()
    print("PASS: native notification delivery coexists with a sanitized island event")
