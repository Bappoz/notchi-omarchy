"""Native Qt input regression, isolated records and no camera/network/AI calls."""

import json, os, shutil, subprocess, tempfile, time, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(
    os.environ.get("NOTCHI_UI_TESTS") == "1", "Requires a Wayland session"
)
class DashboardRuntimeTests(unittest.TestCase):
    def test_all_opening_styles_accept_clicks_and_close_on_hover_exit(self):
        with tempfile.TemporaryDirectory(prefix="notchi-dashboard-") as directory:
            folder = Path(directory)
            shutil.copy2(ROOT / "tests/ui/dashboard.qml", folder / "shell.qml")
            (folder / "Plugin").symlink_to(ROOT, target_is_directory=True)
            for name in ["Commons", "Ui"]:
                (folder / name).symlink_to(
                    Path("/usr/share/omarchy/shell") / name, target_is_directory=True
                )

            def ipc(*args):
                r = subprocess.run(
                    [
                        "quickshell",
                        "ipc",
                        "--path",
                        str(folder / "shell.qml"),
                        "call",
                        "dashboard-test",
                        *args,
                    ],
                    capture_output=True,
                    text=True,
                    timeout=7,
                )
                self.assertEqual(r.returncode, 0, r.stderr)
                return r.stdout.strip()

            with (folder / "log").open("w") as log:
                env = {**os.environ, "XDG_STATE_HOME": str(folder / "state")}
                usage = folder / "state/omarchy/agents/usage"
                usage.mkdir(parents=True)
                (usage / "codex.json").write_text(
                    json.dumps(
                        {
                            "id": "codex",
                            "name": "Codex",
                            "todayTotalTokens": 12345,
                            "todayPrompts": 5,
                            "todaySessions": 2,
                            "recentDays": [
                                {"date": "2026-11-11", "messageCount": 54321}
                            ],
                            "modelUsage": {
                                "GPT": {"inputTokens": 100, "outputTokens": 50}
                            },
                        }
                    )
                )
                process = subprocess.Popen(
                    ["quickshell", "--path", str(folder / "shell.qml"), "--no-color"],
                    stdout=log,
                    stderr=log,
                    env=env,
                )
                fixture = None
                try:
                    end = time.monotonic() + 8
                    while True:
                        r = subprocess.run(
                            [
                                "quickshell",
                                "ipc",
                                "--path",
                                str(folder / "shell.qml"),
                                "call",
                                "dashboard-test",
                                "info",
                            ],
                            capture_output=True,
                            text=True,
                            timeout=3,
                        )
                        if r.returncode == 0:
                            break
                        if time.monotonic() > end or process.poll() is not None:
                            self.fail((folder / "log").read_text())
                        time.sleep(0.1)
                    initial = json.loads(ipc("island"))
                    self.assertEqual(initial["state"], "idle")
                    self.assertEqual(initial["y"], 8)
                    self.assertLess(initial["width"], 220)
                    self.assertEqual(json.loads(ipc("islandEvents")), {
                        "baseline": "idle", "finished": "done", "call": "call", "recent": "call"
                    })
                    self.assertEqual(json.loads(ipc("timerState")), {
                        "initial": "1:05", "finished": "timer", "stopwatch": "0:00"
                    })
                    self.assertEqual(json.loads(ipc("connectionStates")), {
                        "baseline": "", "wifi": "wifi", "headphones": "headphones", "recovered": ""
                    })
                    capture = os.environ.get("NOTCHI_CAPTURE_DIR")
                    destination = Path(capture) if capture else None
                    if destination:
                        destination.mkdir(parents=True, exist_ok=True)

                    def save(name):
                        if not destination:
                            return
                        path = destination / (name + ".png")
                        path.unlink(missing_ok=True)
                        ipc("save", str(path))
                        end = time.monotonic() + 3
                        while not path.exists():
                            self.assertLess(time.monotonic(), end, name)
                            time.sleep(0.05)

                    self.assertEqual(ipc("clickObject", "notch-mini-calendar-toggle"), "ok")
                    time.sleep(.45)
                    calendar = json.loads(ipc("calendarPeekState"))
                    self.assertTrue(calendar["visible"] and calendar["dot"] and calendar["centered"], calendar)
                    self.assertGreater(calendar["height"], 210)
                    save("updated-mini-calendar")
                    self.assertEqual(ipc("clickObject", "notch-mini-calendar-toggle"), "ok")
                    time.sleep(.3)
                    self.assertFalse(json.loads(ipc("calendarPeekState"))["visible"])

                    for sample, expected in [
                        ("volume", "volume"), ("camera", "camera"),
                        ("charging", "charging"), ("lowBattery", "lowBattery"), ("chargeFull", "chargeFull"),
                        ("bluetooth", "headphones"), ("voice", "voice"), ("brightness", ""),
                    ]:
                        hardware = json.loads(ipc("hardware", sample))
                        self.assertEqual(hardware["hud"], expected, hardware)
                        self.assertEqual(hardware["standalone"], sample == "brightness", hardware)
                        if sample == "volume":
                            self.assertEqual(hardware["level"], 62)
                        if expected:
                            time.sleep(.4)
                            self.assertEqual(ipc("hudState"), expected)
                            save("hardware-" + sample)
                    self.assertEqual(ipc("voiceTab"), "calendar")
                    ipc("clear")
                    ipc("prepare", "fluid")
                    time.sleep(0.4)
                    save("island-idle")
                    self.assertEqual(json.loads(ipc("activeMascots")), {
                        "providers": ["claude", "codex"], "clockCentered": True, "orbit": True
                    })
                    phase = float(ipc("orbitPhase"))
                    time.sleep(0.25)
                    self.assertNotEqual(float(ipc("orbitPhase")), phase)
                    save("island-agents")
                    for kind in ("wifi", "headphones"):
                        ipc("simulateConnection", kind)
                        time.sleep(0.4)
                        self.assertEqual(json.loads(ipc("island"))["state"], "alert")
                        save("island-" + kind)
                    ipc("clear")
                    ipc("prepare", "fluid")
                    for style in os.environ.get(
                        "NOTCHI_STYLES",
                        "fluid,bouncy,waterfall,snappy,pop,gentle,flip3D,depth3D,cube3D",
                    ).split(","):
                        ipc("prepare", style)
                        time.sleep(0.8)
                        self.assertEqual(ipc("hover"), "ok", style)
                        time.sleep(0.24)
                        self.assertTrue(
                            json.loads(ipc("info"))["opened"], style + " hover open"
                        )
                        ipc("enterSurface")
                        time.sleep(0.8)
                        self.assertEqual(json.loads(ipc("island"))["tab"], "quick")
                        self.assertEqual(ipc("click", "home"), "home", style)
                        time.sleep(0.4)
                        for tab in ["system", "daily", "weather", "agents"]:
                            self.assertEqual(
                                ipc("click", tab), tab, style + " click " + tab
                            )
                            time.sleep(0.3)
                        self.assertFalse(
                            json.loads(ipc("info"))["held"],
                            style + " navigation pinned hover",
                        )
                        ipc("leave")
                        time.sleep(1.1)
                        self.assertFalse(
                            json.loads(ipc("info"))["opened"], style + " hover exit"
                        )
                    ipc("open", "quick")
                    time.sleep(.7)
                    save("updated-quick")
                    self.assertEqual(ipc("clickObject", "quick-settings"), "ok")
                    time.sleep(.4)
                    self.assertEqual(json.loads(ipc("info"))["tab"], "settings")
                    self.assertEqual(ipc("clickObject", "settings-section-shortcuts"), "ok")
                    save("updated-settings")
                    self.assertEqual(ipc("clickObject", "settings-link-tools"), "ok")
                    time.sleep(.4)
                    self.assertEqual(json.loads(ipc("info"))["tab"], "tools")
                    ipc("open", "quick")
                    time.sleep(.4)
                    self.assertEqual(ipc("clickObject", "quick-settings"), "ok")
                    time.sleep(.4)
                    self.assertEqual(ipc("clickObject", "notch-settings"), "ok")
                    time.sleep(.4)
                    self.assertEqual(json.loads(ipc("info"))["tab"], "quick")
                    ipc("open", "daily")
                    time.sleep(0.5)
                    self.assertTrue(json.loads(ipc("info"))["held"])
                    self.assertEqual(ipc("click", "system"), "system")
                    self.assertTrue(json.loads(ipc("info"))["held"])
                    ipc("open", "daily")
                    time.sleep(0.3)
                    ipc("captureStatus")
                    self.assertEqual(ipc("add", "Persisted through the UI"), "ok")
                    end = time.monotonic() + 5
                    while json.loads(ipc("tasks"))["busy"]:
                        self.assertLess(
                            time.monotonic(), end, "Task pipe never completed"
                        )
                        time.sleep(0.1)
                    ipc("replayStatus")
                    self.assertEqual(json.loads(ipc("tasks"))["count"], 1)
                    saved = json.loads(
                        (folder / "state/omarchy-notch/state.json").read_text()
                    )
                    self.assertEqual(
                        saved["dailyTasks"][0]["title"], "Persisted through the UI"
                    )
                    ipc("editTask")
                    time.sleep(0.3)
                    self.assertEqual(int(ipc("emojiNote")), 1999)
                    self.assertEqual(int(ipc("longNote")), 2000)
                    self.assertEqual(
                        ipc("clickObject", "task-save-" + saved["dailyTasks"][0]["id"]),
                        "ok",
                    )
                    end = time.monotonic() + 5
                    while json.loads(ipc("tasks"))["busy"]:
                        self.assertLess(
                            time.monotonic(), end, "Note save did not finish"
                        )
                        time.sleep(0.05)
                    self.assertEqual(
                        len(
                            json.loads(
                                (folder / "state/omarchy-notch/state.json").read_text()
                            )["dailyTasks"][0]["note"]
                        ),
                        2000,
                    )
                    rows = [
                        {
                            "id": "a",
                            "title": "Review dashboard",
                            "note": "",
                            "priority": 1,
                            "done": False,
                            "day": "2026-11-11",
                        },
                        {
                            "id": "hidden",
                            "title": "Yesterday",
                            "note": "",
                            "priority": 1,
                            "done": True,
                            "day": "2020-01-01",
                        },
                        {
                            "id": "b",
                            "title": "Plan tomorrow",
                            "note": "",
                            "priority": 1,
                            "done": False,
                            "day": "2026-11-11",
                        },
                    ]
                    statePath = folder / "state/omarchy-notch/state.json"
                    state = json.loads(statePath.read_text())
                    state["dailyTasks"] = rows
                    statePath.write_text(json.dumps(state))
                    self.assertEqual(
                        json.loads(ipc("seedRows")),
                        ["a", "hidden", "b"],
                    )
                    time.sleep(0.2)
                    self.assertEqual(
                        ipc("clickObject", "task-down-a"), "ok", ipc("dailyState")
                    )
                    time.sleep(0.3)
                    self.assertEqual(
                        [
                            r["id"]
                            for r in json.loads(statePath.read_text())["dailyTasks"]
                        ],
                        ["hidden", "b", "a"],
                    )
                    ipc("open", "agents/detail-codex")
                    time.sleep(0.7)
                    self.assertEqual(
                        json.loads(ipc("detail")),
                        {
                            "busy": False,
                            "id": "codex",
                            "tokens": 12345,
                            "error": "",
                            "section": "detail",
                        },
                    )
                    self.assertEqual(ipc("clickObject", "quota-back"), "ok")
                    time.sleep(0.3)
                    self.assertEqual(ipc("clickObject", "provider-codex"), "ok")
                    time.sleep(0.4)
                    self.assertEqual(json.loads(ipc("detail"))["section"], "detail")
                    queue = json.loads(ipc("notices"))
                    self.assertEqual(queue, {"queued": 2, "active": ""})
                    self.assertEqual(ipc("releaseNotice"), "agent")
                    end = time.monotonic() + 8
                    while json.loads(ipc("noticeState"))["kind"] != "weather":
                        self.assertLess(
                            time.monotonic(),
                            end,
                            "Weather notice did not follow agent notice",
                        )
                        time.sleep(0.1)
                    self.assertEqual(
                        json.loads(ipc("noticeState")), {"kind": "weather", "queued": 0}
                    )
                    self.assertEqual(
                        json.loads(ipc("resumeNotice")), {"kind": "", "queued": 0}
                    )
                    ipc("reducedMotion")
                    ipc("open", "system")
                    time.sleep(0.1)
                    self.assertEqual(json.loads(ipc("info"))["progress"], 1)
                    ipc("simulateCall")
                    time.sleep(0.55)
                    self.assertEqual(json.loads(ipc("island"))["state"], "alert")
                    save("island-alert")
                    ipc("clear")
                    # The fake player owns a synthetic name on the disposable bus.
                    self.assertEqual(ipc("media"), "")
                    fixture = subprocess.Popen(
                        ["/usr/bin/python3", str(ROOT / "tests/island_mpris_fixture.py")],
                        stdout=log,
                        stderr=log,
                    )

                    def wait_media(expected):
                        end = time.monotonic() + 5
                        while ipc("media") != expected:
                            self.assertLess(time.monotonic(), end, expected)
                            time.sleep(0.1)

                    wait_media("Night Transit:true")
                    self.assertEqual(json.loads(ipc("island"))["state"], "compact")
                    save("island-playing")
                    ipc("open", "quick")
                    time.sleep(0.5)
                    save("island-media")
                    self.assertEqual(ipc("clickObject", "quick-play-pause"), "ok")
                    wait_media("Night Transit:false")
                    self.assertEqual(ipc("clickObject", "quick-play-pause"), "ok")
                    wait_media("Night Transit:true")

                finally:
                    if fixture:
                        fixture.terminate()
                        fixture.wait(timeout=3)
                    subprocess.run(
                        ["quickshell", "kill", "--path", str(folder / "shell.qml")],
                        capture_output=True,
                        timeout=5,
                    )
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    log.flush()
                    diagnostic = (folder / "log").read_text()
                    for error in [
                        "ReferenceError",
                        "SyntaxError",
                        "TypeError",
                        "Cannot assign",
                        "is not a type",
                        "is not a function",
                        "No such file",
                        "Binding loop",
                    ]:
                        self.assertNotIn(error, diagnostic, diagnostic)


if __name__ == "__main__":
    unittest.main()
