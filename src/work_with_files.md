# Work with files 🔥

<div class="intro">
  <div class="intro-text">

Most Advent puzzles begin with a text file full of input. Before you can
solve anything, you have to load that data into your program.

In this chapter you'll read a temperature log, inspect the file that
holds it, create your own report, and update it as new readings arrive.
Along the way you'll meet `Path`, `FileHandle`, and Mojo's context
managers: the same tools you'll use again and again throughout Advent.

  </div>

  <picture class="intro-image">
    <source
      srcset="img/files-dark.png"
      media="(prefers-color-scheme: dark)"
    >
    <img
      src="img/files-bright.png"
      alt="Mojo inspecting a North Pole temperature monitor."
    >
  </picture>
</div>

## Grab your data

Things are getting a little frosty at the North Pole.

Santa embraced the Internet of Things years ago, and temperature sensors
are scattered all over the workshop. Rudolph worries about visibility
for the sleigh, but his nephew Chiller records the daily sensor logs.

Download the sample input used for this page:

[temp_log.txt](./downloads/temp_log.txt)

Place it in your work folder, next to where you'll build your program.

## Read the sensor log

Unlike the previous page, your data already exists. That's how Advent
of Code usually works. You download the puzzle input and let your
program do the reading. Create `temp_log.mojo` so you can start reading:

``` mojo
from std.pathlib import Path

def main() raises:
    var log = Path("./temp_log.txt")
    print(log.read_text())  # -20.5, -22.3, -19.8, -25.1, etc
```

Run this to make sure your content matches the file.

### Checkpoint

- `Path` wraps a filesystem path.
- `read_text()` opens the file, reads the whole file as a `String`,
  then closes it again. If you duplicate the final line here, you
  get the same data.
- Whole-file reads are the 80% case for Advent inputs.

### Try this

File operations can fail. That's why `main()` declares `raises`.

Try changing `"temp_log.txt"` to a filename that doesn't exist (like
"path/to/nowhere", unless you actually have a file with that path). Then:

- Remove `raises` and observe the _compile-time error._
- Restore `raises`, then catch the _runtime error_ with `try`/`except`.
- Put the filename back when you're finished.

### Checkpoint

Ask the filesystem a few questions before you continue. These are good
calls to have on-hand in your Mojo vocabulary:

``` mojo
print(t"Exists: {log.exists()}")
print(t"File:   {log.is_file()}")
print(t"Dir:    {log.is_dir()}")
```

- `exists()`, `is_file()`, and `is_dir()` return `Bool`.
- Production code knows about race conditions and should be ready to handle
  failures between checks and operations.

## Create a report

The elves want proof that today's sensor log arrived before anyone
starts analyzing it. Add this:

``` mojo
var report = Path("report.txt")

report.write_text(
    String.write(
        "North Pole Temperature Report",
        "=============================",
        "",
        "Input: temp_log.txt",
        "Status: Received",
        "",
        "Waiting for analysis...",
        "",
        sep="\n",
    )
)
```

Open `report.txt` in your editor.

### Checkpoint

- `write_text()` creates the file if needed.
- If it already exists, the old contents are replaced.
- Like `read_text()`, it handles opening and closing the file for you.
- The extra blank line gives you a carriage return at the end.

## Append content

Just as you're about to leave, Chiller radios in one last temperature.

Rather than replacing the report, append the new reading, which is -52.3.
Oof, it's cold out there.

``` mojo
with open(report, "a") as f:
    var value = -52.3
    f.write(t"\nLate reading: {Float64(value)} °C")
```

Check the report to see the new line.

### Checkpoint

- `open(path, mode)` returns a `FileHandle`. Modes: `"r"` read, `"w"` write
  (truncates), `"rw"` read-write, `"a"` append.
- You don't need to import `open()`. Mojo's prelude makes it available
  automatically.
- `FileHandle.write()` accepts any `Writable` value.
- Inside the block, `f.write(value)` writes any `Writable` value.
  `f.read()` and `f.read_bytes()` cover the read side.

