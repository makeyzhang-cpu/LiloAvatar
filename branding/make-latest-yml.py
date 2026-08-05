#!/usr/bin/env python3
"""
Generate latest.yml for electron-updater.
Must use LF line endings; CRLF will cause YAML parse errors.
Usage:
  python make-latest-yml.py <exe-path> <version>
"""
import hashlib
import base64
import os
import sys


def main():
    if len(sys.argv) < 3:
        print("Usage: python make-latest-yml.py <exe-path> <version>")
        sys.exit(1)

    exe_path = sys.argv[1]
    version = sys.argv[2]

    if not os.path.exists(exe_path):
        print(f"ERROR: file not found: {exe_path}")
        sys.exit(1)

    size = os.path.getsize(exe_path)
    filename = os.path.basename(exe_path)

    sha512 = hashlib.sha512()
    with open(exe_path, "rb") as fh:
        for chunk in iter(lambda: fh.read(8192), b""):
            sha512.update(chunk)
    sha512_b64 = base64.b64encode(sha512.digest()).decode()

    # Use UTC ISO timestamp
    from datetime import datetime, timezone
    release_date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

    yml = f"""version: {version}
files:
  - url: {filename}
    sha512: {sha512_b64}
    size: {size}
path: {filename}
sha512: {sha512_b64}
releaseDate: '{release_date}'
"""

    out_path = os.path.join(os.path.dirname(exe_path), "latest.yml")
    with open(out_path, "w", newline="\n") as f:
        f.write(yml)

    print(f"Wrote {out_path}")
    print(f"  version: {version}")
    print(f"  size:    {size}")
    print(f"  sha512:  {sha512_b64}")


if __name__ == "__main__":
    main()
