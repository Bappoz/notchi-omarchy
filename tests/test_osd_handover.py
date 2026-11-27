import json
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JS_PATH = ROOT / "ui" / "IslandEvents.js"
SERVICE_PATH = ROOT / "Service.qml"
README_PATH = ROOT / "README.md"


class OsdHandoverTests(unittest.TestCase):
    def _eval_needs_osd_handover(self, payload):
        node = shutil.which("node")
        if not node:
            self.skipTest("node is not installed")
        source = JS_PATH.read_text(encoding="utf-8").replace(".pragma library", "")
        script = (
            source
            + "\nconst data = JSON.parse(process.argv[1]);\n"
            + "process.stdout.write(JSON.stringify(needsOsdHandover(data)));\n"
        )
        result = subprocess.run(
            [node, "-e", script, json.dumps(payload)],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )
        return json.loads(result.stdout)

    def test_needs_osd_handover_only_when_upgrade_leaves_builtin_osd_enabled(self):
        self.assertTrue(
            self._eval_needs_osd_handover(
                [
                    {"id": "omarchy.osd", "enabled": True, "clonedFrom": ""},
                    {"id": "bappoz.notch", "enabled": True, "clonedFrom": "omarchy.osd"},
                ]
            )
        )
        self.assertFalse(
            self._eval_needs_osd_handover(
                [
                    {"id": "omarchy.osd", "enabled": False, "clonedFrom": ""},
                    {"id": "bappoz.notch", "enabled": True, "clonedFrom": "omarchy.osd"},
                ]
            )
        )
        self.assertFalse(
            self._eval_needs_osd_handover(
                [
                    {"id": "omarchy.osd", "enabled": True, "clonedFrom": ""},
                    {"id": "bappoz.notch", "enabled": False, "clonedFrom": "omarchy.osd"},
                ]
            )
        )
        self.assertFalse(
            self._eval_needs_osd_handover(
                [
                    {"id": "omarchy.osd", "enabled": True, "clonedFrom": ""},
                    {"id": "bappoz.notch", "enabled": True, "clonedFrom": ""},
                ]
            )
        )
        self.assertFalse(self._eval_needs_osd_handover([]))
        self.assertFalse(self._eval_needs_osd_handover(None))

    def test_service_uses_fixed_omarchy_ipc_and_readme_has_no_manual_upgrade_commands(self):
        service = SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn('["omarchy-shell", "shell", "listPlugins"]', service)
        self.assertIn('["omarchy-shell", "shell", "enablePlugin", "bappoz.notch", "{}"]', service)
        self.assertIn('["omarchy-shell", "shell", "rescanPlugins"]', service)
        self.assertIn("Events.needsOsdHandover(plugins)", service)

        readme = README_PATH.read_text(encoding="utf-8")
        self.assertNotIn("omarchy restart shell", readme)
        self.assertNotIn("omarchy plugin enable bappoz.notch", readme)
