# Work with files 🔥

Every Advent puzzle arrives as a file of input, and the first thing you do is
read it. Here you'll write a temperature log to disk, read it back, and prove
the round-trip, the same moves you'll make on every puzzle in December.

## Save some temperatures

Temporary files let you work with real files without invented paths or
cleaning up after yourself. The `NamedTemporaryFile` type creates them
for you in your system's temporary directory.

Create a new file, `temp_log.mojo`. Add this code and run it.
Note the path of the newly created file and hop over to
check it from your OS.

```mojo
from std.tempfile import NamedTemporaryFile

def main() raises:
    var content = "20.5, 22.3, 19.8, 25.1"  # temperatures
    var path: String  # scoped to `main()`

    with NamedTemporaryFile(delete=False) as f:  # context manager
        f.write(content)
        path = f.name

    # file is closed here

    print(t"Wrote to {path}")
```

Mojo's `with` statement manages resources using a _context manager_.
Managers use setup (`__enter__()`) and cleanup (`__exit__()`) operations
defined in custom types.

Cleanup (`__exit__()`) will always run at the end of the manager's scope,
even if you raise an error.

When the manager reaches the end of scope, `NamedTemporaryFile` closes the
file handle (`f`) in `__exit__()`. Normally it deletes the temporary
file but `delete=False` overrides that.

### Try this

Remove `delete=False` and re-run the code. The `print` still fires, but the
path it shows is gone after `with` completes. Put `delete=False` back in
after you test.

## Propagating errors

Your app's entry point, `def main()`, declares `raises` because file
operations may error. You either handle errors directly with a
`try`/`except` statement or let `main()` raise the errors and crash
from an uncaught exception.

### Try this

In a scratch file, write:

```mojo
def main() raises:

    with open("path/to/nonexistent/file.txt", "r") as f:
        var content = f.read()
```

- Remove `raises` to see the _compilation_ error.
- Remove `raises` _and_ embed the context manager in a `try`/`except`
statement to handle the _runtime_ error without crashing.
- Use a path to an existing text file and print the `content`.

## File guards

Wrap string-based paths in a `Path` to ask questions.
Add this import to the top of your file:

```mojo
from std.pathlib import Path
```

And add this at the end of `main()` and run it:

```mojo
    var p = Path(path)
    print(t"Exists: {p.exists()}, is file: {p.is_file()}") # True and True
```

### Checkpoint

- `exists()`, `is_file()`, and `is_dir()` return `Bool` without raising.
  Broken symlinks return `False`.
- Use `exists()` to check whether the file is there. You may still encounter
  OS race conditions, so production code should handle errors with
  `try`/`except`.
- `Path(".").listdir()` returns a `List[Path]` for everything in a directory.

### Try this

For nested paths, join them with the `/` operator. Add this to a
scratch file:

```mojo
from std.pathlib import Path

def main():
    var q = Path("data") / "today.txt"
    print(q)  # data/today.txt
```

The `Path` value is valid, but it won't point to a real file unless you
happen to have "data/today.txt" lying around:

```mojo
# ... previous content

print(q.exists())  # False
```

## Read a file

Read the file back and confirm that it contains the same string.
`Path.read_text()` is the one-liner whole-file read. Add this to the end of
your code:

```mojo
    var roundtrip = p.read_text()
    print(roundtrip)  # 20.5, 22.3, 19.8, 25.1
```

Run it.

### Checkpoint

- `print()` adds the newline. There isn't one in your original
  string or your file.
- `read_text()` opens, reads the whole file as a `String`, and closes the
  file without a context manager.
- `write_text(value)` is the matching write side for `Path`. It creates the
  file or overwrites whatever was there.
- These two are the 80% case. Reach for them whenever you're working with a
  whole file at once.
- For bytes instead of text, use `read_bytes()` and `write_bytes()`. See
  the API references for details.

## Validate

Compare the two strings by adding this line:

```mojo
    print(t"Match: {content == roundtrip}")
```

### Checkpoint

- A round-trip check is a sanity check, not a proof. It catches mismatches
  caused by problems such as truncated or incorrectly encoded output. It
  doesn’t prove that you wrote the intended content.
- `String` equality is value-based. Strings with the same contents compare
  as equal.
- Not all types can be compared but `String`s can.
- Mojo strings use bytewise lexical ordering.

### Deeper Checkpoint for the curious

