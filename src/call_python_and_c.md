# Call Python and C libraries 🔥

**WORK IN PROGRESS**

Your puzzle is solved, but one question hangs over the season: is the Pole
actually warming, or is that just the midday sun on station 3? Here's what you
need: hand your readings to Python's numpy to fit a trend, and to a C library to
crunch them at native speed. Mojo links to both.

Mojo solves the whole season on its own. This page is about reach: when a
library you already trust does exactly what you want, you call it instead of
reimplementing it.

## The question

You corrected the sun bias back on the toolkit page, so these readings measure
climate, not sunshine. Skip that correction and you'd fit a trend to the
weather on station 3's roof.

Create `warming.mojo`:

```mojo
def main() raises:
    var days = [0, 1, 2, 3, 4]
    # readings already corrected for the midday sun on station 3
    var readings: List[Float64] = [19.0, 19.5, 20.1, 20.4, 21.2]
    print(t"{len(readings)} days")
```

## Call Python: fit a trend with numpy

`numpy` fits a line in one call. Its `polyfit` returns the slope and intercept,
and the slope's sign answers the question.

Add the import at the top:

```mojo
from std.python import Python
```

Then, in `main()`:

```mojo
    try:
        var np = Python.import_module("numpy")

        var xs = Python.list()
        for d in days:
            xs.append(d)
        var ys = Python.list()
        for r in readings:
            ys.append(r)

        var fit = np.polyfit(xs, ys, 1)  # [slope, intercept]
        var slope = fit[0]               # degrees per day
        print(t"trend: {slope} C/day")   # ~0.53, rising
        print(t"warming? {slope > 0}")   # True
    except:
        print("numpy not found. Add it with `pixi add numpy`.")
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
from std.ffi import OwnedDLHandle, c_int, c_double
```

Then, in `main()`:

```mojo
    try:
        var blas = OwnedDLHandle(
            "/System/Library/Frameworks/Accelerate.framework/Accelerate"
        )
        comptime origin = origin_of(readings)

        # cblas_dasum(count, X, stride) sums |X| in one C call
        var dasum = blas.get_function[
            def(c_int, UnsafePointer[c_double, origin], c_int)
            thin abi("C") -> c_double
        ]("cblas_dasum")

        var total = dasum(c_int(len(readings)), readings.unsafe_ptr(), c_int(1))
        print(t"season mean: {total / Float64(len(readings))}")  # 20.04
        _ = blas  # keep the handle alive to the end of the call
    except:
        print("BLAS not found.")
```

### Checkpoint

- `OwnedDLHandle(path)` opens a shared library. It raises when the library is
  absent, so the same `try`/`except` probe works here as for numpy.
- `get_function` names the C signature. `thin abi("C")` says a plain C function;
  `c_int` and `c_double` are the C-sized aliases (`c_double` is `Float64`), so
  your `List[Float64]` passes straight through.
- `readings.unsafe_ptr()` hands C the array's memory. Get the pointer right
  before the call; anything that grows the list can move it.
- macOS ships BLAS inside the Accelerate framework, shown here. On Linux the
  library is `libopenblas.so` or `libblas.so.3`, usually installed separately.

## Final code

Your complete `warming.mojo`:

```mojo
from std.python import Python
from std.ffi import OwnedDLHandle, c_int, c_double


def main() raises:
    var days = [0, 1, 2, 3, 4]
    # readings already corrected for the midday sun on station 3
    var readings: List[Float64] = [19.0, 19.5, 20.1, 20.4, 21.2]

    # --- Python: fit a trend line with numpy ---
    try:
        var np = Python.import_module("numpy")
        var xs = Python.list()
        for d in days:
            xs.append(d)
        var ys = Python.list()
        for r in readings:
            ys.append(r)
        var fit = np.polyfit(xs, ys, 1)  # [slope, intercept]
        var slope = fit[0]               # degrees per day
        print(t"trend: {slope} C/day")   # ~0.53, rising
        print(t"warming? {slope > 0}")   # True
    except:
        print("numpy not found. Add it with `pixi add numpy`.")

    # --- C: reduce the readings with BLAS ---
    try:
        var blas = OwnedDLHandle(
            "/System/Library/Frameworks/Accelerate.framework/Accelerate"
        )
        comptime origin = origin_of(readings)
        var dasum = blas.get_function[
            def(c_int, UnsafePointer[c_double, origin], c_int)
            thin abi("C") -> c_double
        ]("cblas_dasum")
        var total = dasum(c_int(len(readings)), readings.unsafe_ptr(), c_int(1))
        print(t"season mean: {total / Float64(len(readings))}")  # 20.04
        _ = blas
    except:
        print("BLAS not found.")
```

## What you touched

Importing a Python module, gating an import with `try`/`except`, building a
`Python.list` to cross the boundary, working with a `PythonObject`, loading a C
library with `OwnedDLHandle`, naming a C signature for `get_function`, the
`c_int` and `c_double` aliases, and passing an array to C with `unsafe_ptr`.

You started the season printing one line and finished it linking Mojo to Python
and C to answer a real question. The whole toolkit, from a first `print` to the
outside world, is yours now. Go solve some puzzles.
