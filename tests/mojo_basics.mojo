# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #

from std.testing import (
    assert_equal,
    assert_almost_equal,
    assert_raises,
    assert_true,
)
from std.algorithm import mean
from std.random import seed, random_si64

# --- Code under test (copied from mojo_basics.md) ---


def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")

    var total: Float64 = 0.0
    var count: Int = 0
    for temp in temps:
        total += temp
        count += 1
    return total / Float64(count)


def calculate_average_mean(temps: List[Float64]) raises -> Float64:
    # Sidequest version using std.algorithm.mean
    if len(temps) == 0:
        raise Error("No temperature data")
    return mean(temps)


def function_returning_string() -> String:
    var t_string = t"one plus one is {1 + 1}"
    return String(t_string)


def function_returning_random_number() -> Int64:
    return random_si64(1, 10)


# --- Tests ---


def test_calculate_average() raises:
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    var avg = calculate_average(temps)
    print(t"Average: {avg}")
    assert_almost_equal(avg, -21.925, atol=1e-9)


def test_calculate_average_raises_on_empty() raises:
    var empty = List[Float64]()
    with assert_raises(contains="No temperature data"):
        _ = calculate_average(empty)


def test_calculate_average_mean_matches() raises:
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    var avg_manual = calculate_average(temps)
    var avg_mean = calculate_average_mean(temps)
    assert_almost_equal(avg_manual, avg_mean, atol=1e-9)


def test_tstring_string_return() raises:
    var s = function_returning_string()
    print(s)
    assert_equal(s, "one plus one is 2")


def test_random_number_in_range() raises:
    seed()
    var n = function_returning_random_number()
    print(t"{n}")
    assert_true(n >= 1 and n <= 10)


def test_enumerate_loop() raises:
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    var count: Int = 0
    for index, temp in enumerate(temps):
        print(t"  Day {index + 1}: {temp}°C")
        count += 1
    assert_equal(count, len(temps))


def test_loop_else_runs_without_break() raises:
    var completed_normally = False
    for _ in range(5):
        print("Loop iteration")
    else:
        completed_normally = True
    assert_true(completed_normally)


def test_loop_else_skipped_with_break() raises:
    var completed_normally = False
    for _ in range(5):
        break
    else:
        completed_normally = True
    assert_true(not completed_normally)


def main() raises:
    test_calculate_average()
    test_calculate_average_raises_on_empty()
    test_calculate_average_mean_matches()
    test_tstring_string_return()
    test_random_number_in_range()
    test_enumerate_loop()
    test_loop_else_runs_without_break()
    test_loop_else_skipped_with_break()
    print("All tests passed.")
