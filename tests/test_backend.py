"""Pure backend regressions; never read desktop state or invoke external tools."""

import datetime as dt
import contextlib
import importlib.util
import io
import json
import math
from pathlib import Path
import signal
import subprocess
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock


BACKEND_PATH = Path(__file__).resolve().parents[1] / "backend.py"
backend = None
if BACKEND_PATH.exists():
    spec = importlib.util.spec_from_file_location("omarchy_notch_backend", BACKEND_PATH)
    backend = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(backend)


class BackendCase(unittest.TestCase):
    def function(self, name):
        self.assertIsNotNone(backend, f"Backend is missing: {BACKEND_PATH}")
        function = getattr(backend, name, None)
        self.assertTrue(callable(function), f"Backend function is missing: {name}")
        return function


class LocalPathTests(BackendCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.file = Path(self.directory.name) / "a file with spaces.txt"
        self.file.write_text("Local test fixture", encoding="utf-8")

    def test_accepts_existing_absolute_local_path(self):
        result = self.function("local_path")(str(self.file))
        self.assertEqual(Path(result), self.file.resolve())

    def test_accepts_percent_encoded_file_uri(self):
        result = self.function("local_path")(self.file.as_uri())
        self.assertEqual(Path(result), self.file.resolve())

    def test_accepts_localhost_file_uri(self):
        uri = self.file.as_uri().replace("file:///", "file://localhost/", 1)
        result = self.function("local_path")(uri)
        self.assertEqual(Path(result), self.file.resolve())

    def test_resolves_symlink_to_its_existing_target(self):
        link = self.file.parent / "link.txt"
        link.symlink_to(self.file)
        result = self.function("local_path")(str(link))
        self.assertEqual(Path(result), self.file.resolve())

    def test_rejects_remote_relative_missing_and_nul_paths(self):
        local_path = self.function("local_path")
        rejected = [
            "https://example.invalid/file.txt",
            "sftp://example.invalid/file.txt",
            "file://example.invalid" + str(self.file),
            "file://localhost.example.invalid" + str(self.file),
            "file://user@localhost" + str(self.file),
            "relative.txt",
            "./relative.txt",
            "file:relative.txt",
            str(self.file.parent / "missing.txt"),
            str(self.file) + "\x00suffix",
            "",
        ]
        for value in rejected:
            with self.subTest(value=repr(value)):
                try:
                    result = local_path(value)
                except (ValueError, OSError):
                    continue
                self.assertFalse(result, f"Rejected input yielded a usable path: {result!r}")


class LyricsTests(BackendCase):
    def test_sorts_lyrics_by_timestamp_and_preserves_text(self):
        result = self.function("parse_lrc")(
            "[ar:Example artist]\n[ti:Example song]\n"
            "[01:02.250]Second line\n[00:05.50]First line\n"
            "[00:06]An untimed fraction\nThis line has no timestamp\n"
        )
        self.assertEqual(result, [
            {"time": 5.5, "text": "First line"},
            {"time": 6.0, "text": "An untimed fraction"},
            {"time": 62.25, "text": "Second line"},
        ])

    def test_emits_one_line_for_each_timestamp_on_same_line(self):
        result = self.function("parse_lrc")("[00:10.00][00:20.125]Repeated lyric")
        self.assertEqual(result, [
            {"time": 10.0, "text": "Repeated lyric"},
            {"time": 20.125, "text": "Repeated lyric"},
        ])

    def test_ignores_metadata_and_malformed_timestamp_lines(self):
        result = self.function("parse_lrc")(
            "[al:Album]\n[by:Writer]\n[offset:50]\n"
            "[bad:time]Invalid\n[00:abc]Invalid\n"
        )
        self.assertEqual(result, [])

    def test_keeps_markup_shaped_lyrics_as_literal_text(self):
        lyric = '<img src="https://example.invalid/tracker">'
        self.assertEqual(self.function("parse_lrc")("[00:01.0]" + lyric), [
            {"time": 1.0, "text": lyric},
        ])


class CalendarTests(BackendCase):
    def assert_grid(self, year, month, first, last):
        result = self.function("calendar_grid")(year, month)
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 42)
        dates = [dt.date.fromisoformat(value) for value in result]
        self.assertEqual(dates[0].isoformat(), first)
        self.assertEqual(dates[-1].isoformat(), last)
        self.assertEqual(dates[0].weekday(), 0)
        self.assertTrue(all(right - left == dt.timedelta(days=1)
                            for left, right in zip(dates, dates[1:])))
        self.assertIn(dt.date(year, month, 1), dates)

    def test_includes_adjacent_months_across_year_boundary(self):
        self.assert_grid(2026, 1, "2025-12-29", "2026-02-08")

    def test_includes_february_29_in_leap_year(self):
        self.assert_grid(2024, 2, "2024-01-29", "2024-03-10")
        self.assertIn("2024-02-29", self.function("calendar_grid")(2024, 2))

    def test_sunday_month_start_still_uses_monday_first_grid(self):
        self.assert_grid(2026, 11, "2026-10-26", "2026-12-06")

    def test_month_starting_monday_uses_six_full_weeks(self):
        self.assert_grid(2021, 2, "2021-02-01", "2021-03-14")


