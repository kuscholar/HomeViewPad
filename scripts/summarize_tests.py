#!/usr/bin/env python3
"""Print xcresulttool's actual counts; never turn failed/empty results into success."""
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
print(f"\n### {path.stem}\n")
for key in ('result', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests'):
    print(f"- {key}: {data.get(key, 'unavailable')}")
if not isinstance(data.get('totalTestCount'), int) or data['totalTestCount'] <= 0:
    raise SystemExit('No executed test evidence; inspect the result bundle.')
if data.get('failedTests', 0) or data.get('result') != 'Passed':
    raise SystemExit('Tests did not pass; inspect the result bundle.')
