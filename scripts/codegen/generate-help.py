#!/usr/bin/env python3
"""
generate-help.py — generate HelpContent from Shared/content/help-content.json

Usage:
  python3 generate-help.py ios   swift   <output-swift-file>
  python3 generate-help.py android kotlin <output-kotlin-file>

Items with platform == target OR platform == "both" are included.
Items for the other platform are silently dropped. The same rule applies to
individual screenTip actions, which may carry their own optional "platform"
(schema 1.10); omitting it means "both", so pre-1.10 content is unaffected.

Also emits screenTips (per-screen contextual tip cards) using the icon
vocabulary defined in content/icons.json. Build fails on duplicate ids,
non-slug ids, or icon tokens that aren't in the vocabulary.
"""

import json
import re
import sys
from pathlib import Path


SLUG_RE = re.compile(r"^[a-z0-9-]+$")


def escape_swift(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def escape_kotlin(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")


def fail(msg: str):
    print(f"generate-help: ERROR — {msg}", file=sys.stderr)
    sys.exit(1)


def validate_screen_tips(tips, icon_vocab, platform):
    """Validate every screenTip entry. Returns the platform-filtered list."""
    seen_ids = set()
    filtered = []
    for i, tip in enumerate(tips):
        loc = f"screenTips[{i}]"
        for required in ("id", "screenName", "title", "platform", "actions"):
            if required not in tip:
                fail(f"{loc} missing field '{required}'")
        tip_id = tip["id"]
        if not SLUG_RE.match(tip_id):
            fail(f"{loc}.id '{tip_id}' must match {SLUG_RE.pattern}")
        if tip_id in seen_ids:
            fail(f"{loc}.id '{tip_id}' is duplicated")
        seen_ids.add(tip_id)
        if tip["platform"] not in ("ios", "android", "both"):
            fail(f"{loc}.platform '{tip['platform']}' must be ios|android|both")
        if not isinstance(tip["actions"], list) or not tip["actions"]:
            fail(f"{loc}.actions must be a non-empty array")
        # Per-action platform gating (schema 1.10). Optional, defaults to
        # "both", so every pre-1.10 action keeps its behaviour and the output
        # for a file that uses no action-level platform key is byte-identical
        # to what the previous generator emitted. It exists because a single
        # action can mix claims that are true on one platform and false on the
        # other (an Apple Music sentence inside an otherwise shared
        # explanation), and the consumers' only alternative was a string-match
        # shim over the rendered copy, which drops the true half with the false.
        kept_actions = []
        for j, action in enumerate(tip["actions"]):
            aloc = f"{loc}.actions[{j}]"
            for required in ("icon", "label", "context"):
                if not action.get(required):
                    fail(f"{aloc} missing or empty field '{required}'")
            if action["icon"] not in icon_vocab:
                fail(
                    f"{aloc}.icon '{action['icon']}' is not in the icon vocabulary "
                    f"(content/icons.json). Add it there first."
                )
            action_platform = action.get("platform", "both")
            if action_platform not in ("ios", "android", "both"):
                fail(f"{aloc}.platform '{action_platform}' must be ios|android|both")
            if action_platform in (platform, "both"):
                kept_actions.append(action)
        # cardPosition is optional; defaults to "bottom"
        pos = tip.get("cardPosition", "bottom")
        if pos not in ("top", "bottom"):
            fail(f"{loc}.cardPosition '{pos}' must be 'top' or 'bottom'")
        if tip["platform"] in (platform, "both"):
            # A tip whose every action was gated away for this platform has
            # nothing left to say, so drop the tip rather than emit an empty
            # card. Announced rather than silent, so an over-broad gate shows
            # up in the build log instead of as a card that quietly stopped
            # appearing.
            if not kept_actions:
                print(
                    f"generate-help: note — {loc} ('{tip_id}') has no actions for "
                    f"platform '{platform}'; tip omitted."
                )
                continue
            filtered.append({**tip, "cardPosition": pos, "actions": kept_actions})
    return filtered


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <ios|android> <swift|kotlin> <output-file>",
              file=sys.stderr)
        sys.exit(1)

    platform, fmt, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    if platform not in ("ios", "android"):
        fail(f"Unknown platform: {platform}")
    if fmt not in ("swift", "kotlin"):
        fail(f"Unknown format: {fmt}")

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent.parent
    help_json = repo_root / "content" / "help-content.json"
    icons_json = repo_root / "content" / "icons.json"
    version_file = repo_root / "VERSION"

    if not help_json.exists():
        fail(f"Missing: {help_json}")
    if not icons_json.exists():
        fail(f"Missing: {icons_json}")

    version = version_file.read_text().strip() if version_file.exists() else "unknown"

    with open(help_json, encoding="utf-8") as f:
        data = json.load(f)
    with open(icons_json, encoding="utf-8") as f:
        icons_data = json.load(f)

    icon_vocab = icons_data.get("icons", {})
    if not icon_vocab:
        fail("content/icons.json has no 'icons' object")

    # Filter sections by platform (existing flow)
    filtered_sections = []
    for section in data.get("sections", []):
        items = [
            item for item in section["items"]
            if item.get("platform", "both") in (platform, "both")
        ]
        if items:
            filtered_sections.append({**section, "items": items})

    # Validate + filter screenTips
    raw_tips = data.get("screenTips", [])
    filtered_tips = validate_screen_tips(raw_tips, icon_vocab, platform)

    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    if fmt == "swift":
        content = build_swift(filtered_sections, filtered_tips, icon_vocab, version, platform)
    else:
        content = build_kotlin(filtered_sections, filtered_tips, icon_vocab, version, platform)

    out.write_text(content, encoding="utf-8")
    print(f"Generated: {out_path} ({content.count(chr(10))} lines, "
          f"{len(filtered_sections)} sections, {len(filtered_tips)} screenTips)")


def build_swift(sections, screen_tips, icon_vocab, version, platform):
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
        "    struct ScreenTipAction {",
        "        let icon: String",
        "        let label: String",
        "        let context: String",
        "    }",
        "    struct ScreenTip {",
        "        let id: String",
        "        let title: String",
        "        let cardPosition: String",
        "        let actions: [ScreenTipAction]",
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

    lines += ["    ]"]

    # Screen tips
    lines += ["", "    static let screenTips: [ScreenTip] = ["]
    for tip in screen_tips:
        tid = escape_swift(tip["id"])
        ttitle = escape_swift(tip["title"])
        pos = escape_swift(tip["cardPosition"])
        lines.append(f'        ScreenTip(id: "{tid}", title: "{ttitle}", cardPosition: "{pos}", actions: [')
        for action in tip["actions"]:
            symbol = icon_vocab[action["icon"]]["ios"]
            lines.append(
                f'            ScreenTipAction('
                f'icon: "{escape_swift(symbol)}", '
                f'label: "{escape_swift(action["label"])}", '
                f'context: "{escape_swift(action["context"])}"),'
            )
        lines.append("        ]),")
    lines += [
        "    ]",
        "",
        "    static func screenTip(id: String) -> ScreenTip? {",
        "        screenTips.first(where: { $0.id == id })",
        "    }",
        "}",
        "",
    ]
    return "\n".join(lines)


def build_kotlin(sections, screen_tips, icon_vocab, version, platform):
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
        "    data class ScreenTipAction(val icon: String, val label: String, val context: String)",
        "    data class ScreenTip(val id: String, val title: String, val cardPosition: String, val actions: List<ScreenTipAction>)",
        "",
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

    lines += ["    )"]

    # Screen tips
    lines += ["", "    val screenTips: List<ScreenTip> = listOf("]
    for tip in screen_tips:
        tid = escape_kotlin(tip["id"])
        ttitle = escape_kotlin(tip["title"])
        pos = escape_kotlin(tip["cardPosition"])
        lines.append(f'        ScreenTip(id = "{tid}", title = "{ttitle}", cardPosition = "{pos}", actions = listOf(')
        for action in tip["actions"]:
            symbol = icon_vocab[action["icon"]]["android"]
            lines.append(
                f'            ScreenTipAction('
                f'icon = "{escape_kotlin(symbol)}", '
                f'label = "{escape_kotlin(action["label"])}", '
                f'context = "{escape_kotlin(action["context"])}"),'
            )
        lines.append("        )),")
    lines += [
        "    )",
        "",
        "    fun screenTip(id: String): ScreenTip? = screenTips.firstOrNull { it.id == id }",
        "}",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    main()
