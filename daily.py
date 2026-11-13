"""Local daily tasks and conservative, deduplicated weather transition policy."""

import datetime as dt
import hashlib
import json
import math
import os
import re
import subprocess
import time
import uuid
from pathlib import Path

import backend as local

COLORS = ["#88c8ae", "#b5a2e0", "#e8b883", "#83b8dc", "#e59cae", "#d2c377"]


def tasks():
    s = local.read_json(local.STATE / "state.json", {}) or {}
    return {
        "tasks": s.get("dailyTasks", []),
        "taskColor": s.get("taskColor", COLORS[0]),
    }


def update(data):
    if not isinstance(data, dict):
        raise TypeError("Dados da tarefa inválidos")
    op = data.get("op")
    today = dt.date.today().isoformat()
    with local.locked_state() as s:
        rows = s.setdefault("dailyTasks", [])
        if op == "color":
            if data.get("color") not in COLORS:
                raise ValueError("Cor inválida")
            s["taskColor"] = data["color"]
        elif op == "add":
            title = str(data.get("title", "")).strip()
            if not title or len(title) > 280 or len(rows) >= 300:
                raise ValueError(
                    "Use um título de até 280 caracteres e no máximo 300 tarefas"
                )
            rows.append(
                {
                    "id": uuid.uuid4().hex,
                    "title": title,
                    "note": "",
                    "priority": 1,
                    "done": False,
                    "day": today,
                    "created": time.time(),
                }
            )
        elif op == "undo":
            previous = s.pop("lastDeletedTask", None)
            if previous and len(rows) < 300:
                rows.insert(min(previous["index"], len(rows)), previous["task"])
        else:
            index = next(
                (i for i, x in enumerate(rows) if x.get("id") == data.get("id")), None
            )
            if index is None:
                raise ValueError("Tarefa não encontrada")
            row = rows[index]
            if op == "toggle":
                row["done"] = not row["done"]
                row["completedDay"] = today if row["done"] else ""
            elif op == "delete":
                s["lastDeletedTask"] = {"task": rows.pop(index), "index": index}
            elif op == "move":
                direction = data.get("direction")
                if direction not in (-1, 1):
                    raise ValueError("Direção inválida")
                if data.get("relativeId"):
                    anchor = next(
                        (x for x in rows if x["id"] == data["relativeId"]), None
                    )
                    if anchor is None or anchor["id"] == row["id"]:
                        raise ValueError("Posição inválida")
                    rows.pop(index)
                    target = rows.index(anchor) + (1 if direction > 0 else 0)
                    rows.insert(target, row)
                else:
                    target = max(0, min(len(rows) - 1, index + direction))
                    rows[index], rows[target] = rows[target], rows[index]
            elif op == "edit":
                title = str(data.get("title", row["title"])).strip()
                note = str(data.get("note", row.get("note", "")))
                priority = data.get("priority", row["priority"])
                if (
                    not title
                    or len(title) > 280
                    or len(note) > 2000
                    or priority not in (0, 1, 2)
                ):
                    raise ValueError("Título, detalhe ou prioridade inválidos")
                changed = priority != row["priority"]
                row.update(title=title, note=note, priority=priority)
                if changed:
                    rows.sort(key=lambda x: -x["priority"])
            else:
                raise ValueError("Ação de tarefa inválida")
        result = {"tasks": list(rows), "taskColor": s.get("taskColor", COLORS[0])}
    return result


def category(w):
    code = int(w.get("code") or 0)
    if code >= 95:
        return "storm"
    if code in range(51, 68) or code in range(80, 83):
        return "rain"
    if code in range(71, 78) or code in (85, 86):
        return "snow"
    if isinstance(w.get("humidity"), (int, float)) and w["humidity"] <= 25:
        return "dry"
    return "clear" if code <= 1 else "cloudy"


