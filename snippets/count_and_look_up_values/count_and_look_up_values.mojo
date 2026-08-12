# ===----------------------------------------------------------------------=== #
# Copyright (c) 2026, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #
# ANCHOR: final
from std.pathlib import Path

# ANCHOR: import_set
from std.collections import Set

# ANCHOR_END: import_set


def main() raises:
    # ANCHOR: reports
    var log = Path("src/downloads/station_reports.txt")
    var lines = log.read_text().splitlines()

    var reported_ids = List[Int]()
    var days = List[Int]()

    for line in lines:
        # ['Station 3', 'Day 0', '06:00', '-18.2C', 'Clear']
        var fields = line.split(", ")
        reported_ids.append(Int(fields[0].split(" ")[1]))
        days.append(Int(fields[1].split(" ")[1]))
        # fields[2] is the time, fields[3] the temperature, fields[4] the
        # conditions. This page only needs the station id and the day.

    print(t"{len(reported_ids)} readings")  # 15 readings
    # ANCHOR_END: reports

    # ANCHOR: tally
    var counts = Dict[Int, Int]()
    for id in reported_ids:
        counts[id] = counts.get(id, 0) + 1
        # Key not found? Count defaults to 0.

    # Dicts don't guarantee order, so sort the entries before printing them.
    var pairs = List[Tuple[Int, Int]]()
    for entry in counts.items():
        pairs.append((entry.key, entry.value))

    for i in range(len(pairs)):
        for j in range(i + 1, len(pairs)):
            if pairs[j][0] < pairs[i][0]:
                var tmp = pairs[i]
                pairs[i] = pairs[j]
                pairs[j] = tmp

    for pair in pairs:
        print(t"station {pair[0]}: {pair[1]} readings")
    # station 1: 5 readings
    # station 3: 4 readings
    # station 5: 6 readings
    # ANCHOR_END: tally

    # ANCHOR: lookup_set
    var reported: Set[Int] = {}
    for id in reported_ids:
        reported.add(id)

    for station in range(1, 6):
        print(
            t"Station {station} reported? "
            t"{'Yes' if station in reported else 'No'}"  # TStrings allow concatenation
        )
    # Station 1 reported? Yes
    # Station 2 reported? No
    # Station 3 reported? Yes
    # Station 4 reported? No
    # Station 5 reported? Yes
    # ANCHOR_END: lookup_set

    # ANCHOR: silent_stations
    var expected = Set[Int](1, 2, 3, 4, 5)
    var missing = expected - reported
    print(t"silent stations: {missing}")  # {2, 4} in either order
    # ANCHOR_END: silent_stations

    # ANCHOR: tuple_keys
    var per_day = Dict[Tuple[Int, Int], Int]()
    for i in range(len(reported_ids)):
        var key = (reported_ids[i], days[i])
        per_day[key] = per_day.get(key, 0) + 1

    for entry in per_day.items():
        var station, day = entry.key  # unpack the tuple key
        print(t"station {station}, day {day}: {entry.value}")
    # ANCHOR_END: tuple_keys

    # ANCHOR: build_set
    var per_day_set = Set[Tuple[Int, Int]]()
    for i in range(len(reported_ids)):
        per_day_set.add((reported_ids[i], days[i]))
    # ANCHOR_END: build_set

    # ANCHOR: comprehension
    var missing_days = [
        String(t"Station {station} - Day {day}")
        for station in [1, 3, 5]  # the three stations that report at all
        for day in range(3)
        if (station, day) not in per_day_set
    ]
    # ANCHOR_END: comprehension

    # ANCHOR: print_missing
    print(t"missing days: {missing_days}")  # ['Station 1 - Day 1']
    # ANCHOR_END: print_missing
    # ANCHOR_END: final
