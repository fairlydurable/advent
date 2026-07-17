# Mojo basics 🔥

Advent of Code drops a fresh puzzle every midnight in December, and every
one starts the same way: hold some data, loop it, branch on it, survive bad
input. This page builds that toolkit on one week of temperature readings, the
dataset you'll carry through the whole workbook.

## Hello Mojo

Create `analyzer.mojo` in your favorite IDE or editor.

Add this to `analyzer.mojo`:

```mojo
def main():
    print("Temperature Analyzer")
```

Run it:

```bash
mojo analyzer.mojo
```

### Checkpoint

- If you see "Temperature Analyzer", your setup works.
- All Mojo executables use `main()` as their entry point.

## Variables and data

Update your file to add temperature data:

```mojo
def main():
    print("Temperature Analyzer")

    # Square brackets tell Mojo the `List` type at compile time
    var temps: List[Float64] = [20.5, 22.3, 19.8, 25.1]

    print(t"Recorded {len(temps)} temperatures")  # TString
```

Mojo's `TString` adds string interpolation to the language using a
string template with braces. Mojo can replace the braced expressions
with their values.

This is a template, not a `String`. That means you can use it with
`print()` because Mojo automatically converts it to a string. Printing is
the #1 use case for `TStrings`. It also means you can't return it in
place of a string.

When you want to return a value, you need to cast. Open a throwaway file,
then compile and run this:

```mojo
def function_returning_string() -> String:
    var t_string = t"one plus one is {1 + 1}"  # Set up TString
    return String(t_string)                    # Explicit cast

def main():
    var string: String = function_returning_string()
    print(string)  # one plus one is 2
```

Remove the `String` cast and return `t_string` to see the error.

### Checkpoint

- TString expressions use braces. You can do math, call functions,
  or interpolate values by name.
- After removing the cast, the compiler error tells you a lot
  about how Mojo represents a `TString`.

## Loops

Print each temperature. Add this code to `main()` under the print statement:

```mojo
def main():
    # ... existing code ...

    for index in range(len(temps)):  # The range is [0, len(temps))
        print(t"  Day {index + 1}: {temps[index]}°C")
```

Improve readability (and ditch the call to `len()`) with enumeration:

```mojo
for index, temp in enumerate(temps):
    print(t"  Day {index + 1}: {temp}°C")
```

### Checkpoint

- The `range()` function is your `for loop` workhorse.
- If you don't use a loop index, replace it with a discard: `for _ in ...`.
- Mojo also has `while` loops. They work exactly as you'd expect.
- All Mojo loops support `break` (stop the loop), `continue` (next
  iteration), and `return` (leave the loop and return with or without a
  value).

A particularly Mojo add-on is the loop `else` clause. It runs when a loop
finishes normally. If you `break`, it won't run `else`:

```mojo
def main():
    for _ in range(5):
        print("Loop iteration")
        # break # uncomment this to break and bypass `else:`
    else:
        # always prints for completed loops
        print("Loop completed without break.")
```

## Functions

Add this function above `main()` to calculate the average temperature:

```mojo
def calculate_average(temps: List[Float64]) -> Float64:
    var total: Float64 = 0.0
    var count: Int = 0
    for temp in temps:  # iterate over collection values
        total += temp
        count += 1
    return total / Float64(count)

def main():
    # ... existing code ...
```

Add this code to the end of `main()` to call the function:

```mojo
    var avg = calculate_average(temps)
    print(t"Average: {round(avg, 2)}°C")  # Average: 21.92°C
```

### Checkpoint

- Place return types after arrow tokens. Functions and methods without
  return arrows return `None`.
- Like all compound statements, `calculate_average()` needs a colon
  before the body starts.
- Function bodies must be indented and do so consistently. 4-space convention.
- Use `round()` to specify the digits after the decimal.

## Conditionals

Classify the average temperature. Add to the end of `main()`:

```mojo
    if avg > 25.0:
        print("Status: Hot week")
    elif avg > 20.0:
        print("Status: Comfortable week")
    else:
        print("Status: Cool week")
```

### Checkpoint

- Add as many `elif` clauses as you need, from zero to many.
- Mojo has Python-like ternary: `value if condition else alt_value`.
  There's no "Elvis" operator in the language.

## Raise errors

Handle empty data by updating `calculate_average`. Now the function
can raise an error.

```mojo
def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:  # Empty list of temperatures
        raise Error("No temperature data")

    var total: Float64 = 0.0
    var count: Int = 0
    for temp in temps:
        total += temp
        count += 1
    return total / Float64(count)
```

What changed:

- You add `raises` before the return arrow.
- You add the empty list check.
- You raise an `Error` if the list's empty.

## Handle errors

Now that you have a raising function, return to `main()`. Wrap your code
with `try-except` for error handling:

```mojo
    try:
        var avg = calculate_average(temps)
        print(t"Average: {round(avg, 2)}°C")

        if avg > 25.0:
            print("Status: Hot week")
        elif avg > 20.0:
            print("Status: Comfortable week")
        else:
            print("Status: Cool week")
    except e:
        print("Error:", e)
```

To test the error, replace `temps` with `List[Float64]()`. It constructs
an empty list of `Float64` values. Confirm that your app errors with "No
temperature data". After, revert your code.

### Checkpoint

`try`/`except` statements support `else` and `finally` blocks:

- If the `try` block runs without raising an error, control passes to
  the `else` block, if defined.
- When included, a `finally` block always runs. It doesn't matter if you
  caught an error or ran `else` block.

If you omit the `try`/`except` handling, you must allow `main()` to raise.
Add `raises` before the colon. When using an empty list, the program
terminates with an unhandled exception.

```mojo
def main() raises:
    # ...
```

## Final code

Your complete `analyzer.mojo`:

```mojo
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
```

## What you touched

Mojo variables, lists, loops, functions, conditionals, and error handling.

## Extras

<details>
<summary><b>Sidequest</b>: Discover 'mean()'</summary>

### It's dangerous to go alone. Take this function call

Using the raising version of `calculate_average()` lets you try out Mojo's
built-in `mean()` function. It's an error raising call:

- Add `from std.algorithm import mean` to the start of your file.
- Replace the math after the empty check with `return mean(temps)`.

```mojo
from std.algorithm import mean

def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:  # Empty list of temperatures
        raise Error("No temperature data")

    return mean(temps)  # raising
```

</details>
