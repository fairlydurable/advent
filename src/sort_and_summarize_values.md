# Sort and summarize values 🔥

Manipulating data helps you get to the truths hidden within it. When your
puzzle wants the coldest and warmest days, for example, it helps to use
Mojo sorting and filtering.

## The week's readings

Your puzzle supplies you with the names of each weekday and a temperature
reading for each day. Create `summary.mojo`:

```mojo
def main() raises:
    var days = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    var readings: List[Float64] = [22.1, 19.8, -2.5, 25.0, 18.7]
    var count = len(readings)
    print(t"{count} readings")  # 5 readings
```

## Sort to rank

Sorting helps you order the list, so you can pick the coldest and
warmest days from the two ends.

Import `sort` at the top of your file:

```mojo
from std.builtin.sort import sort
```

Sort a copy so the original day order stays intact:

```mojo
var ordered = readings.copy()
sort(ordered)
print(t"sorted: {ordered}")  # [-2.5, 18.7, 19.8, 22.1, 25.0]
print(t"coldest: {ordered[0]}, warmest: {ordered[count - 1]}")
```

### Checkpoint

- `sort()` is a free function, not a method. It sorts in place and
  ascending, so it returns nothing and rewrites the list you pass.
- Sort a `.copy()` when you need the original ordering. Here `readings`
  stays aligned with `days`.

## Top of the list

Once a list is sorted, the largest values are at the end. Slice off the
last three to retrieve them in ascending order:

```mojo
print(t"top 3 warmest: {ordered[(count - 3):]}")  # [19.8, 22.1, 25.0]
```

### Checkpoint

- This is the "top three" move puzzles ask for constantly: sort once, then
  take from the end.

## Reduce your data

You've been asked to find the average temperature over the five-day period.

To sum your list, add the following import:

```mojo
from std.algorithm.reduction import sum
```

Call `sum()` and divide by `count`. This line also rounds the result to a
single decimal place.

```mojo
print(t"average: {round(sum(readings) / Float64(count), 1)}")  # 16.6
```

### Checkpoint

- `round(value, digits)` tidies a float for display. Floating-point totals
  carry representation noise. `round()` helps you control that.

## Filter it down

Use a comprehension filtered for negative values to build a new list:

```mojo
var below = [r for r in readings if r < 0.0]
print(t"below freezing: {below}")  # [-2.5]
```

### Checkpoint

- `[expr for x in it if cond]` keeps only the elements where `cond` is true.
- The filter runs as the list builds, so you never construct the rejects.

## Pair the days

The `days` list has important information you need to tell _when_ the
weather extreme happened.

`zip()` combines two lists, allowing you to walk them in step. It hands you
one value from each. Use this to align readings with their day names:

```mojo
for day, r in zip(days, readings):
    print(t"{day}: {r}")
```

### Checkpoint

- `zip()` yields a tuple per step, unpacked here into `day` and `r`.
- If the lists have different lengths, `zip()` stops at the shorter list,
  so you won't run off the end.

## Match the days to the extremes

Using std.algorithm.reduction, import `min()` and `max()`, then fetch the
minimum and maximum values without sorting:

```mojo
from std.algorithm.reduction import sum, min, max

# ...

var max_value = max(readings)  # 25.0
var min_value = min(readings)  # -2.5
```

Knowing the values helps you find their original indices in `readings`:

```mojo
try:
    var min_index = readings.index(min_value)
    print(t"Coldest day: {days[min_index]} with {min_value}°C")
    var max_index = readings.index(max_value)
    print(t"Hottest day: {days[max_index]} with {max_value}°C")
except e:
    print(e)
```

Wrapping your calls to `index()` in a `try`/`except` statement ensures
that any errors will be caught and reported.

If you'd like to see that error in action, tweak either value. For example
`.index(min_value + 1.0)`.

### Checkpoint

- The reduction package lets you use `sum()`, `product()`, `min()`,
  `max()`, and `mean()`.

## Final code

Your complete `summary.mojo`:

```mojo
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
```

## What you touched

Sorting, reductions (`sum()`, `min()`, `max()`), filtered comprehensions,
`zip()`, and locating values with `index()`.
