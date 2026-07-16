# Sort and summarize values 🔥

Your puzzle wants the coldest day, the warmest, and a running total. Here's what
you need: sort a list, read off its extremes, add it up, and filter it down.

## The week's readings

You have one reading per day and the day names beside them. Create
`summary.mojo`:

```mojo
def main() raises:
    var days = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    var readings: List[Float64] = [22.1, 19.8, -2.5, 25.0, 18.7]
    print(t"{len(readings)} readings")
```

## Sort to rank

Sorting puts the readings in order, and once they're ordered the coldest and
warmest sit at the two ends.

Add the import at the top:

```mojo
from std.builtin.sort import sort
```

Sort a copy so the original day order stays intact:

```mojo
    var ordered = readings.copy()
    sort(ordered)
    print(t"sorted: {ordered}")  # [-2.5, 18.7, 19.8, 22.1, 25.0]
    print(t"coldest: {ordered[0]}, warmest: {ordered[len(ordered) - 1]}")
```

### Checkpoint

- `sort` is a free function, not a method. It sorts in place and ascending, so it
  returns nothing and rewrites the list you pass.
- Sort a `.copy()` when you still need the original order. Here `readings` stays
  aligned with `days`.
- For a custom order (largest first, by some field), `sort` also accepts a
  comparison function. Ascending is the common case, so it's the default here.

## Top of the list

Once a list is sorted ascending, the largest values are simply the last ones. No
second pass needed.

```mojo
    var n = len(ordered)
    print(t"top 3 warmest: {ordered[n - 1]}, {ordered[n - 2]}, {ordered[n - 3]}")
```

### Checkpoint

- After an ascending sort, the top *k* values are the last *k*, read back to
  front.
- This is the "top three" move puzzles ask for constantly: sort once, then take
  from the end.

## Add it up

Mojo has no `sum` that swallows a whole list, so total it with a loop, the same
pattern you used for the average earlier.

```mojo
    var total = 0.0
    for r in readings:
        total += r
    var mean = total / Float64(len(readings))
    print(t"total: {round(total, 1)}, mean: {round(mean, 2)}")
```

### Checkpoint

- `min` and `max` take individual values or a few arguments, not a whole list.
  For a list's extremes, sort and read the ends, as you did above.
- `round(value, digits)` tidies a float for display. Floating-point totals carry
  representation noise, so `83.1` prints cleaner than the raw `83.10000000000001`.

## Filter it down

A comprehension with an `if` builds a new list from only the values that pass a
test. Pull out the readings below freezing:

```mojo
    var below = [r for r in readings if r < 0.0]
    print(t"below freezing: {below}")  # [-2.5]
```

### Checkpoint

- `[expr for x in it if cond]` keeps only the elements where `cond` is true.
- The filter runs as the list builds, so you never construct the rejects.

## Pair the days

`zip` walks two lists in step, handing you one value from each. Use it to line
readings back up with their day names.

```mojo
    for day, r in zip(days, readings):
        print(t"{day}: {r}")
```

### Checkpoint

- `zip` yields a tuple per step, unpacked here into `day` and `r`. It's in the
  prelude, so no import.
- It stops at the shorter list, so mismatched lengths won't run off the end.

## Final code

Your complete `summary.mojo`:

```mojo
from std.builtin.sort import sort


def main() raises:
    var days = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    var readings: List[Float64] = [22.1, 19.8, -2.5, 25.0, 18.7]

    # sort to rank
    var ordered = readings.copy()
    sort(ordered)
    print(t"sorted: {ordered}")  # [-2.5, 18.7, 19.8, 22.1, 25.0]
    print(t"coldest: {ordered[0]}, warmest: {ordered[len(ordered) - 1]}")

    # top 3 warmest are the last three after an ascending sort
    var n = len(ordered)
    print(t"top 3 warmest: {ordered[n - 1]}, {ordered[n - 2]}, {ordered[n - 3]}")

    # add it up
    var total = 0.0
    for r in readings:
        total += r
    var mean = total / Float64(len(readings))
    print(t"total: {round(total, 1)}, mean: {round(mean, 2)}")

    # filter below freezing
    var below = [r for r in readings if r < 0.0]
    print(t"below freezing: {below}")  # [-2.5]

    # pair each day with its reading
    for day, r in zip(days, readings):
        print(t"{day}: {r}")
```

## What you touched

Sorting a list in place, reading extremes and top-*k* from the ends, totaling and
averaging with a loop, `round` for display, filtered comprehensions, and `zip`
to walk two lists together.

Next, the sensors spread out across a field, and the readings arrive as a grid
you walk cell by cell.
