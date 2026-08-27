# Call Python and C libraries 🔥

<!-- markdownlint-disable MD024 -->

<div class="intro">
  <div class="intro-text">

Your puzzle is solved, but one question hangs over the season: is the Pole
actually warming, or is that just the midday sun on station 3? Here's what you
need: hand your readings to Python's numpy to fit a trend, and to a C library to
crunch them at native speed. Mojo links to both.

Mojo solves the whole season on its own. This page is about reach: when a
library you already trust does exactly what you want, you call it instead of
reimplementing it.

> [!NOTE]
> Advent of Mojo is a work in progress. Content, examples, and structure
> may change. If you've found a bug, have a suggestion, or want to flag
> something confusing, or any other reason, please open a thorough
> ***Documentation*** issue on the
> [Modular GitHub](https://github.com/modular/modular/issues).
>
> This link may change when Advent is broken off to its own repository.

  </div>

  <div class="intro-image">
    <img
      class="intro-image-light"
      src="img/interop-light.png"
      alt="Mojo connects to C and Python libraries."
    >
    <img
      class="intro-image-dark"
      src="img/interop-dark.png"
      alt="Mojo connects to C and Python libraries."
    >
  </div>
</div>

## The question

Station 3 is the one with the sun problem: readings taken between 10:00 and
14:00 run warm because the sensor bakes in direct light. Pull station 3's
entries back out of [station_reports.txt](./downloads/station_reports.txt)
and correct them the same way you did on the toolkit page, so the trend you
fit measures climate, not sunshine on a roof.

Create `warming.mojo`:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:first_program}}
```

Day 1's only station 3 reading lands at noon, right in the sun-bias window,
so it comes in at a suspiciously warm `-18.5C`. The correction knocks it back
down to `-20.0`, right in line with the rest of the season. Skip the
correction and the trend still looks like it's warming, just by a slightly
inflated amount.

### Checkpoint

- Type the `days` and `readings` declarations explicitly. Without the
  annotations, Mojo infers `Array` instead of `List`.
- Wrap text-to-number conversion in `try`/`except`. Input text may not
  contain a valid number.
- Chained comparisons evaluate as pairwise comparisons joined by `and`.
  This expression:

  ```mojo
  10 <= Float64(hour_string) < 14
  ```

  is equivalent to:

  ```mojo
  10 <= Float64(hour_string) and Float64(hour_string) < 14
  ```

## Call Python: fit a trend with numpy

`numpy` fits a line in one call. Its `polyfit` function returns the slope and
intercept. The sign of the slope answers the question: "Is it warming?"

Add imports at the top:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:numpy_import}}
```

Then, in `main()`:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:numpy_fit}}
```

### Checkpoint

- `Python.import_module()` loads any module the active Python can see. It
  raises if the module is missing, so use `try`/`except` to handle the error.
- `numpy` isn't part of Mojo. Add it to your project with `pixi add numpy`.
  Python standard library modules such as `re` and `math` need no separate
  install.
- `np.array()` doesn't accept a Mojo `List` directly. Build a `Python.list()`
  and append the values, crossing the Python boundary once instead of once
  per value.
- `slope` is a `PythonObject`. Compare it in Python space (`slope > 0`)
  instead of converting it to a Mojo `Float64`.
- The exact slope includes floating-point noise. Its sign is all you need
  to answer whether the readings are warming.

## Call C: crunch with BLAS

BLAS is a C numeric library that ships on every platform. Load it and call a
function by name to reduce the whole array in one shot.

Add the FFI imports at the top:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:blas_import}}
```

Then, in `main()`:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:blas_reduce}}
```

### Checkpoint

- `OwnedDLHandle(path)` opens a shared library. It raises if the library is
  missing, so use the same `try`/`except` probe as for NumPy.
- `get_function()` specifies the C signature. `thin abi("C")` declares a plain
  C function, while `c_int` and `c_double` match C's integer and double types.
  `c_double` is an alias for `Float64`, so the readings need no conversion.
- `readings.unsafe_ptr()` gives C a pointer to the list's storage. Get the
  pointer immediately before the call. Growing the list can move its storage
  and invalidate the pointer.
- `cblas_dasum` sums absolute values. Because every station 3 reading is
  negative, negate the result before calculating the mean.
- macOS provides BLAS through the Accelerate framework used here. On Linux,
  use `libopenblas.so` or `libblas.so.3`, which usually requires a separate
  installation.

## Final code

Your complete `warming.mojo`:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:final}}
```

## Topics covered

Importing a Python module, gating an import with `try`/`except`, building a
`Python.list` to cross the boundary, working with a `PythonObject`, loading a C
library with `OwnedDLHandle`, naming a C signature for `get_function`, the
`c_int` and `c_double` aliases, and passing an array to C with `unsafe_ptr`.

You started the season printing one line and finished it linking Mojo to Python
and C to answer a real question. The whole toolkit, from a first `print` to the
outside world, is yours now. Go solve some puzzles.

<!-- markdownlint-enable MD024 -->
