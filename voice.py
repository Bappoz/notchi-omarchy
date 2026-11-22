"""Capture a short voice command and transcribe it with Superwhisper."""

import json
import math
import os
import selectors
import signal
import struct
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

RATE = 16000
MAX_SECONDS = 12
TRANSCRIBE_TIMEOUT = 70


def send(**event):
    print(json.dumps(event, ensure_ascii=False), flush=True)


def capture(recorder, path):
    """Write private PCM and emit its measured amplitude, never the samples."""
    deadline = time.monotonic() + MAX_SECONDS
    with selectors.DefaultSelector() as selector, wave.open(str(path), "wb") as output:
        selector.register(sys.stdin, selectors.EVENT_READ, "control")
        selector.register(recorder.stdout, selectors.EVENT_READ, "pcm")
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        pending = b""
        frames = 0
        while (timeout := deadline - time.monotonic()) > 0:
            for key, _ in selector.select(timeout):
                if key.data == "control":
                    return frames if sys.stdin.readline().strip() == "stop" else 0
                data = os.read(recorder.stdout.fileno(), 3200)
                if not data:
                    raise OSError("Audio input closed")
                pending += data
                if len(pending) < 1600:
                    continue
                size = len(pending) & ~1
                chunk, pending = pending[:size], pending[size:]
                output.writeframesraw(chunk)
                count = size // 2
                frames += count
                rms = math.sqrt(sum(value * value for (value,) in struct.iter_unpack("<h", chunk)) / count)
                send(level=min(1, round(rms / 4500, 3)))
        return frames


def superwhisper(*arguments, timeout=5):
    result = subprocess.run(
        ["superwhisper", *arguments], stdin=subprocess.DEVNULL,
        capture_output=True, timeout=timeout,
    )
    reply = json.loads(result.stdout)
    if not isinstance(reply, dict):
        raise ValueError("Invalid Superwhisper response")
    if result.returncode and not reply.get("error"):
        raise subprocess.CalledProcessError(result.returncode, result.args)
    return reply


def transcription(result):
    for key in ("text", "transcription", "inserted_text", "transcript"):
        value = result.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()[:256]
    return ""


def transcription_event(result):
    error = result.get("error")
    if error:
        detail = str(error).casefold()
        if "no speech" in detail or "no voice" in detail:
            return {"error": "empty"}
        if "read cloud audio" in detail or "read audio" in detail:
            return {"error": "audioUnreadable"}
        return {"error": "unavailable"}
    text = transcription(result)
    return {"text": text} if text else {"error": "empty"}


def transcribe(path):
    before = superwhisper("status")
    if before.get("phase") in ("recording", "transcribing", "processing"):
        return {"error": "busy"}

    reply = superwhisper("transcribe", str(path), timeout=TRANSCRIBE_TIMEOUT)
    if reply.get("error") or transcription(reply):
        return transcription_event(reply)
    if reply.get("ok") is False:
        return {"error": "unavailable"}

    # The Linux CLI can acknowledge the request before the daemon reads the
    # file. Keep the WAV open to the daemon until its own session completes.
    previous = before.get("session_id")
    session = reply.get("session_id")
    if type(session) is not int or session == previous:
        if type(previous) is not int:
            return {"error": "unavailable"}
        session = previous + 1

    deadline = time.monotonic() + TRANSCRIBE_TIMEOUT
    while time.monotonic() < deadline:
        state = superwhisper("status")
        result = state.get("last")
        if isinstance(result, dict) and result.get("session_id") == session:
            return transcription_event(result)
        active = state.get("session_id")
        if type(active) is int and active > session:
            return {"error": "busy"}
        time.sleep(.24)
    return {"error": "timeout"}


def voice():
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    with tempfile.TemporaryDirectory(prefix="notchi-voice-", dir=runtime) as directory:
        path = Path(directory) / "command.wav"
        config = superwhisper("audio", "show")
        device = config.get("effectiveDevice")
        command = ["pw-record", "--raw", "--format", "s16", "--rate", str(RATE), "--channels", "1"]
        if isinstance(device, str) and device and not device.startswith("-"):
            command.extend(("--target", device))
        with subprocess.Popen(
            [*command, "-"], stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        ) as recorder:
            try:
                frames = capture(recorder, path)
            finally:
                if recorder.poll() is None:
                    recorder.terminate()
                    try:
                        recorder.wait(timeout=1)
                    except subprocess.TimeoutExpired:
                        recorder.kill()
        if frames < RATE / 4:
            send(error="tooShort")
            return
        send(phase="processing")
        send(**transcribe(path))


def compositor_state(command):
    result = subprocess.run(["hyprctl", "-j", command], capture_output=True, timeout=.5, check=True)
    return json.loads(result.stdout)


def guide(classes):
    cursor = compositor_state("cursorpos")
    if not isinstance(cursor, dict) or not all(isinstance(cursor.get(axis), int) for axis in ("x", "y")):
        return
    for _ in range(24):
        window = compositor_state("activewindow")
        if any(str(window.get(key, "")).casefold() in classes for key in ("initialClass", "class")):
            x, y = window["at"]
            width, height = window["size"]
            if width > 0 and height > 0:
                send(start=cursor, target={"x": x + width // 2, "y": y + min(48, height // 2)})
            return
        time.sleep(.12)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda _signal, _frame: sys.exit(0))
    try:
        if sys.argv[1:2] == ["guide"]:
            guide({argument.casefold() for argument in sys.argv[2:] if argument})
        else:
            voice()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        if sys.argv[1:2] != ["guide"]:
            send(error="unavailable")
