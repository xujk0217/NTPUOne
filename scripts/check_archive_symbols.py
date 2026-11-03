#!/usr/bin/env python3
"""Report missing binary dSYMs in an xcarchive without altering it."""
import pathlib
import re
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit('Usage: python3 scripts/check_archive_symbols.py /path/to/App.xcarchive')
archive = pathlib.Path(sys.argv[1])
if not (archive / 'Info.plist').is_file():
    raise SystemExit('Archive not found')
def uuids(path):
    result = subprocess.run(['dwarfdump', '--uuid', str(path)], capture_output=True, text=True)
    return set(re.findall(r'UUID: ([0-9A-Fa-f-]+)', result.stdout)) if result.returncode == 0 else set()
found = set()
for symbol in (archive / 'dSYMs').glob('*.dSYM'):
    found.update(uuids(symbol))
apps = list((archive / 'Products' / 'Applications').glob('*.app'))
if not apps or not found:
    raise SystemExit('Archive has no app or readable dSYMs')
missing = []
for app in apps:
    for framework in (app / 'Frameworks').glob('*.framework'):
        binary = framework / framework.stem
        if binary.is_file():
            for uid in sorted(uuids(binary) - found):
                missing.append((framework.name, uid))
for name, uid in missing:
    print(f'MISSING {name} {uid}')
print(f'{len(missing)} framework UUID(s) missing matching dSYM in archive')
raise SystemExit(1 if missing else 0)
