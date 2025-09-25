
import sys
import re
from pathlib import Path

def unicode_escape(s: str) -> str:
    out = []
    for ch in s:
        if ord(ch) > 127:
            out.append("\\u%04x" % ord(ch))
        else:
            out.append(ch)
    return "".join(out)

# Regex to match Dart/Flutter string literals (single or double quotes).
# Handles basic escapes but not multiline (triple) strings.
STRING_RE = re.compile(
    r"""
    (?P<prefix>[rR]?)(?P<quote>['"])        # optional raw prefix + opening quote
    (?P<body>(?:\\.|(?!\1).)*?)             # body: escaped chars or anything not the same quote
    (?P=quote)                              # closing quote
    """,
    re.VERBOSE | re.DOTALL,
)

# Simple heuristic: skip raw strings (r'...') to avoid breaking regex patterns.
def transform_string_literal(match: re.Match) -> str:
    prefix = match.group('prefix') or ''
    quote = match.group('quote')
    body  = match.group('body')

    if prefix.lower() == 'r':
        return match.group(0)  # don't touch raw strings

    # Do not touch if it already contains \uXXXX sequences for all non-ascii?
    # We'll still re-escape non-ascii characters, but leave existing escapes untouched.
    new_body_chars = []
    i = 0
    while i < len(body):
        ch = body[i]
        if ch == '\\':  # keep escapes as-is
            if i + 1 < len(body):
                new_body_chars.append(ch)
                new_body_chars.append(body[i+1])
                i += 2
                continue
        # Replace non-ASCII with \uXXXX
        if ord(ch) > 127:
            new_body_chars.append("\\u%04x" % ord(ch))
        else:
            new_body_chars.append(ch)
        i += 1

    new_body = ''.join(new_body_chars)
    return f"{prefix}{quote}{new_body}{quote}"

def process_file(path: Path) -> int:
    try:
        original = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        original = path.read_text(encoding='utf-16')

    transformed = STRING_RE.sub(transform_string_literal, original)

    if transformed != original:
        backup = path.with_suffix(path.suffix + ".bak")
        if not backup.exists():
            backup.write_text(original, encoding='utf-8')
        path.write_text(transformed, encoding='utf-8')
        return 1
    return 0

def main():
    if len(sys.argv) > 1:
        root = Path(sys.argv[1])
    else:
        root = Path('.')
    dart_files = list(root.rglob('*.dart'))
    changed = 0
    for f in dart_files:
        changed += process_file(f)
    print(f"Scanned {len(dart_files)} .dart files, updated {changed} file(s).")
    print("Backups saved as *.bak next to modified files.")

if __name__ == "__main__":
    main()
