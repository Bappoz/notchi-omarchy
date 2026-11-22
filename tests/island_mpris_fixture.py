"""Synthetic player used by the isolated native UI test."""
from gi.repository import Gio, GLib

NAME = "org.mpris.MediaPlayer2.notchi_test"
PATH = "/org/mpris/MediaPlayer2"
BASE = "org.mpris.MediaPlayer2"
PLAYER = f"{BASE}.Player"
conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
state = "Playing"
xml = f"""
<node>
  <interface name="{BASE}">
    <property name="Identity" type="s" access="read"/>
  </interface>
  <interface name="{PLAYER}">
    <method name="PlayPause"/>
    <method name="Play"/>
    <method name="Pause"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="Position" type="x" access="read"/>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="Metadata" type="a{{sv}}" access="read"/>
    <property name="CanControl" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
  </interface>
</node>
"""


def get_property(_conn, _sender, _path, _interface, name):
    if name == "Identity":
        return GLib.Variant("s", "Test player")
    if name == "PlaybackStatus":
        return GLib.Variant("s", state)
    if name == "Metadata":
        return GLib.Variant("a{sv}", {
            "mpris:trackid": GLib.Variant("o", f"{PATH}/track1"),
            "xesam:title": GLib.Variant("s", "Night Transit"),
            "xesam:artist": GLib.Variant("as", ["Signal Garden"]),
        })
    if name == "Position":
        return GLib.Variant("x", 0)
    return GLib.Variant("b", name != "CanSeek")


def call(_conn, _sender, _path, _interface, method, _params, invocation):
    global state
    if method in ("PlayPause", "Play", "Pause"):
        state = "Paused" if method == "Pause" or (method == "PlayPause" and state == "Playing") else "Playing"
        conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                         GLib.Variant("(sa{sv}as)", (PLAYER, {"PlaybackStatus": GLib.Variant("s", state)}, [])))
    invocation.return_value(None)


for interface in Gio.DBusNodeInfo.new_for_xml(xml).interfaces:
    conn.register_object(PATH, interface, call, get_property, None)
conn.call_sync(
    "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
    "RequestName", GLib.Variant("(su)", (NAME, 4)), None, Gio.DBusCallFlags.NONE, 2000, None,
)
GLib.MainLoop().run()
