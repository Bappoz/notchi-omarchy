"""Provider details preserve token contracts and never expose raw credentials."""

import json, os, sys, tempfile, unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import backend


class AgentDetailTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        p = mock.patch.dict(os.environ, {"XDG_STATE_HOME": self.tmp.name})
        p.start()
        self.addCleanup(p.stop)
        self.folder = Path(self.tmp.name) / "omarchy/agents/usage"
        self.folder.mkdir(parents=True)

    def write(self, data):
        (self.folder / "codex.json").write_text(json.dumps(data))

    def test_real_model_fields_and_native_daily_token_contract(self):
        self.write(
            {
                "id": "codex",
                "name": "Codex",
                "todayTotalTokens": 1234,
                "recentDays": [{"date": "2026-11-11", "messageCount": 2468}],
                "modelUsage": {
                    "GPT": {
                        "inputTokens": 100,
                        "outputTokens": 50,
                        "cacheReadInputTokens": 400,
                        "cacheCreationInputTokens": 20,
                    }
                },
                "token": "DO_NOT_EXPOSE",
                "email": "DO_NOT_EXPOSE",
            }
        )
        d = backend.agent_detail("codex")["agentDetail"]
        self.assertEqual(d["todayTokens"], 1234)
        self.assertEqual(d["days"][0]["tokens"], 2468)
        self.assertEqual(d["models"][0]["total"], 570)
        self.assertNotIn("DO_NOT_EXPOSE", json.dumps(d))

    def test_unknown_is_not_zero_and_malformed_model_collection_is_safe(self):
        self.write({"id": "codex", "modelUsage": []})
        d = backend.agent_detail("codex")["agentDetail"]
        self.assertIsNone(d["todayTokens"])
        self.assertEqual(d["models"], [])
        self.write({"id": "codex", "modelUsage": {"GPT": {"inputTokens": "NaN"}}})
        self.assertIsNone(
            backend.agent_detail("codex")["agentDetail"]["models"][0]["total"]
        )

    def test_file_identity_and_partial_totals(self):
        self.write({"id": "other", "modelUsage": {"GPT": {"inputTokens": 10}}})
        detail = backend.agent_detail("codex")["agentDetail"]
        self.assertEqual(detail["id"], "codex")
        self.assertTrue(detail["models"][0]["partial"])

    def test_path_traversal_never_reads_a_record(self):
        for value in ["../../secret", "/tmp/secret", "codex.json"]:
            with self.assertRaises(ValueError):
                backend.agent_detail(value)
