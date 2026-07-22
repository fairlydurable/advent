# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
from std.builtin.sort import sort
from std.algorithm.reduction import sum, min, max


def main() raises:
    var days = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    var readings: List[Float64] = [22.1, 19.8, -2.5, 25.0, 18.7]
    var count = len(readings)
    print(t"{count} readings")  # 5 readings

    var ordered = readings.copy()
    sort(ordered)
    print(t"sorted: {ordered}")  # [-2.5, 18.7, 19.8, 22.1, 25.0]
    print(t"coldest: {ordered[0]}, warmest: {ordered[count - 1]}")
    print(t"top 3 warmest: {ordered[(count - 3):]}")
    print(t"average: {round(sum(readings) / Float64(count), 1)}")  # 16.6

    var below = [r for r in readings if r < 0.0]
    print(t"below freezing: {below}")  # [-2.5]

    for day, r in zip(days, readings):
        print(t"{day}: {r}")

    var max_value = max(readings)  # 25.0
    var min_value = min(readings)  # -2.5

    try:
        var min_index = readings.index(min_value)
        print(t"Coldest day: {days[min_index]} with {min_value}°C")
        var max_index = readings.index(max_value)
        print(t"Hottest day: {days[max_index]} with {max_value}°C")
    except e:
        print(e)
