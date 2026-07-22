# Mojo basics 🔥

<div class="intro">
  <div class="intro-text">

Advent of Code drops a fresh puzzle every midnight in December. Many
puzzles start with the same basic work: grab some data, loop over it, make
decisions, and survive bad input.

At the North Pole, a set of workshop sensors has recorded one week of
temperature readings. Before anyone can spot problems in the heating
system, they need a program that can inspect the data.

You'll build that program here, creating the basic toolkit you'll use
throughout the workbook.

  </div>

  <picture class="intro-image">
    <source
      srcset="img/temperatures-dark.png"
      media="(prefers-color-scheme: dark)"
    >
    <img
      src="img/temperatures-bright.png"
      alt="Mojo inspecting a North Pole temperature monitor."
    >
  </picture>
</div>

## Hello Mojo

Create `analyzer.mojo` in your favorite IDE or editor.

Start with a message that identifies your new tool:

```mojo
def main():
    print("North Pole Temperature Analyzer")
```

Run it:

```bash
mojo analyzer.mojo
```

### Checkpoint

- If you see "North Pole Temperature Analyzer", your setup works.
- All Mojo executables use `main()` as their entry point.

## Variables and data

The workshop sensors have already collected four temperature readings.
Store them in a list so your analyzer can work with them.

Update your file:

```mojo
def main():
    print("North Pole Temperature Analyzer")

    # Square brackets tell Mojo the `List` type at compile time
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]

    print(t"Recorded {len(temps)} temperatures")  # TStrings are templates
```

Mojo's `TString` adds string interpolation, building a string template with
braces. Mojo replaces the braced expressions with their values.

### Try this

A `TString` is a template, not a `String`. Its braces can contain
expressions, including function calls, arithmetic, and values, not just
variable names.

Open a throwaway file, then compile and run this example to see expressions
in action:

```mojo
from std.random import seed, random_si64

# Int is your machine-sized integer. Int64 has a fixed width.
# Normally they're the same, but on older hardware they may differ.
def function_returning_random_number() -> Int64:
    return random_si64(1, 10)

def function_returning_string() -> String:
    var t_string = t"one plus one is {1 + 1}"  # Set up TString
    return String(t_string)                    # Explicit cast

def main():
    seed()  # Seeds the random number generator
    var string: String = function_returning_string()     # Assignment works
    print(string + "!")        # Strings can be added, "one plus one is 2!"
    print(t"{function_returning_random_number()}")    # A number in [1, 10]
```

## Loops

Before looking for patterns, print each day's reading so you can see what
the sensors recorded.

Add this code to `main()` under the existing print statement:

```mojo
def main():
    # ... existing code ...

    for index in range(len(temps)):  # The range is [0, len(temps))
        print(t"  Day {index + 1}: {temps[index]}°C")
```

Improve readability, and remove the call to `len()`, with enumeration:

```mojo
for index, temp in enumerate(temps):
    print(t"  Day {index + 1}: {temp}°C")
```

### Checkpoint

- The `range()` function is your `for` loop workhorse.
- If you don't use a loop index, replace it with a discard:
  `for _ in ...`.
- Mojo also has `while` loops. They work exactly as you expect.
- All Mojo loops support `break` to stop the loop, `continue` to start
  the next iteration, and `return` to leave the loop and return from the
  function.

### Try this

A particularly Mojo addition is the loop `else` clause. It runs when a
loop finishes normally. If you `break`, the `else` block doesn't run:

```mojo
def main():
    for _ in range(5):
        print("Loop iteration")
        # break  # Uncomment to break and bypass `else:`
    else:
        print("Loop completed without break.")
```

## Functions

The workshop receives new readings every day. Put the average calculation
in a function so the analyzer can reuse it.

Add this function above `main()`:

