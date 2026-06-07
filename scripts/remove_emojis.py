#!/usr/bin/env python3
"""
Remove emojis from all .ts/.tsx/.py files in the codebase.
EXCEPTIONS: Dashboard world map hotspots and sidebar nav icons are preserved.

Usage:
    python scripts/remove_emojis.py --dry-run   # preview only
    python scripts/remove_emojis.py             # apply changes
"""
import re
import argparse
from pathlib import Path

# Files/paths to skip entirely (contain intentional UI emojis)
SKIP_FILES = {
    "src/app/pages/Dashboard/index.tsx",  # world map + KPI icons
    "src/app/layouts/Sidebar.tsx",  # navigation icons
}

# Specific emojis to KEEP (used as UI icons on dashboard/sidebar)
KEEP_EMOJIS = {
    "🛡",
    "🔔",
    "📄",
    "🤖",
    "📊",
    "⚙",
    "⬡",
    "📈",
    "🔍",
    "🌐",
    "⚡",
    "#",
    "🏢",
}

# Emoji unicode ranges
EMOJI_PATTERN = re.compile(
    "["
    "\U0001F600-\U0001F64F"  # emoticons
    "\U0001F300-\U0001F5FF"  # symbols & pictographs
    "\U0001F680-\U0001F6FF"  # transport & map
    "\U0001F1E0-\U0001F1FF"  # flags
    "\U00002600-\U000027BF"  # misc symbols (includes ☀️ ☣)
    "\U0001F900-\U0001F9FF"  # supplemental symbols
    "\U00002702-\U000027B0"
    "]+",
    flags=re.UNICODE,
)

# Text replacements for common emoji usage in code
REPLACEMENTS = {
    "✅": "",
    "❌": "ERROR:",
    "⚠": "WARNING:",
    "✓": "",
    "✗": "x",
    "→": "->",
    "●": "*",
    "↑": "^",
    "↺": "",
    "☀️": "",
    "🌙": "",
    "★": "*",
    "⟳": "",
    "➤": "",
    "⚡": "",
}


def clean_file(path: Path, dry_run: bool) -> tuple[bool, int]:
    """Remove emojis from a file. Returns (changed, count)."""
    try:
        original = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, PermissionError):
        return False, 0

    text = original
    count = 0

    # Apply specific replacements first
    for emoji, replacement in REPLACEMENTS.items():
        if emoji in text:
            c = text.count(emoji)
            text = text.replace(emoji, replacement)
            count += c

    # Remove remaining emojis (except kept ones)
    def replace_match(m: re.Match) -> str:
        nonlocal count
        s = m.group(0)
        if s in KEEP_EMOJIS:
            return s
        count += len(s)
        return ""

    text = EMOJI_PATTERN.sub(replace_match, text)

    if text == original:
        return False, 0

    if not dry_run:
        path.write_text(text, encoding="utf-8")
        print(f"  CLEANED  {path}  ({count} emojis removed)")
    else:
        print(f"  PREVIEW  {path}  ({count} emojis would be removed)")

    return True, count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--root", default=".", help="Project root")
    args = parser.parse_args()

    root = Path(args.root)
    patterns = ["frontend/src/**/*.tsx", "frontend/src/**/*.ts", "backend/src/**/*.py"]
    skip = {root / p for p in SKIP_FILES}

    total_files = 0
    total_emojis = 0

    print(f"\n{'DRY RUN - ' if args.dry_run else ''}Scanning {root}\n")

    for pattern in patterns:
        for path in sorted(root.glob(pattern)):
            if (
                path in skip
                or "node_modules" in str(path)
                or "__pycache__" in str(path)
            ):
                continue
            changed, count = clean_file(path, args.dry_run)
            if changed:
                total_files += 1
                total_emojis += count

    print(
        f"\n{'Would remove' if args.dry_run else 'Removed'} "
        f"{total_emojis} emojis across {total_files} files"
    )
    if args.dry_run:
        print("Run without --dry-run to apply changes")


if __name__ == "__main__":
    main()