class AgentTests(BackendCase):
    def test_quota_age_and_small_fraction_are_not_presented_as_live_full_quota(self):
        record={"id":"claude","limitsFetchedAt":(time.time()-900)*1000,"limits":[{"percent":.03}]}
        result=backend.normalize_agent(record)
        self.assertTrue(result["stale"])
        self.assertEqual(result["limits"][0]["percent"],3)
        record["limitsFetchedAt"]={"secret":"PRIVATE"}
        self.assertEqual(backend.normalize_agent(record)["fetchedAt"],0)

    def test_normalizes_fraction_percent_and_keeps_reset_timestamp(self):
        result = self.function("normalize_agent")({
            "id": "codex", "name": "Codex", "status": "ok",
            "limits": [{"label": "5h", "percent": 0.73,
                        "resetsAt": "2026-11-07T01:00:00Z"}],
        })
        self.assertEqual(result["id"], "codex")
        self.assertEqual(result["name"], "Codex")
        self.assertEqual(result["status"], "ok")
        self.assertEqual(len(result["limits"]), 1)
        limit = result["limits"][0]
        self.assertEqual(limit["label"], "5h")
        self.assertAlmostEqual(limit["percent"], 73)
        self.assertEqual(limit["resetsAt"], "2026-11-07T01:00:00Z")

    def test_clamps_out_of_range_percentages(self):
        result = self.function("normalize_agent")({
            "id": "example", "name": "Example", "status": "ok",
            "limits": [{"label": "Negative", "percent": -5},
                       {"label": "Too high", "percent": 137},
                       {"label": "Already percent", "percent": 45}],
        })
        limits = {entry["label"]: entry["percent"] for entry in result["limits"]}
        self.assertEqual(limits["Negative"], 0)
        self.assertEqual(limits["Too high"], 100)
        self.assertEqual(limits["Already percent"], 45)

    def test_does_not_return_credentials_accounts_or_arbitrary_input_fields(self):
        raw = {
            "id": "codex", "name": "Codex", "status": "ok",
            "credentials": {"token": "TEST_CREDENTIAL_DO_NOT_COPY"},
            "accounts": [{"email": "TEST_PRIVATE_ACCOUNT_DO_NOT_COPY"}],
            "extra": "TEST_EXTRA_FIELD_DO_NOT_COPY",
            "limits": [{"label": "5h", "percent": 0.5,
                        "token": "TEST_LIMIT_SECRET_DO_NOT_COPY"}],
        }
        result = self.function("normalize_agent")(raw)
        self.assertEqual(set(result), {"id", "name", "status", "limits", "stale", "note", "fetchedAt"})
        encoded = json.dumps(result)
        for marker in ("TEST_CREDENTIAL_DO_NOT_COPY", "TEST_PRIVATE_ACCOUNT_DO_NOT_COPY",
                       "TEST_EXTRA_FIELD_DO_NOT_COPY", "TEST_LIMIT_SECRET_DO_NOT_COPY"):
            self.assertNotIn(marker, encoded)

    def test_handles_malformed_limit_entries_without_losing_valid_entries(self):
        result = self.function("normalize_agent")({
            "id": "codex", "name": "Codex", "status": "ok",
            "limits": [None, "invalid", 37, [], {},
                       {"label": "Not a number", "percent": "invalid"},
                       {"label": "Nonfinite", "percent": float("nan")},
                       {"label": "Valid", "percent": 0.25}],
        })
        for entry in result["limits"]:
            self.assertIsInstance(entry, dict)
            self.assertIsInstance(entry["label"], str)
            self.assertIsInstance(entry["percent"], (int, float))
            self.assertTrue(math.isfinite(entry["percent"]))
            self.assertGreaterEqual(entry["percent"], 0)
            self.assertLessEqual(entry["percent"], 100)
        valid = [entry for entry in result["limits"] if entry["label"] == "Valid"]
        self.assertEqual(len(valid), 1)
        self.assertAlmostEqual(valid[0]["percent"], 25)


