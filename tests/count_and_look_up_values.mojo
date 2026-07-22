# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
from std.collections import Set


def main() raises:
    # each reading's station id, already parsed from the log
    var reported_ids = [3, 1, 3, 5, 1, 3, 1, 5, 1, 5, 5, 3, 5, 5, 1]
    print(t"{len(reported_ids)} readings")  # 15

    var counts = Dict[Int, Int]()
    for id in reported_ids:
        counts[id] = counts.get(id, 0) + 1

    for entry in counts.items():
        print(t"station {entry.key}: {entry.value} readings")

    var reported: Set[Int] = {}
    for id in reported_ids:
        reported.add(id)

    for station in range(1, 6):
        print(
            t"Station {station} reported? "
            t"{\"Yes\" if station in reported else \"No\"}"  # TStrings allow concatenation
        )
    # Station 1 reported? Yes
    # Station 2 reported? No
    # Station 3 reported? Yes
    # Station 4 reported? No
    # Station 5 reported? Yes

    var expected = Set[Int](1, 2, 3, 4, 5)
    var missing = expected - reported
    print(t"silent stations: {missing}")  # {2, 4}

    var per_day = Dict[Tuple[Int, Int], Int]()
    var log = [(3, 0), (3, 0), (1, 2), (3, 1)]  # (station, day)
    for pair in log:
        per_day[pair] = per_day.get(pair, 0) + 1

    for entry in per_day.items():
        var station, day = entry.key  # unpack the tuple key
        print(t"station {station}, day {day}: {entry.value}")

    # Try removing (1, 1) after running the missing days code below
    var data = [
        (1, 0),
        (1, 0),
        (1, 0),
        (2, 0),
        (2, 0),
        (3, 0),
        (3, 0),
        (3, 0),
        (1, 1),
        (3, 1),
        (3, 1),
        (3, 1),
        (3, 1),
        (1, 2),
        (1, 2),
        (1, 2),
        (1, 2),
        (1, 2),
        (1, 2),
        (2, 2),
        (2, 2),
        (3, 2),
        (3, 2),
        (3, 2),
        (3, 2),
    ]

    var per_day_set: Set[Tuple[Int, Int]] = {}
    for pair in data:
        per_day_set.add(pair)

    var missing_days = [
        String(t"Station {station} - Day {day}")
        for station in range(1, 4)
        for day in range(3)
        if (station, day) not in per_day_set
    ]

    print(t"missing days: {missing_days}")  # ['Station 2 - Day 1']
