# Tests

Every file under `snippets/` has exactly one paired test file here, at the
same relative path, named `<snippet>_test.mojo`. For example:

| Snippet                                                       | Test                                                            |
|---------------------------------------------------------------|-----------------------------------------------------------------|
| `snippets/pull_numbers_from_text/pull_numbers_from_text.mojo` | `tests/pull_numbers_from_text/pull_numbers_from_text_test.mojo` |
| `snippets/reuse_your_code/toolkit/__init__.mojo`              | `tests/reuse_your_code/toolkit_test.mojo`                       |

The test suffix isn't just a naming convention: a test file and its
snippet share a module name (e.g. both resolve to `pull_numbers_from_text`),
and Mojo will report "attempt to resolve a recursive reference" if a test
file's own basename collides with the module it's importing.

## What a test does

Tests import the real snippet module and exercise it — they never
copy-paste the snippet's code inline. Two shapes show up:

- **Snippets with standalone functions** (`toolkit/__init__.mojo`,
  `pull_numbers_from_text.mojo`'s `extract_ints`, the `calculate_average`
  variants in `mojo_basics/`) get real unit tests: import the function,
  assert on specific inputs and outputs with `std.testing`
  (`assert_equal`, `assert_almost_equal`, `assert_raises`, `assert_true`).
- **Snippets that are a single `main()`** with everything inline (most
  page walkthroughs) get an end-to-end test: import `main` under an alias
  and call it, asserting it completes without raising. Where `main()` has
  an observable side effect — `work_with_files/temp_log.mojo` creates and
  then removes `report.txt` — the test asserts on that side effect
  directly (e.g. the file is gone afterward) instead of just checking
  that nothing raised.

Snippets that read from a file under `src/downloads/` (temp logs, station
reports, grid data) are exercised against that real file, so a test
failure usually means the snippet's assumptions and the data file have
drifted apart — check both when fixing one.

## Running tests

Run the whole suite from the repo root:

```bash
pixi run test
```

Run a single test directly with `mojo run`, passing `-I` so Mojo can find
the paired snippet's directory:

```bash
mojo run -I snippets/pull_numbers_from_text \
    tests/pull_numbers_from_text/pull_numbers_from_text_test.mojo
```

The `-I` path always matches the snippet's directory, not the test's.
