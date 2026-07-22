# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
from std.pathlib import Path
from std.os import remove


def main() raises:
    var log = Path("temps.txt")

    log.write_text(
        String.write(
            "20.5",
            " 22.3",
            "",
            "19.8  ",
            "not a number",
            "26.0",
            "25.1",
            sep="\n",
            end="\n",
        )
    )

    var text = log.read_text()
    var lines = text.splitlines()
    print(t"Got {len(lines)} lines")

    var temps: List[Float64] = []
    var rejected: List[String] = []

    for line in lines:
        var cleaned = line.strip()
        if not cleaned:
            continue

        try:
            temps.append(Float64(cleaned))
        except:
            rejected.append(String(cleaned))

    print(t"Parsed {len(temps)} temperatures: {temps}")
    print(t"Rejected {len(rejected)}: {rejected}")

    remove(log)
