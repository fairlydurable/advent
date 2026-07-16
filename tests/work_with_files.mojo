# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
from std.tempfile import NamedTemporaryFile
from std.pathlib import Path
from std.os import remove, rmdir, removedirs


def main() raises:
    var content = "20.5, 22.3, 19.8, 25.1"  # temperatures
    var path: String

    with NamedTemporaryFile(delete=False) as f:  # context manager
        f.write(content)
        path = f.name

    print(t"Wrote to {path}")

    var p = Path(path)
    print(t"Exists: {p.exists()}, is file: {p.is_file()}")

    var roundtrip = p.read_text()
    print(roundtrip)

    print(t"Match: {content == roundtrip}")

    with open(p, "a") as f:
        while value := input("Today's high (°C): "):
            try:
                var fp = Float64(value)
                f.write(t", {fp}")
            except e:
                print(t"Invalid input '{value}': {e}")

    print(p.read_text())

    if p.exists():
        remove(p)
    print(t"After cleanup, exists: {p.exists()}")