```mojo
def calculate_average(temps: List[Float64]) -> Float64:
    var total: Float64 = 0.0
    var count: Int = 0
    for temp in temps:  # Iterate over collection values
        total += temp
        count += 1
    return total / Float64(count)

def main():
    # ... existing code ...
```

Add this code to the end of `main()` to call the function:

```mojo
    var avg = calculate_average(temps)
    print(t"Average: {round(avg, 2)}°C")  # Average: -21.92°C
```

### Checkpoint

- Place return types after arrow tokens.
- Functions and methods without return arrows return `None`.
- Like all compound statements, `calculate_average()` needs a colon
  before its body.
- Function bodies must use consistent indentation. Mojo convention uses
  four spaces.
- Use `round()` to specify the number of digits after the decimal point.

## Conditionals

The elves need more than a number. Classify the week's average so they can
quickly see whether the workshop was cool, comfortable, or hot.

Add this code to the end of `main()`:

```mojo
    if avg > -20.0:
        print("Status: Hot week")
    elif avg > -25.0:
        print("Status: Comfortable week")
    else:
        print("Status: Cool week")
```

### Checkpoint

- Add as many `elif` clauses as you need, from zero to many.
- Mojo has a Python-like conditional expression:
  `value if condition else alt_value`.
- Mojo doesn't have an Elvis operator.

## Raise errors

Sometimes a sensor fails and produces no readings. Your analyzer should
notice instead of trying to calculate an average from an empty list.

Update `calculate_average()` so the function can raise an error:

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
```

What changed:

- You added `raises` before the return arrow.
- You added an empty-list check.
- You raised an `Error` when the list contained no readings.

## Handle errors

A missing sensor report shouldn't leave the elves wondering what happened.
Catch the error and print a useful message.

Return to `main()` and wrap the average calculation and classification in
`try` and `except`:

```mojo
    try:
        var avg = calculate_average(temps)
        print(t"Average: {round(avg, 2)}°C")

        if avg > -20.0:
            print("Status: Hot week")
        elif avg > -25.0:
            print("Status: Comfortable week")
        else:
            print("Status: Cool week")
    except e:
        print("Error:", e)
```

To test the error, replace `temps` with `List[Float64]()`. This constructs
an empty list of `Float64` values.

Confirm that your program reports `No temperature data`, then restore the
original readings.

### Checkpoint

`try` and `except` statements support `else` and `finally` blocks:

- If the `try` block completes without raising an error, control passes
  to the `else` block, when present.
- A `finally` block always runs, whether the program catches an error or
  completes the `try` or `else` block.

If you omit the `try` and `except` handling, you must allow `main()` to
raise. Add `raises` before the colon:

```mojo
def main() raises:
    # ...
```

With an empty list, the program then terminates with an unhandled
exception.

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
    print("North Pole Temperature Analyzer")
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    print(t"Recorded {len(temps)} temperatures")

    for index, temp in enumerate(temps):
        print(t"  Day {index + 1}: {temp}°C")

    try:
        var avg = calculate_average(temps)
        print(t"Average: {round(avg, 2)}°C")  # Average: -21.92°C

        if avg > -20.0:
            print("Status: Hot week")
        elif avg > -25.0:
            print("Status: Comfortable week")
        else:
            print("Status: Cool week")

    except e:
        print("Error:", e)
```

The analyzer can now store sensor readings, inspect them, calculate their
average, classify the week, and report missing data.

The North Pole has its first working analysis tool.

## What you touched

Mojo variables, lists, loops, functions, conditionals, and error handling.

## Extras

<details>
<summary><b>Sidequest</b>: Discover `mean()`</summary>

### It's dangerous to go alone. Take this function call

Now that `calculate_average()` can raise errors, try Mojo's built-in
`mean()` function. It is also a raising call:

- Add `from std.algorithm import mean` to the start of your file.
- Replace the manual calculation after the empty check with
  `return mean(temps)`.

```mojo
from std.algorithm import mean

def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")

    return mean(temps)
```

</details>
