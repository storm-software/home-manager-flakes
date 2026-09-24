#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import sys
import tempfile


SETTING = "chatgpt.cliExecutable"


def without_comments(source: str) -> str:
    result: list[str] = []
    index = 0
    in_string = False
    escaped = False
    while index < len(source):
        character = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if in_string:
            result.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            index += 1
        elif character == '"':
            in_string = True
            result.append(character)
            index += 1
        elif character == "/" and following == "/":
            result.extend("  ")
            index += 2
            while index < len(source) and source[index] not in "\r\n":
                result.append(" ")
                index += 1
        elif character == "/" and following == "*":
            result.extend("  ")
            index += 2
            while index < len(source):
                if source[index : index + 2] == "*/":
                    result.extend("  ")
                    index += 2
                    break
                result.append("\n" if source[index] == "\n" else " ")
                index += 1
            else:
                raise ValueError("unterminated block comment")
        else:
            result.append(character)
            index += 1
    return "".join(result)


def validate_jsonc(source: str) -> None:
    commentless = without_comments(source)
    json_source = re.sub(r",(?=\s*[}\]])", "", commentless)
    parsed = json.loads(json_source)
    if not isinstance(parsed, dict):
        raise ValueError("settings must contain a JSON object")


def scan_string(source: str, start: int) -> int:
    index = start + 1
    escaped = False
    while index < len(source):
        if escaped:
            escaped = False
        elif source[index] == "\\":
            escaped = True
        elif source[index] == '"':
            return index + 1
        index += 1
    raise ValueError("unterminated string")


def skip_space_and_comments(source: str, start: int) -> int:
    index = start
    while index < len(source):
        if source[index].isspace():
            index += 1
        elif source[index : index + 2] == "//":
            newline = source.find("\n", index + 2)
            index = len(source) if newline == -1 else newline + 1
        elif source[index : index + 2] == "/*":
            end = source.find("*/", index + 2)
            if end == -1:
                raise ValueError("unterminated block comment")
            index = end + 2
        else:
            return index
    return index


def find_setting_value(source: str) -> tuple[int, int] | None:
    index = 0
    depth = 0
    while index < len(source):
        if source[index : index + 2] in ("//", "/*"):
            index = skip_space_and_comments(source, index)
        elif source[index] == '"':
            end = scan_string(source, index)
            if depth == 1 and json.loads(source[index:end]) == SETTING:
                colon = skip_space_and_comments(source, end)
                if colon >= len(source) or source[colon] != ":":
                    raise ValueError(f"{SETTING} is not a property")
                value_start = skip_space_and_comments(source, colon + 1)
                if value_start >= len(source) or source[value_start] != '"':
                    raise ValueError(f"{SETTING} must be a string")
                return value_start, scan_string(source, value_start)
            index = end
        elif source[index] in "[{":
            depth += 1
            index += 1
        elif source[index] in "]}":
            depth -= 1
            index += 1
        else:
            index += 1
    return None


def closing_brace_and_last_token(source: str) -> tuple[int, int | None]:
    masked = without_comments(source)
    closing = masked.rfind("}")
    if closing == -1:
        raise ValueError("settings object has no closing brace")
    last = closing - 1
    while last >= 0 and masked[last].isspace():
        last -= 1
    return closing, last if last >= 0 and masked[last] != "{" else None


def updated_source(source: str, launcher: str) -> str:
    validate_jsonc(source)
    encoded = json.dumps(launcher)
    existing = find_setting_value(source)
    if existing is not None:
        start, end = existing
        return source[:start] + encoded + source[end:]

    closing, last = closing_brace_and_last_token(source)
    before = source[:closing]
    if last is not None and source[last] != ",":
        before = source[: last + 1] + "," + source[last + 1 : closing]
    if before and not before.endswith("\n"):
        before += "\n"
    return before + f'  "{SETTING}": {encoded}\n' + source[closing:]


def configure(settings: Path, launcher: str) -> None:
    source = settings.read_text() if settings.exists() else "{}\n"
    updated = updated_source(source, launcher)
    if updated == source:
        return
    settings.parent.mkdir(parents=True, exist_ok=True)
    mode = settings.stat().st_mode if settings.exists() else 0o600
    with tempfile.NamedTemporaryFile(
        "w", dir=settings.parent, prefix=f".{settings.name}.", delete=False
    ) as temporary:
        temporary.write(updated)
        temporary_path = Path(temporary.name)
    os.chmod(temporary_path, mode)
    os.replace(temporary_path, settings)


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} SETTINGS_FILE CODEX_VSCODE", file=sys.stderr)
        return 2
    try:
        configure(Path(sys.argv[1]), sys.argv[2])
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"configure-codex-vscode: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
