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

## Call Python: fit a trend with numpy

`numpy` fits a line in one call. Its `polyfit` returns the slope and intercept,
and the slope's sign answers the question.

Add the import at the top:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:numpy_import}}
```

Then, in `main()`:

```mojo
{{#include ../snippets/call_python_and_c/warming.mojo:numpy_fit}}
```

### Checkpoint

- `Python.import_module` loads any module the active Python can see. It raises
  when the module is missing, so wrap it in `try`/`except` and the program keeps
  running instead of crashing.
- `numpy` isn't part of Mojo. Add it to your project (`pixi add numpy`) so the
  import succeeds. `re`, `math`, and the rest of Python's standard library ship
  with Python and need no install.
- `np.array` won't take a Mojo `List` directly, so build a `Python.list()` and
  append into it. Cross the boundary once, in bulk, not once per value.
- `slope` is a `PythonObject`. Compare it in Python space (`slope > 0`) rather
  than converting it back to a Mojo `Float64`.
- The raw slope carries float noise. Its sign is the answer you came for.

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

- `OwnedDLHandle(path)` opens a shared library. It raises when the library is
  absent, so the same `try`/`except` probe works here as for numpy.
- `get_function` names the C signature. `thin abi("C")` says a plain C function;
  `c_int` and `c_double` are the C-sized aliases (`c_double` is `Float64`), so
  your `List[Float64]` passes straight through.
- `readings.unsafe_ptr()` hands C the array's memory. Get the pointer right
  before the call; anything that grows the list can move it.
- `cblas_dasum` sums magnitudes, not signed values. Every station 3 reading is
  below zero, so negating the result hands back the real mean.
- macOS ships BLAS inside the Accelerate framework, shown here. On Linux the
  library is `libopenblas.so` or `libblas.so.3`, usually installed separately.

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