class StateCase(BackendCase):
    def setUp(self):
        self.function("read_json")
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        for name, value in {"HOME": self.home, "STATE": self.home / "state",
                            "DATA": self.home / "data"}.items():
            patcher = mock.patch.object(backend, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)


class ClipboardTests(StateCase):
    def setUp(self):
        super().setUp()
        self.image = self.home / "screenshot.png"
        self.image.write_bytes(b"fixture image bytes")
        self.history = [{"type": "text", "text": "Full text to copy"},
                        {"type": "image", "path": str(self.image), "mime": "image/png"}]
        backend.atomic_json(self.home / ".local/state/omarchy/clipboard-history.json", self.history)
        self.clipboard = None

    def fake_clipboard_command(self, argv, **kwargs):
        """Model the installed text/file helpers without accessing a clipboard."""
        program = Path(argv[0]).name
        if program == "omarchy-clipboard-paste-text":
            entry = self.history[int(argv[argv.index("--history-index") + 1])]
            if entry["type"] != "text":
                raise ValueError("Text helper refuses image entries")
            self.clipboard = ("text/plain", entry["text"].encode())
        elif program == "omarchy-clipboard-paste-file":
            self.clipboard = (argv[-2], Path(argv[-1]).read_bytes())
        elif program == "wl-copy":
            value = kwargs.get("input", b"")
            self.clipboard = (argv[argv.index("--type") + 1],
                              value.encode() if isinstance(value, str) else value)
        else:
            raise AssertionError(f"Unexpected external command: {program}")
        return ""

    def test_copy_text_history_entry_preserves_full_text(self):
        with mock.patch.object(backend, "run", side_effect=self.fake_clipboard_command):
            backend.clipboard_copy(0)
        self.assertEqual(self.clipboard, ("text/plain", b"Full text to copy"))

    def test_copy_image_history_entry_preserves_image_mime_and_bytes(self):
        with mock.patch.object(backend, "run", side_effect=self.fake_clipboard_command):
            backend.clipboard_copy(1)
        self.assertEqual(self.clipboard, ("image/png", b"fixture image bytes"))


