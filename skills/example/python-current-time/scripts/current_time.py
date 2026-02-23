#!/usr/bin/env python3

from datetime import datetime


def main() -> None:
    # Print local time with timezone offset in ISO 8601 format.
    print(datetime.now().astimezone().isoformat(timespec="seconds"))


if __name__ == "__main__":
    main()
