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

# ANCHOR: import_sort
from std.builtin.sort import sort

# ANCHOR_END: import_sort


def main() raises:
    # ANCHOR: program
    var log = Path("src/downloads/station_reports.txt")
    var lines = log.read_text().splitlines()

    var labels = List[String]()
    var readings: List[Float64] = []

    for line in lines:
        # ['Station 3', 'Day 0', '06:00', '-22.3C', 'Clear']
        var fields = line.split(", ")
        labels.append(String(t"{fields[0]}, {fields[1]}, {fields[2]}"))
        readings.append(Float64(fields[3].removesuffix("C")))

    var count = len(readings)
    print(t"{count} readings")  # 15 readings
    # ANCHOR_END: program

    # ANCHOR: sort_body
    var ordered = readings.copy()
    sort(ordered)
    print(t"sorted: {ordered}")
    # [-41.7, -32.0, -31.5, -30.1, -29.0, -28.4, -24.0, -23.1, -22.3, -22.3,
    #  -21.7, -21.0, -20.5, -18.5, -18.2]
    print(t"coldest: {ordered[0]}, warmest: {ordered[count - 1]}")
    # ANCHOR_END: sort_body

    # ANCHOR: top3
    print(t"top 3 warmest: {ordered[(count - 3):]}")  # [-20.5, -18.5, -18.2]
    # ANCHOR_END: top3

    # ANCHOR: avg_print
    var total: Float64 = 0.0
    for r in readings:
        total += r

    print(t"average: {round(total / Float64(count), 1)}")  # -25.6
    # ANCHOR_END: avg_print

    # ANCHOR: filter_body
    var extreme = [r for r in readings if r < -30.0]
    print(t"extreme readings: {extreme}")  # [-30.1, -31.5, -32.0, -41.7]
    # ANCHOR_END: filter_body

    # ANCHOR: zip_loop
    for label, r in zip(labels, readings):
        print(t"{label}: {r}")
    # ANCHOR_END: zip_loop

    # ANCHOR: minmax_setup
    var max_value = Float64.MIN  # -inf, so any reading beats it
    var min_value = Float64.MAX  # +inf, so any reading undercuts it

    for r in readings:  # one pass finds both extremes
        if r > max_value:
            max_value = r
        if r < min_value:
            min_value = r

    # max_value: -18.2 (warmest), min_value: -41.7 (coldest)
    # ANCHOR_END: minmax_setup

    # ANCHOR: try_except
    try:
        var min_index = readings.index(min_value)
        print(t"Coldest reading: {labels[min_index]} at {min_value}°C")
        var max_index = readings.index(max_value)
        print(t"Warmest reading: {labels[max_index]} at {max_value}°C")
    except e:
        print(e)
    # ANCHOR_END: try_except
    # ANCHOR_END: final
