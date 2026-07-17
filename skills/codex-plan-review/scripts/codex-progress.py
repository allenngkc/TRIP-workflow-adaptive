#!/usr/bin/env python3
"""Render concise live progress from ``codex exec --json`` JSONL."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


def compact(value: Any, limit: int = 240) -> str:
    if isinstance(value, (dict, list)):
        text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    else:
        text = str(value)
    text = re.sub(r"\s+", " ", text).strip()
    return text if len(text) <= limit else f"{text[: limit - 3]}..."


def error_message(event: dict[str, Any]) -> str:
    error = event.get("error")
    if isinstance(error, dict):
        return compact(error.get("message", "unknown error"))
    return compact(event.get("message", error or "unknown error"))


def changed_paths(item: dict[str, Any]) -> str:
    paths: list[str] = []
    changes = item.get("changes", [])
    if isinstance(changes, list):
        for change in changes:
            if isinstance(change, dict) and isinstance(change.get("path"), str):
                paths.append(change["path"])
            elif isinstance(change, str):
                paths.append(change)
    if isinstance(item.get("path"), str):
        paths.append(item["path"])
    return ", ".join(dict.fromkeys(paths))


def progress_line(event: dict[str, Any]) -> str | None:
    event_type = event.get("type")
    item = event.get("item") if isinstance(event.get("item"), dict) else {}
    item_type = item.get("type")

    if event_type == "thread.started":
        return f"[codex] session started: {event.get('thread_id', 'unknown')}"
    if event_type == "turn.started":
        return "[codex] turn started"
    if event_type == "turn.completed":
        return "[codex] turn completed"
    if event_type == "turn.failed":
        return f"[codex] turn failed: {error_message(event)}"
    if event_type == "error":
        return f"[codex] error: {error_message(event)}"
    if event_type == "item.started" and item_type == "command_execution":
        return f"[codex] command started: {compact(item.get('command', 'unknown command'))}"
    if event_type == "item.completed" and item_type == "command_execution":
        failed = item.get("status") == "failed"
        exit_code = item.get("exit_code")
        failed = failed or isinstance(exit_code, int) and exit_code != 0
        state = "failed" if failed else "completed"
        return f"[codex] command {state}: {compact(item.get('command', 'unknown command'))}"
    if event_type in {"item.started", "item.completed"} and item_type == "file_change":
        state = "started" if event_type == "item.started" else "completed"
        paths = changed_paths(item)
        suffix = f": {compact(paths)}" if paths else ""
        return f"[codex] file changes {state}{suffix}"
    if event_type in {"item.started", "item.completed"} and item_type == "mcp_tool_call":
        state = "started" if event_type == "item.started" else "completed"
        tool = item.get("tool", item.get("name", "MCP tool"))
        return f"[codex] tool {state}: {compact(tool)}"
    if event_type == "item.started" and item_type == "web_search":
        return f"[codex] web search started: {compact(item.get('query', 'search'))}"
    if event_type == "item.completed" and item_type == "plan_update":
        return "[codex] plan updated"
    return None


def events(lines: Iterable[str]) -> Iterable[dict[str, Any]]:
    for line_number, line in enumerate(lines, 1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid JSONL at line {line_number}: {exc.msg}") from exc
        if not isinstance(event, dict):
            raise ValueError(f"invalid JSONL at line {line_number}: event is not an object")
        yield event


def extract_thread(path: Path) -> int:
    with path.open(encoding="utf-8") as handle:
        for event in events(handle):
            if event.get("type") == "thread.started" and event.get("thread_id"):
                print(event["thread_id"])
                return 0
    return 1


def render(thread_file: Path | None) -> int:
    try:
        for event in events(sys.stdin):
            if event.get("type") == "thread.started" and event.get("thread_id") and thread_file:
                thread_file.write_text(f"{event['thread_id']}\n", encoding="utf-8")
            line = progress_line(event)
            if line:
                print(line, flush=True)
    except (OSError, ValueError) as exc:
        print(f"[codex] progress parser error: {exc}", file=sys.stderr, flush=True)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--thread-file", type=Path)
    parser.add_argument("--extract-thread", type=Path)
    args = parser.parse_args()
    if args.extract_thread:
        return extract_thread(args.extract_thread)
    return render(args.thread_file)


if __name__ == "__main__":
    raise SystemExit(main())
