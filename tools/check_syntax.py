# check_syntax.py - Parses every .lua file under a path with luaparser (Lua 5.3 grammar).
# WoW uses Lua 5.1 but the MSBT codebase avoids 5.2+ only constructs, so this is a
# good smoke test for syntax errors (unbalanced blocks, stray tokens, etc.).
import sys, pathlib
from luaparser import ast

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
failed = 0
checked = 0
for f in sorted(root.rglob("*.lua")):
    src = f.read_text(encoding="utf-8-sig", errors="replace").lstrip("\ufeff")
    try:
        ast.parse(src)
        checked += 1
    except Exception as e:
        failed += 1
        first = str(e).splitlines()[0][:160].encode("ascii", "replace").decode("ascii")
        rel = str(f).encode("ascii", "replace").decode("ascii")
        print(f"FAIL {rel}: {first}")
print(f"Checked {checked} file(s), {failed} failure(s).")
sys.exit(1 if failed else 0)
