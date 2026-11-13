import contextlib, json, tempfile, unittest, sys, time
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import daily


class DailyCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        patch = mock.patch.object(daily.local, "STATE", Path(self.tmp.name))
        patch.start()
        self.addCleanup(patch.stop)


class DailyTests(DailyCase):
    def test_create_reorder_complete_delete_and_undo_preserve_other_state(self):
        with daily.local.locked_state() as s:
            s["timer"] = {"end": 123}
        a = daily.update({"op": "add", "title": "One"})["tasks"][0]["id"]
        b = daily.update({"op": "add", "title": "Two"})["tasks"][1]["id"]
        r = daily.update({"op": "move", "id": b, "direction": -1})
        self.assertEqual(r["tasks"][0]["id"], b)
        r = daily.update({"op": "toggle", "id": a})
        self.assertTrue(next(x for x in r["tasks"] if x["id"] == a)["done"])
        daily.update({"op": "delete", "id": a})
        r = daily.update({"op": "undo"})
        self.assertEqual(len(r["tasks"]), 2)
        self.assertEqual(
            daily.local.read_json(daily.local.STATE / "state.json")["timer"],
            {"end": 123},
        )

    def test_input_validation(self):
        for data in [
            {"op": "add", "title": ""},
            {"op": "add", "title": "x" * 301},
            {"op": "color", "color": "javascript:evil"},
            {"op": "move", "id": "unknown", "direction": -1},
        ]:
            with self.assertRaises(ValueError):
                daily.update(data)


class WeatherTransitionTests(unittest.TestCase):
    def test_first_resume_and_duplicate_do_not_alert(self):
        s = {}
        w = {"temperature": 20, "humidity": 50, "code": 0}
        self.assertIsNone(daily.weather_transition(s, w, 1000, True))
        self.assertIsNone(daily.weather_transition(s, w, 1600, True))
        self.assertIsNone(daily.weather_transition(s, {**w, "code": 95}, 5000, True))

    def test_storm_and_dry_are_transitions_not_every_refresh(self):
        s = {}
        daily.weather_transition(
            s, {"temperature": 20, "humidity": 50, "code": 0}, 1000, True
        )
        e = daily.weather_transition(
            s, {"temperature": 20, "humidity": 50, "code": 95}, 1600, True
        )
        self.assertEqual(e["kind"], "storm")
        self.assertIsNone(
            daily.weather_transition(
                s, {"temperature": 20, "humidity": 50, "code": 95}, 2200, True
            )
        )
        e = daily.weather_transition(
            s, {"temperature": 20, "humidity": 20, "code": 0}, 2800, True
        )
        self.assertEqual(e["kind"], "dry")

    def test_locked_and_small_temperature_changes_are_silent(self):
        s = {}
        daily.weather_transition(
            s, {"temperature": 20, "humidity": 50, "code": 0}, 1000, True
        )
        self.assertIsNone(
            daily.weather_transition(
                s, {"temperature": 21, "humidity": 50, "code": 0}, 1600, True
            )
        )
        self.assertIsNone(
            daily.weather_transition(
                s, {"temperature": 26, "humidity": 50, "code": 0}, 2200, False
            )
        )


if __name__ == "__main__":
    unittest.main()


class WeatherCacheTests(DailyCase):
    def test_inactive_and_resume_do_not_replay_hazard(self):
        import integrations

        now = [1000]
        active = [True]
        w = {"temperature": 20, "humidity": 50, "code": 0}
        with mock.patch.object(
            daily.time, "time", side_effect=lambda: now[0]
        ), mock.patch.object(
            daily, "session_active", side_effect=lambda: active[0]
        ), mock.patch.object(
            integrations, "coordinates", return_value=(0, 0, "UTC")
        ), mock.patch.object(
            integrations, "weather", side_effect=lambda: {"weather": dict(w)}
        ) as fetch:
            self.assertIsNone(daily.weather_panel()["weatherAlert"])
            for tick in range(1060, 1600, 60):
                now[0] = tick
                daily.weather_panel()
            active[0] = False
            now[0] = 1600
            daily.weather_panel()
            self.assertEqual(fetch.call_count, 1)
            active[0] = True
            now[0] = 1660
            w["code"] = 95
            self.assertIsNone(daily.weather_panel()["weatherAlert"])
            now[0] = 2300
            w["code"] = 61
            self.assertIsNone(
                daily.weather_panel()["weatherAlert"],
                "A suspended timer must reset the baseline",
            )

    def test_location_change_resets_baseline_and_fetches_new_place(self):
        import integrations

        with mock.patch.object(
            daily.time, "time", return_value=1000
        ), mock.patch.object(
            daily, "session_active", return_value=True
        ), mock.patch.object(
            integrations, "coordinates", return_value=(0, 0, "UTC")
        ) as coords, mock.patch.object(
            integrations,
            "weather",
            return_value={"weather": {"temperature": 20, "humidity": 50, "code": 0}},
        ) as fetch:
            daily.weather_panel()
            coords.return_value = (1, 1, "UTC")
            self.assertIsNone(daily.weather_panel()["weatherAlert"])
            self.assertEqual(fetch.call_count, 2)

    def test_move_relative_to_visible_task_skips_hidden_history(self):
        rows = [
            daily.update({"op": "add", "title": str(i)})["tasks"][-1] for i in range(3)
        ]
        result = daily.update(
            {
                "op": "move",
                "id": rows[2]["id"],
                "direction": -1,
                "relativeId": rows[0]["id"],
            }
        )
        self.assertEqual([r["title"] for r in result["tasks"]], ["2", "0", "1"])


class SessionStateTests(unittest.TestCase):
    def setUp(self):
        patch = mock.patch.object(daily.Path, "glob", return_value=[])
        patch.start()
        self.addCleanup(patch.stop)

    def test_auto_session_without_environment_id(self):
        with mock.patch.dict(
            daily.os.environ, {"XDG_SESSION_ID": ""}
        ), mock.patch.object(
            daily.local, "run", return_value="Active=yes\nLockedHint=no\nIdleHint=no"
        ) as run:
            self.assertTrue(daily.session_active())
            self.assertEqual(run.call_args.args[0][2], "auto")

    def test_display_session_fallback(self):
        with mock.patch.dict(
            daily.os.environ, {"XDG_SESSION_ID": ""}
        ), mock.patch.object(
            daily.local,
            "run",
            side_effect=[
                ValueError("missing"),
                "3",
                "Active=yes\nLockedHint=no\nIdleHint=no",
            ],
        ):
            self.assertTrue(daily.session_active())

    def test_unknown_session_is_distinct_from_locked(self):
        with mock.patch.object(
            daily.local, "run", side_effect=ValueError("unavailable")
        ):
            self.assertIsNone(daily.session_active())
        with mock.patch.object(
            daily.local, "run", return_value="Active=yes\nLockedHint=yes\nIdleHint=no"
        ):
            self.assertFalse(daily.session_active())