class TimerTests(StateCase):
    def test_cancel_does_not_stop_a_unit_outside_notchi_namespace(self):
        backend.atomic_json(backend.STATE / "state.json", {
            "timer": {"unit": "unrelated-user-service", "end": 9999999999}})
        with mock.patch.object(backend, "run") as external:
            backend.timer_cancel()
        external.assert_not_called()
        self.assertEqual(backend.read_json(backend.STATE / "state.json")["timer"], {})

    def test_failed_scheduling_preserves_previous_timer(self):
        timer = {"unit": "omarchy-notch-focus-123", "end": 9999999999}
        backend.atomic_json(backend.STATE / "state.json", {"timer": timer})
        with mock.patch.object(backend, "run", side_effect=ValueError("Scheduling failed")):
            with self.assertRaises(ValueError):
                backend.timer_start(5, "Replacement")
        self.assertEqual(backend.read_json(backend.STATE / "state.json")["timer"], timer)

    def test_failed_previous_timer_stop_does_not_leave_two_active_alerts(self):
        old_unit = "omarchy-notch-focus-123"
        backend.atomic_json(backend.STATE / "state.json", {
            "timer": {"unit": old_unit, "end": 9999999999}})
        active_units = {old_unit}

        def simulate_command(argv, **kwargs):
            if argv[0] == "systemd-run":
                active_units.add(next(value.split("=", 1)[1] for value in argv
                                      if str(value).startswith("--unit=")))
                return subprocess.CompletedProcess(argv, 0, stdout="", stderr="")
            units = [str(value).removesuffix(".timer").removesuffix(".service")
                     for value in argv if str(value).endswith((".timer", ".service"))]
            if old_unit in units:
                return subprocess.CompletedProcess(argv, 1, stdout="", stderr="Stop failed")
            active_units.difference_update(units)
            return subprocess.CompletedProcess(argv, 0, stdout="", stderr="")

        def checked_command(argv, **kwargs):
            result = simulate_command(argv, **kwargs)
            if result.returncode:
                raise ValueError(result.stderr)
            return result.stdout

        with mock.patch.object(backend, "run", side_effect=checked_command), \
                mock.patch.object(backend.subprocess, "run", side_effect=simulate_command):
            try:
                backend.timer_start(5, "Replacement")
            except ValueError:
                pass
        self.assertLessEqual(len(active_units), 1,
                             "A failed replacement left old and new alerts active together")


class PortTests(BackendCase):
    def test_stale_port_selection_cannot_stop_any_process(self):
        self.function("stop_port")
        with mock.patch.object(backend, "ports", return_value={"ports": []}), \
                mock.patch.object(backend.os, "kill") as kill:
            with self.assertRaises(ValueError):
                backend.stop_port(4567, 3000)
        kill.assert_not_called()

    def test_another_users_process_cannot_be_stopped(self):
        self.function("stop_port")
        rows = {"ports": [{"pid": 4567, "port": 3000}]}
        with mock.patch.object(backend, "ports", return_value=rows), \
                mock.patch.object(backend.os, "getuid", return_value=1000), \
                mock.patch.object(backend.Path, "stat", return_value=SimpleNamespace(st_uid=0)), \
                mock.patch.object(backend.os, "kill") as kill:
            with self.assertRaises(ValueError):
                backend.stop_port(4567, 3000)
        kill.assert_not_called()

    def test_confirmed_current_user_listener_gets_termination_signal(self):
        self.function("stop_port")
        rows = {"ports": [{"pid": 4567, "port": 3000}]}
        with mock.patch.object(backend, "ports", return_value=rows), \
                mock.patch.object(backend.os, "getuid", return_value=1000), \
                mock.patch.object(backend.Path, "stat", return_value=SimpleNamespace(st_uid=1000)), \
                mock.patch.object(backend.os, "kill") as kill:
            backend.stop_port(4567, 3000)
        kill.assert_called_once_with(4567, signal.SIGTERM)


class MetricsTests(BackendCase):
    def test_cpu_excludes_duplicate_guest_counters_and_memory_uses_available(self):
        samples=iter(["cpu 100 0 100 800 0 0 0 0 400 0", "cpu 150 0 150 900 0 0 0 0 1200 0"])
        def read(path,*args,**kwargs):
            if str(path)=="/proc/meminfo":return "MemTotal: 1000 kB\nMemAvailable: 400 kB\nMemFree: 50 kB\n"
            if str(path)=="/proc/stat":return next(samples)
            raise AssertionError(path)
        with mock.patch.object(backend.Path,"read_text",read),mock.patch.object(backend.time,"sleep"):
            result=backend.metrics()
        self.assertEqual(result["cpu"],50)
        self.assertEqual(result["memory"],60)


