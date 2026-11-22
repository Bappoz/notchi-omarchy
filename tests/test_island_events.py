import unittest

from island_events import bluetooth_headsets, classify, wifi_profiles


class NotificationAdapterTests(unittest.TestCase):
    def test_call_category_and_supported_clients(self):
        self.assertEqual(classify("Vesktop", "", "call.incoming", "private"), ("call", "Discord"))
        self.assertEqual(classify("ElecWhat", "", "", "Chamada de vídeo recebida"), ("call", "WhatsApp"))
        self.assertEqual(classify("Chromium", "", "", "Someone is calling"), ("notification", "Desktop"))

    def test_transfer_names_and_category(self):
        self.assertEqual(classify("omarchy", "", "", "Omdrop: received a file"), ("transfer", "Omdrop"))
        self.assertEqual(classify("omadrop", "", "", "private"), ("transfer", "Omdrop"))
        self.assertEqual(classify("LocalSend", "", "", "private"), ("transfer", "LocalSend"))

    def test_omdrop_receive_toast_uses_filename_as_title(self):
        self.assertEqual(classify(
            "omarchy-action", "", "", "incoming.png",
            '["/opt/omdrop/bin/omdrop","act","open","/private/incoming.png"]',
        ), ("transfer", "Omdrop"))
        self.assertEqual(classify(
            "omarchy-action", "", "", "incoming.png", '{"argv":"omdrop"}',
        ), ("notification", "Desktop"))

    def test_plain_messages_and_timer_do_not_leak_content(self):
        self.assertEqual(classify("", "discord", "", "private sender"), ("chat", "Discord"))
        self.assertEqual(classify("my build", "", "system.error", "private path"), ("report", "Desktop"))
        self.assertIsNone(classify("Notchi", "", "", "private focus message"))


class ConnectionAdapterTests(unittest.TestCase):
    def test_wifi_filters_activation_and_connection_type(self):
        active = wifi_profiles("office:802-11-wireless:activated\n")
        self.assertEqual(len(active), 1)
        self.assertNotIn("office", active)
        self.assertEqual(wifi_profiles(
            "ethernet:802-3-ethernet:activated\ntry:802-11-wireless:activating\n"
            "office:802-11-wireless:activated\n"
        ), active)

    def test_bluez_filters_audio_and_connected_state(self):
        def device(connected, uuid):
            return {"org.bluez.Device1": {
                "Connected": connected,
                "UUIDs": ["0000" + uuid + "-0000-1000-8000-00805f9b34fb"],
            }}
        self.assertEqual(len(bluetooth_headsets({
            "/Headset": device(True, "110B"),
            "/Earbuds": device(True, "184e"),
            "/Keyboard": device(True, "1124"),
            "/Disconnected": device(False, "111e"),
        })), 2)