## Context managers

When you call `open()`, it returns a _context manager_ typed as
`FileHandle`. Context managers are types that implement two methods:
`__enter__()` and `__exit__()`. Mojo calls these at the start and exit of
`with` statements, helping you add custom code for set-up and tear-down.

`FileHandle` automatically close the file they're managing when execution
leaves the `with` block. Managers run `__exit__()` whether the block ends
normally or with errors.

You focus on reading and writing, instead of having to close the file
directly.

### Checkpoint

- The binding used for `as` (in this case binding `f`) should always be
  a context manager.
- Context managers use duck typing. Implement the two dunder methods
  (methods whose names start and end with double underscores), and use the
  type for `with`. There's no context manager trait.

## Clean up

You just got notice from Santa's security point-elf. Apparently, unlike
your raw data, the report you generated is proprietary to North Pole
Operations. Time to perform your polar data safety protocol:

``` mojo
from std.os import remove

try:
    if report.exists():
        remove(report)
except e:
    print(t"Security protocol violation. File removal failed: {e}")

print(t"After cleanup, exists: {report.exists()}")
```

### Checkpoint

- `remove()` deletes a file and raises if the operation fails.
- Generated files are good candidates for cleanup. Puzzle inputs usually
  stick around for future runs.
- For production, make sure you cover race conditions and other situations
  where removing the file fails with `try`/`except` statements.
- For directories, use `rmdir()` for empty ones or `removedirs()` for
  nested ones.

## What you touched

`Path`, whole-file reads and writes, file guards, `FileHandle`, context
managers, appending to files, error propagation, user input, and
cleanup.

## Also worth knowing

**Bytes**

Every text API has a bytes equivalent: `read_bytes()`, `write_bytes()`,
`FileHandle.read_bytes()`, and `FileHandle.write_bytes()`.

**Temporary files**

`NamedTemporaryFile` creates scratch files that clean themselves up
automatically. They're perfect for intermediate data, but most Advent
puzzles work directly with an input file like the one you used here.

**Scratch directories**

`TemporaryDirectory` provides the same convenience for whole directory
trees.

**Path composition**

Use the `/` operator to build nested paths:

``` mojo
var log = Path("data") / "temp_log.txt"
```

## Final code

Your complete `temp_log.mojo`:

```mojo
from std.pathlib import Path
from std.os import remove

def main() raises:
    var log = Path("./temp_log.txt")
    print(log.read_text())

    print(t"Exists: {log.exists()}")   # True
    print(t"File:   {log.is_file()}")  # True
    print(t"Dir:    {log.is_dir()}")   # False

    var report = Path("report.txt")

    report.write_text(
        String.write(
            "North Pole Temperature Report",
            "=============================",
            "",
            "Input: temp_log.txt",
            "Status: Received",
            "",
            "Waiting for analysis...",
            "",
            sep="\n",
        )
    )

    with open(report, "a") as f:
        var value = -52.3
        f.write(t"\nLate reading: {Float64(value)} °C")
    print(report.read_text())

    try:
        if report.exists():
            remove(report)
    except e:
        print(t"Security protocol violation. File removal failed: {e}")

    print(t"After cleanup, exists: {report.exists()}")
```

## What you touched

Context managers, reading, writing, and deleting files, paths and file
checks, user input.

## Also worth knowing

**Bytes**:

Every text call has a bytes sibling. `Path.write_bytes(span)`,
`Path.read_bytes()`, `f.write_bytes(span)`, `f.read_bytes()`. Use
`String.as_bytes()` to get a `Span[Byte]` from a string.

A `Byte` aliases `UInt8`.

**Scratch directories**:

`from std.tempfile import TemporaryDirectory, NamedTemporaryFile`
helps you work with temporary content.

**Path parts**:

`Path("a/b/c.txt").name` is `"c.txt"`. `split`, `basename`, `dirname`, and
`getsize` cover the rest. Import them from `std.os.path`