class PowerSupplyTests(BackendCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.power = Path(self.directory.name)

    def battery(self, name, **fields):
        directory = self.power / name
        directory.mkdir()
        for key, value in {"type": "Battery", "capacity": 8, "status": "Discharging", **fields}.items():
            (directory / key).write_text(str(value))

    def test_notebook_battery_is_distinct_from_a_low_peripheral(self):
        self.battery("hidpp_battery_0", scope="Device", capacity=8)
        self.battery("BAT0", capacity=99, present=1, status="Not charging")
        rows = backend.batteries(self.power)
        summary = backend.system_battery(rows)
        self.assertEqual(summary["name"], "BAT0")
        self.assertEqual(summary["percent"], 99)
        self.assertFalse(summary["charging"])
        self.assertEqual(len(rows), 2)

    def test_no_system_battery_does_not_substitute_a_mouse(self):
        self.battery("hidpp_battery_0", scope="Device")
        self.assertIsNone(backend.system_battery(backend.batteries(self.power)))

    def test_multiple_internal_batteries_are_weighted_by_energy(self):
        self.battery("BAT0", scope="System", capacity=50, energy_now=500, energy_full=1000)
        self.battery("BAT1", scope="System", capacity=100, energy_now=3000, energy_full=3000, status="Charging")
        summary = backend.system_battery(backend.batteries(self.power))
        self.assertEqual(summary["percent"], 88)
        self.assertTrue(summary["charging"])

    def test_absent_and_invalid_batteries_are_skipped(self):
        self.battery("BAT0", present=0)
        self.battery("BAT1", capacity="unknown")
        self.assertEqual(backend.batteries(self.power), [])


class FilePreservationTests(StateCase):
    def test_clearing_shelf_preserves_files_and_other_state(self):
        originals = [self.home / "one.txt", self.home / "two.txt"]
        for original in originals:
            original.write_bytes(b"Keep original bytes")
        backend.shelf_add([str(path) for path in originals])
        with backend.locked_state() as state:
            state["settings"] = {"theme": "glass"}
            state["timer"] = {"unit": "existing-focus", "end": 9999999999}
        with mock.patch.object(backend.sys, "argv", ["backend.py", "shelf-clear"]), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(backend.main(), 0)
        result = backend.read_json(backend.STATE / "state.json")
        self.assertEqual(result["shelf"], [])
        self.assertEqual(result["settings"], {"theme": "glass"})
        self.assertEqual(result["timer"]["unit"], "existing-focus")
        for original in originals:
            self.assertEqual(original.read_bytes(), b"Keep original bytes")

    def test_removing_from_shelf_preserves_original_file(self):
        original = self.home / "original.txt"
        original.write_bytes(b"Original user-owned content")
        backend.shelf_add([str(original)])
        with mock.patch.object(backend.sys, "argv", ["backend.py", "shelf-remove", str(original)]), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(backend.main(), 0)
        self.assertEqual(original.read_bytes(), b"Original user-owned content")
        self.assertEqual(backend.read_json(backend.STATE / "state.json")["shelf"], [])




class ShareTests(StateCase):
    def test_sharing_opens_only_the_selected_file_in_localsend(self):
        file=self.home/'to-share.txt';file.write_text('fixture')
        with mock.patch.object(backend.sys,'argv',['backend.py','share',str(file)]),mock.patch.object(backend.shutil,'which',return_value='/usr/bin/localsend'),mock.patch.object(backend,'launch') as launch,contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(backend.main(),0)
        launch.assert_called_once_with(['localsend',str(file)])

if __name__ == "__main__":
    unittest.main()
