"""Example job for the Docker + Task Scheduler pattern.

Stands in for real work: it prints progress (captured in the run log),
writes one timestamped file to /output, and exits 0 on success.

Set ``FAIL=1`` in the container environment to make it exit with code 3,
which is how to check that a failed run shows up in the log and in Task
Scheduler's "Last Run Result".
"""
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

OUTPUT = Path("/output")


def main() -> int:
    name = os.environ.get("JOB_NAME", "job")
    now = datetime.now(timezone.utc)
    print(f"{name}: started at {now:%Y-%m-%d %H:%M:%S} UTC", flush=True)

    if os.environ.get("FAIL") == "1":
        print(f"{name}: FAIL=1 set, simulating an error", file=sys.stderr, flush=True)
        return 3

    OUTPUT.mkdir(parents=True, exist_ok=True)
    result = OUTPUT / f"{name}_{now:%Y%m%d-%H%M%S}.txt"
    result.write_text(f"{name} ran at {now.isoformat()}\n", encoding="utf-8")
    print(f"{name}: wrote {result}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
