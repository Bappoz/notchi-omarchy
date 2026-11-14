"""Run with dbus-run-session -- /usr/bin/python3 tests/timer_dbus_probe.py.
Uses an isolated notification bus and synthetic data, never the desktop bus.
"""
from pathlib import Path
import json,os,subprocess,sys,tempfile
from gi.repository import Gio,GLib
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='notchi-private-timer-') as folder:
    state=Path(folder)/'omarchy-notch';state.mkdir(mode=0o700)
    payload=state/'state.json';secret='SYNTHETIC confidential meeting 14:30'
    unit='omarchy-notch-focus-123'
    payload.write_text(json.dumps({'timer':{'unit':unit,'label':secret}}));payload.chmod(0o600)
    conn=Gio.bus_get_sync(Gio.BusType.SESSION,None)
    conn.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',('org.freedesktop.Notifications',0)),None,Gio.DBusCallFlags.NONE,5000,None)
    info=Gio.DBusNodeInfo.new_for_xml('<node><interface name="org.freedesktop.Notifications"><method name="Notify"><arg type="s" direction="in"/><arg type="u" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="as" direction="in"/><arg type="a{sv}" direction="in"/><arg type="i" direction="in"/><arg type="u" direction="out"/></method></interface></node>')
    received=[];process=None
    def call(connection,sender,path,interface,method,parameters,invocation):
        received.append(parameters.unpack()[4])
        assert received==[secret]
        assert secret.encode() not in Path(f'/proc/{process.pid}/cmdline').read_bytes()
        assert secret.encode() not in Path(f'/proc/{process.pid}/environ').read_bytes()
        invocation.return_value(GLib.Variant('(u)',(1,)))
    conn.register_object('/org/freedesktop/Notifications',info.interfaces[0],call,None,None)
    process=subprocess.Popen(['/usr/bin/python3',str(ROOT/'timer_notify.py'),unit],env={**os.environ,'XDG_STATE_HOME':folder},stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    loop=GLib.MainLoop()
    def tick():
        if process.poll() is not None:loop.quit();return False
        return True
    GLib.timeout_add(30,tick)
    def timeout():
        if process.poll() is None:process.kill()
        loop.quit();return False
    GLib.timeout_add_seconds(12,timeout);loop.run()
    out,err=process.communicate(timeout=3)
    assert process.returncode==0 and received==[secret],(process.returncode,err)
    assert secret.encode() not in out+err
    assert json.loads(payload.read_text())['timer']=={}
print('PASS: isolated D-Bus delivery; no body in argv/environment/log output; state cleared')
