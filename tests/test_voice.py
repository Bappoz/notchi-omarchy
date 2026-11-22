"""Exercise audio streaming through the voice helper without a microphone or account."""

import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


class VoiceAdapterTests(unittest.TestCase):
    def test_streams_meter_and_transcribes_a_private_wav_after_stop(self):
        script = Path(__file__).resolve().parents[1] / "voice.py"
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            recorder = directory / "pw-record"
            recorder.write_text(f"""#!{sys.executable}
import os, struct, sys, time
assert sys.argv[-3:] == ["--target", "test-source", "-"]
while True:
    os.write(1, struct.pack("<h", 2200) * 1600)
    time.sleep(.1)
""")
            transcriber = directory / "superwhisper"
            transcriber.write_text(f"""#!{sys.executable}
import json, stat, sys, wave
from pathlib import Path
work = Path(__file__).parent
job = work / "job"
counter = work / "counter"
if sys.argv[1:] == ["audio", "show"]:
    print(json.dumps({{"effectiveDevice": "test-source"}}))
elif sys.argv[1] == "transcribe":
    assert len(sys.argv) == 3
    job.write_text(sys.argv[2])
    print(json.dumps({{"ok": True, "session_id": 5}}))
elif not job.exists():
    print(json.dumps({{"phase": "idle", "session_id": 4,
                      "last": {{"session_id": 4, "text": "A different utterance"}}}}))
elif not counter.exists():
    counter.touch()
    print(json.dumps({{"phase": "transcribing", "session_id": 5}}))
else:
    path = Path(job.read_text())
    assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700
    with wave.open(str(path)) as audio:
        assert audio.getframerate() == 16000 and audio.getnframes() >= 4000
    print(json.dumps({{"session_id": 5, "last": {{"session_id": 5, "text": "Abra o calendário"}}}}))
""")
            recorder.chmod(0o700)
            transcriber.chmod(0o700)
            with subprocess.Popen(
                [sys.executable, str(script)],
                env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}", "XDG_RUNTIME_DIR": str(directory)},
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
            ) as process, selectors.DefaultSelector() as ready:
                try:
                    ready.register(process.stdout, selectors.EVENT_READ)
                    for _ in range(4):
                        self.assertTrue(ready.select(3), "No volume samples")
                        meter = json.loads(process.stdout.readline())
                        self.assertGreater(meter["level"], 0)
                    rest, _ = process.communicate(input="stop\n", timeout=5)
                finally:
                    if process.poll() is None:
                        process.terminate()
            events = [json.loads(line) for line in rest.splitlines()]
            self.assertIn({"phase": "processing"}, events)
            self.assertIn({"text": "Abra o calendário"}, events)
            self.assertEqual(list(directory.glob("notchi-voice-*")), [])

    def test_service_audio_failure_is_not_reported_as_silence(self):
        from voice import transcription_event
        self.assertEqual(transcription_event({"error": "Cannot read cloud audio"}), {"error": "audioUnreadable"})
        self.assertEqual(transcription_event({"error": "No speech detected"}), {"error": "empty"})

    def test_does_not_guess_which_session_to_execute(self):
        from voice import transcribe

        for reply in ({"ok": True}, {"ok": True, "session_id": 4}):
            with self.subTest(reply=reply), patch("voice.superwhisper", side_effect=[
                {"phase": "idle", "session_id": 4}, reply,
            ]) as cli:
                self.assertEqual(transcribe(Path("/test/command.wav")), {"error": "unavailable"})
                self.assertEqual(cli.call_count, 2)
