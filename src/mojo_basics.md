# Mojo basics 🔥

<!-- markdownlint-disable MD024 -->

<div class="intro">
  <div class="intro-text">

Advent of Code is an annual series of programming puzzles released every
December. Many puzzles share a common format: grab some data, loop over it,
evaluate a pattern, and compute the output. This example challenge follows the
same steps. The toolkit demonstrated to solve this challenge will help you hit
the ground running on any Advent of Code puzzle you pick up.

At the North Pole, a set of workshop sensors has recorded one week of
temperature readings. Before anyone can spot problems in the heating
system, they need a program that can inspect the data.

  </div>

  <div class="intro-image">
    <img
      class="intro-image-light"
      src="img/temperature-light.png"
      alt="Mojo inspects a North Pole temperature monitor."
    >
    <img
      class="intro-image-dark"
      src="img/temperature-dark.png"
      alt="Mojo inspects a North Pole temperature monitor."
    >
  </div>
</div>

## Hello Mojo

Create `analyzer.mojo` in your favorite IDE or editor.

Start with a message that identifies your new tool:

```mojo
{{#include ../snippets/mojo_basics/analyzer.mojo:hello}}
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
{{#include ../snippets/mojo_basics/analyzer.mojo:list}}
```

Mojo's `TString` adds string interpolation, building a string template with
braces. Mojo replaces the braced expressions with their values. `TString`
braces can contain expressions, including function calls, arithmetic,
and values, not just variable names.

## Loops

Before looking for patterns, print each day's reading so you can see what
the sensors recorded.

Add this code to `main()` under the existing print statement:

```mojo
{{#include ../snippets/mojo_basics/analyzer.mojo:for_in}}
```

Improve readability, and remove the call to `len()`, with enumeration:

```mojo
{{#include ../snippets/mojo_basics/analyzer.mojo:enumerate}}
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
{{#include ../snippets/mojo_basics/analyzer.mojo:for_else}}
```

## Functions

The workshop receives new readings every day. Put the average calculation
in a function so the analyzer can reuse it.

Add this function above `main()`:

```mojo
{{#include ../snippets/mojo_basics/calculate_average.mojo:calc_avg}}
```

Add this code to the end of `main()` to call the function:

```mojo
{{#include ../snippets/mojo_basics/calculate_average.mojo:call_avg}}
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
{{#include ../snippets/mojo_basics/calculate_average.mojo:classify}}
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
{{#include ../snippets/mojo_basics/error_handling.mojo:raises_check}}
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
{{#include ../snippets/mojo_basics/error_handling.mojo:handle_errors}}
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
{{#include ../snippets/mojo_basics/mean.mojo:main_raises}}
```

With an empty list, the program then terminates with an unhandled
exception.

## Final code

Your complete `analyzer.mojo`:

```mojo
{{#include ../snippets/mojo_basics/error_handling.mojo:final}}
```

The analyzer can now store sensor readings, inspect them, calculate their
average, classify the week, and report missing data.

The North Pole has its first working analysis tool.

## Topics covered

Mojo variables, lists, loops, functions, conditionals, and error handling.

## Extras

<details>
<summary><b>Sidequest</b>: Discover `mean()`</summary>

Now that `calculate_average()` can raise errors, try Mojo's built-in
`mean()` function. It is also a raising call:

- Add `from max.algorithm import mean` to the start of your file.
- Replace the manual calculation after the empty check with
  `return mean(temps)`.

```mojo
{{#include ../snippets/mojo_basics/mean.mojo:snippet}}
```

</details>

<!-- markdownlint-enable MD024 -->
