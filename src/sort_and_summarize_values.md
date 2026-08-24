# Sort and summarize values 🔥

<!-- markdownlint-disable MD024 -->

<div class="intro">
  <div class="intro-text">

Manipulating data helps you identify patterns and trends. When your
puzzle wants the coldest and warmest readings, for example, it helps to use
Mojo sorting and filtering.

  </div>

  <div class="intro-image">
    <img
      class="intro-image-light"
      src="img/tallied-light.png"
      alt="Mojo with tallied data."
    >
    <img
      class="intro-image-dark"
      src="img/tallied-dark.png"
      alt="Mojo with tallied data."
    >
  </div>
</div>

## The station readings

Create `sort_and_summarize_values.mojo`. Read
[station_reports.txt](./downloads/station_reports.txt) and pull out each
reading's temperature, alongside a label so you can trace a value back to
the entry it came from:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:program}}
```

## Sort to rank

Sorting orders the list, so you can pick the coldest and
warmest readings from the two ends.

Import `sort` at the top of your file:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:import_sort}}
```

Sort a copy so the original order stays intact:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:sort_body}}
```

### Checkpoint

- `sort()` is a free function, not a method. It sorts in place and
  ascending, so it returns nothing and rewrites the list you pass.
- Sort a `.copy()` when you need the original ordering. Here `readings`
  stays aligned with `labels`.

## Top of the list

Once a list is sorted, the largest values are at the end. Slice off the
last three to retrieve them in ascending order:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:top3}}
```

### Checkpoint

- This provides the "top three" that many puzzles ask for: sort once, then
take from the end.

## Reduce your data

You've been asked to find the average temperature across every reading.

Import `sum()`, `min()`, and `max()` from the reduction package:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:import_reduction}}
```

Call `sum()` and divide by `count`. This line also rounds the result to a
single decimal place.

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:avg_print}}
```

### Checkpoint

- `round(value, digits)` tidies a float for display. Floating-point totals
  carry representation noise. `round()` helps you control that.
- The reduction package lets you use `sum()`, `product()`, `min()`,
  `max()`, and `mean()`.

## Filter it down

Use a comprehension filtered for the most extreme readings to build a new
list:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:filter_body}}
```

### Checkpoint

- `[expr for x in it if cond]` keeps only the elements where `cond` is true.
- The filter runs as the list builds, so you never construct the rejects.

## Pair the readings with their labels

The `labels` list has important information you need to tell _which_
station and day a reading belongs to.

`zip()` combines two lists, allowing you to walk through paired values in step.
Use this to align readings with their labels:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:zip_loop}}
```

### Checkpoint

- `zip()` yields a tuple per step, unpacked here into `label` and `r`.
- If the lists have different lengths, `zip()` stops at the shorter list,
  so you won't run off the end.

## Match the readings to the extremes

Using `max()` and `min()`, fetch the minimum and maximum values without
sorting:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:minmax_setup}}
```

Knowing the values helps you find their original indices in `readings`:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:try_except}}
```

Wrapping your calls to `index()` in a `try`/`except` statement ensures
that any errors will be caught and reported.

If you'd like to see that error in action, tweak either value. For example
`.index(min_value + 1.0)`.

## Final code

Your complete `sort_and_summarize_values.mojo`:

```mojo
{{#include ../snippets/sort_and_summarize_values/sort_and_summarize_values.mojo:final}}
```

## Topics covered

Sorting, reductions (`sum()`, `min()`, `max()`), filtered comprehensions,
`zip()`, and locating values with `index()`.

<!-- markdownlint-enable MD024 -->