def weather_transition(state, weather, now, active):
    old = state.get("observation")
    group = category(weather)
    temp = weather.get("temperature")
    state["observation"] = {
        "at": now,
        "group": group,
        "temperature": temp,
        "active": active,
    }
    if not active or not old or not old.get("active") or now - old["at"] > 1500:
        return None
    kind = (
        group
        if group in ("storm", "rain", "dry", "snow") and group != old["group"]
        else None
    )
    if (
        kind is None
        and isinstance(temp, (int, float))
        and isinstance(old.get("temperature"), (int, float))
        and abs(temp - old["temperature"]) >= 3
        and now - state.get("temperatureAlertAt", 0) >= 2700
    ):
        kind = "temperature"
        state["temperatureAlertAt"] = now
    if not kind:
        return None
    return {
        "id": str(int(now)) + ":" + kind,
        "kind": kind,
        "temperature": temp,
        "humidity": weather.get("humidity"),
        "code": weather.get("code"),
    }


def session_active():
    """True/False for a known session; None permits fetching without alerts."""
    try:
        # No queued weather notices when the session is locked, idle or the lid is closed.
        for path in Path("/proc/acpi/button/lid").glob("*/state"):
            if "closed" in path.read_text():
                return False
        sid = os.environ.get("XDG_SESSION_ID") or "auto"

        def state(session):
            out = local.run(
                [
                    "loginctl",
                    "show-session",
                    session,
                    "-p",
                    "Active",
                    "-p",
                    "LockedHint",
                    "-p",
                    "IdleHint",
                ]
            )
            values = dict(
                line.split("=", 1) for line in out.splitlines() if "=" in line
            )
            if values.get("Active") not in ("yes", "no"):
                return None
            if values.get("LockedHint") == "yes" or values.get("IdleHint") == "yes":
                return False
            if values.get("LockedHint") != "no" or values.get("IdleHint") != "no":
                return None
            return values["Active"] == "yes"

        try:
            result = state(sid)
            if result is not None:
                return result
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        display = local.run(
            ["loginctl", "show-user", str(os.getuid()), "-p", "Display", "--value"]
        ).strip()
        if display and re.fullmatch(r"[A-Za-z0-9_-]+", display):
            return state(display)
        return None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def weather_panel(force=False):
    import integrations

    now = time.time()
    active = session_active()
    path = local.STATE / "weather-panel.json"
    cache = local.read_json(path, {}) or {}
    # A delayed minute tick indicates resume or a paused shell. Reset the baseline
    # instead of replaying weather changes that may have happened while away.
    if now - cache.get("lastCheck", now) > 90 and cache.get("observation"):
        cache["observation"]["active"] = False
    cache["lastCheck"] = now
    old = cache.get("weather", {})
    if active is False and not force:
        if cache.get("observation"):
            cache["observation"]["active"] = False
            local.atomic_json(path, cache)
        return {
            "weather": {
                **old,
                "inactive": True,
                "stale": now - cache.get("fetched", 0) > 1800,
            }
        }
    try:
        location = hashlib.sha256(
            json.dumps(integrations.coordinates()).encode()
        ).hexdigest()
        if cache.get("location") != location:
            cache = {"lastCheck": now, "location": location}
            old = {}
        if not force and now - cache.get("fetched", 0) < 600:
            local.atomic_json(path, cache)
            return {"weather": {**old, "stale": False}}
        w = integrations.weather()["weather"]
        if not isinstance(w.get("temperature"), (int, float)) or not math.isfinite(
            w["temperature"]
        ):
            raise ValueError("Temperatura indisponível")
        w["kind"] = category(w)
        w["fetched"] = now
        w["stale"] = False
        alert = weather_transition(cache, w, now, active is True)
        cache.update(weather=w, fetched=now)
        local.atomic_json(path, cache)
        return {"weather": w, "weatherAlert": alert}
    except (OSError, ValueError) as exc:
        if cache.get("observation"):
            cache["observation"]["active"] = False
        local.atomic_json(path, cache)
        return {"weather": {**old, "stale": True, "error": str(exc)[:300]}}
