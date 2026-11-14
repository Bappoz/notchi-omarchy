#!/usr/bin/python3
"""Deliver one private timer notification without putting its body in argv."""
import re
import sys
import backend


def notify(body):
    # Use the D-Bus connection directly, not a notify-send/busctl subprocess.
    from gi.repository import Gio, GLib
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    connection.call_sync(
        'org.freedesktop.Notifications', '/org/freedesktop/Notifications',
        'org.freedesktop.Notifications', 'Notify',
        GLib.Variant('(susssasa{sv}i)', (
            'Notchi', 0, '', 'Notchi', body, [], {}, -1)),
        GLib.VariantType.new('(u)'), Gio.DBusCallFlags.NONE, 6000, None)


def deliver(unit, sender=notify):
    if not re.fullmatch(r'omarchy-notch-focus-\d+', unit):
        raise ValueError('Invalid timer identifier')
    # Synchronize delivery with cancellation/replacement. An old or already
    # delivered identifier must not read/send the current timer's message.
    failure = None
    with backend.locked_state() as state:
        timer = state.get('timer', {})
        if timer.get('unit') != unit:
            return
        label = timer.get('label')
        if not isinstance(label, str) or len(label) > 180:
            raise ValueError('Invalid timer payload')
        try:
            sender(label)
        except Exception as error:
            failure = error
        state['timer'] = {}
    if failure is not None:
        raise failure


def main():
    try:
        if sys.argv[1:] == ['--check']:
            from gi.repository import Gio, GLib
        elif len(sys.argv) == 2:
            deliver(sys.argv[1])
        else:
            raise ValueError('Invalid request')
        return 0
    except Exception:
        # Never print provider errors or payloads into the service journal.
        print('Notchi timer delivery failed', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
