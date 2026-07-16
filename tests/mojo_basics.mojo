# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")

    var total: Float64 = 0.0
    var count: Int = 0
    for temp in temps:
        total += temp
        count += 1
    return total / Float64(count)


def main():
    print("Temperature Analyzer")
    var temps: List[Float64] = [20.5, 22.3, 19.8, 25.1]
    print(t"Recorded {len(temps)} temperatures")

    for index, temp in enumerate(temps):  # The index is [0, len(temps))
        print(t"  Day {index + 1}: {temp}°C")

    try:
        var avg = calculate_average(temps)
        print(t"Average: {round(avg, 2)}°C")  # Average: 21.92°C

        if avg > 25.0:
            print("Status: Hot week")
        elif avg > 20.0:
            print("Status: Comfortable week")
        else:
            print("Status: Cool week")

    except e:
        print("Error:", e)