- Mojo strings implement both `Equatable` (`==` comparison) and
  `Comparable` (ordering comparisons like `<` and `>=`).
- Lexical ordering means both `"aa" < "ab"` and `"AA" < "aa"` are `True`.
  Capital letters appear first in ASCII tables. Mojo compares overlapping
  bytes, then falls back to length.

## Append content

Use `open()` with `"a"` (append) to add content to the end of your file:

```mojo
    with open(p, "a") as f:
        f.write(", 26.0")
   # file is closed again after `with`

    print(p.read_text())
```

### Checkpoint

- `open(path, mode)` returns a `FileHandle`. Modes: `"r"` read, `"w"` write
  (truncates), `"rw"` read-write, `"a"` append.
- You don't need to import `open()`. Mojo's prelude makes it available
  automatically.
- Inside the block, `f.write(value)` writes any `Writable` value.
  `f.read()` and `f.read_bytes()` cover the read side.

## Add user input

Remove the `f.write(...)` line and add:

```mojo
        while value := input("Today's high (°C): "):
            f.write(t", {value}")
```

The walrus assignment (`:=`) binds the `value` you enter so you can write it
into the file. Enter a few readings and then press return without typing.

### Checkpoint

- Strings are truthy. An empty entry is `False`, ending the `while` loop.
- `input(prompt)` prints the prompt with no trailing newline, reads one
  line from stdin, returns a `String`.
- `input()` raises if stdin can't be read.

## Convert strings to floating point

Update the code to convert your input to floating point. If you enter
"15", it will record "15.0". If you enter "fifteen", you'll error.
The input loop continues after showing an error message:

```mojo
    with open(p, "a") as f:
        while value := input("Today's high (°C): "):
            try:
                var fp = Float64(value)
                f.write(t", {fp}")
            except e:
                print(t"Invalid input '{value}': {e}")
```

## Clean up

When creating the temporary file, you set `delete=False`. The temp file
is yours to manage. Remove it.

Add this import at the top:

```mojo
from std.os import remove
```

At the end of `main()`, add:

```mojo
    if p.exists():
        remove(p)
    print(t"After cleanup, exists: {p.exists()}")
```

### Checkpoint

- `remove(path)` raises if the path can't be removed (missing, a directory,
  permission denied).
- Use `exists()` to check whether the file is there. You may still encounter
  OS race conditions, so production code should handle errors with
  `try`/`except`.
- For directories, use `rmdir` for empty ones or `removedirs`
  for nested ones.

### Try this

- Call `remove(p)` twice. The second call raises because the file is
  already gone. If you need "remove if it exists," check first.

## Final code

Your complete `temp_log.mojo`:

```mojo
from std.tempfile import NamedTemporaryFile
from std.pathlib import Path
from std.os import remove, rmdir, removedirs

def main() raises:
    var content = "20.5, 22.3, 19.8, 25.1"  # temperatures
    var path: String

    with NamedTemporaryFile(delete=False) as f:  # context manager
        f.write(content)
        path = f.name

    print(t"Wrote to {path}")

    var p = Path(path)
    print(t"Exists: {p.exists()}, is file: {p.is_file()}")

    var roundtrip = p.read_text()
    print(roundtrip)

    print(t"Match: {content == roundtrip}")

    with open(p, "a") as f:
        while value := input("Today's high (°C): "):
            try:
                var fp = Float64(value)
                f.write(t", {fp}")
            except e:
                print(t"Invalid input '{value}': {e}")

    print(p.read_text())

    if p.exists():
        remove(p)
    print(t"After cleanup, exists: {p.exists()}")
```

## What you touched

Temporary files, context managers, reading, writing, and deleting files,
paths and file checks, user input, the walrus operator, truthy strings,
type conversion.

## Also worth knowing

**Bytes**:

Every text call has a bytes sibling. `Path.write_bytes(span)`,
`Path.read_bytes()`, `f.write_bytes(span)`, `f.read_bytes()`. Use
`String.as_bytes()` to get a `Span[Byte]` from a string.

A `Byte` aliases `UInt8`.

**Scratch directories**:

`from std.tempfile import TemporaryDirectory`
works like `NamedTemporaryFile` but for a directory tree.

**Path parts**:

`Path("a/b/c.txt").name` is `"c.txt"`. `split`, `basename`, `dirname`, and
`getsize` cover the rest. Import them from `std.os.path`
