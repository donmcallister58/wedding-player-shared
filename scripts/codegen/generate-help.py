#!/usr/bin/env python3
"""
generate-help.py — generate HelpContent from Shared/content/help-content.json

Usage:
  python3 generate-help.py ios   swift   <output-swift-file>
  python3 generate-help.py android kotlin <output-kotlin-file>

Items with platform == target OR platform == "both" are included.
Items for the other platform are silently dropped.
"""

import json
import os
import sys
from pathlib import Path


def escape_swift(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def escape_kotlin(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <ios|android> <swift|kotlin> <output-file>",
              file=sys.stderr)
        sys.exit(1)

    platform, fmt, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    if platform not in ("ios", "android"):
        print(f"Unknown platform: {platform}", file=sys.stderr)
        sys.exit(1)
    if fmt not in ("swift", "kotlin"):
        print(f"Unknown format: {fmt}", file=sys.stderr)
        sys.exit(1)

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent.parent
    help_json = repo_root / "content" / "help-content.json"
    version_file = repo_root / "VERSION"

    if not help_json.exists():
        print(f"Missing: {help_json}", file=sys.stderr)
        sys.exit(1)

    version = version_file.read_text().strip() if version_file.exists() else "unknown"

    with open(help_json, encoding="utf-8") as f:
        data = json.load(f)

    # Filter items to those relevant for this platform
    filtered = []
    for section in data["sections"]:
        items = [
            item for item in section["items"]
            if item.get("platform", "both") in (platform, "both")
        ]
        if items:
            filtered.append({**section, "items": items})

    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    if fmt == "swift":
        content = build_swift(filtered, version, platform)
    else:
        content = build_kotlin(filtered, version, platform)

    out.write_text(content, encoding="utf-8")
    print(f"Generated: {out_path} ({content.count(chr(10))} lines)")


def build_swift(sections, version, platform):
    lines = [
        "// GENERATED — DO NOT EDIT.",
        f"// Regenerated from wedding-player-shared@v{version} on each build.",
        f"// Source: content/help-content.json  platform: {platform}",
        "",
        "import Foundation",
        "",
        "enum HelpContent {",
        "    struct Item {",
        "        let id: String",
        "        let title: String",
        "        let steps: [String]",
        "    }",
        "    struct Section {",
        "        let id: String",
        "        let title: String",
        "        let items: [Item]",
        "    }",
        "    static let sections: [Section] = [",
    ]

    for section in sections:
        sid = escape_swift(section["id"])
        stitle = escape_swift(section["title"])
        lines.append(f'        Section(id: "{sid}", title: "{stitle}", items: [')
        for item in section["items"]:
            iid = escape_swift(item["id"])
            ititle = escape_swift(item["title"])
            lines.append(f'            Item(id: "{iid}", title: "{ititle}", steps: [')
            for step in item["steps"]:
                lines.append(f'                "{escape_swift(step)}",')
            lines.append("            ]),")
        lines.append("        ]),")

    lines += ["    ]", "}", ""]
    return "\n".join(lines)


def build_kotlin(sections, version, platform):
    lines = [
        "// GENERATED — DO NOT EDIT.",
        f"// Regenerated from wedding-player-shared@v{version} on each build.",
        f"// Source: content/help-content.json  platform: {platform}",
        "",
        "package uk.playerapps.weddingplayer.generated",
        "",
        "object HelpContent {",
        "    data class Item(val id: String, val title: String, val steps: List<String>)",
        "    data class Section(val id: String, val title: String, val items: List<Item>)",
        "    val sections: List<Section> = listOf(",
    ]

    for section in sections:
        sid = escape_kotlin(section["id"])
        stitle = escape_kotlin(section["title"])
        lines.append(f'        Section(id = "{sid}", title = "{stitle}", items = listOf(')
        for item in section["items"]:
            iid = escape_kotlin(item["id"])
            ititle = escape_kotlin(item["title"])
            lines.append(f'            Item(id = "{iid}", title = "{ititle}", steps = listOf(')
            for step in item["steps"]:
                lines.append(f'                "{escape_kotlin(step)}",')
            lines.append("            )),")
        lines.append("        )),")

    lines += ["    )", "}", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    main()
