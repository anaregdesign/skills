---
name: python-current-time
description: Return the current local time by running a bundled Python script. Use this when a user asks for the current time and wants it retrieved via Python.
---

# Python Current Time

Use this skill when a user wants the current time from a Python script.

## Workflow

1. Run `python3 scripts/current_time.py`.
2. Return the script output exactly as printed.
3. If `python3` is unavailable, run `python scripts/current_time.py`.
