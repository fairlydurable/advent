# EXPECT-EXIT: nonzero
# Claims:
# - List indexing checks bounds by default and terminates the process on a
#   violation. Nothing unwinds and no `except` can catch it.
# - The `try` block below never reaches its `except`.


def main():
    var readings: List[Int] = [12, 14, 9]
    var index = len(readings) + 4
    try:
        print(readings[index])
    except e:
        print("unreachable: bounds failures are not errors", e)
