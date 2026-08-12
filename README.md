# Advent of Mojo

Advent of Mojo is a hands-on workbook for learning
[Mojo](https://mojolang.org/) by writing real code. It combines short
explanations, runnable examples, and exercises, aimed at developers who already
know how to program and want a working Mojo vocabulary — not a language
specification.

The book is built with [mdBook](https://rust-lang.github.io/mdBook/). Source
chapters live under [`src/`](src/), and custom styling lives under
[`theme/`](theme/).

Every runnable Mojo example lives in its own file under
[`snippets/`](snippets/), one subdirectory per chapter, and each chapter
pulls its examples into the prose with mdBook's `{{#include}}` syntax. This
keeps the snippets themselves compilable and testable independent of the
book text. Every snippet has a paired test under [`tests/`](tests/) that
imports it directly and checks its behavior.

## Reading the book

Chapters are listed in reading order in [`src/SUMMARY.md`](src/SUMMARY.md),
starting with [`welcome.md`](src/welcome.md) and
[`install.md`](src/install.md).

## Building locally

This is a [pixi](https://pixi.sh) project — it declares `mojo` and `mdbook`
as dependencies so you don't need either installed globally.

```bash
# Install pixi if you don't have it
curl -fsSL https://pixi.sh/install.sh | sh

# Build the static site into ./book
pixi run book

# Or serve it locally with live reload
pixi run serve

# Run one of the extracted snippets directly
pixi run mojo snippets/mojo_basics/analyzer.mojo
```

## Tests

Every file under `snippets/` has one paired test under `tests/`, at the
same relative path, that imports the snippet and checks its behavior. Run
the whole suite with `pixi run test`. See [`tests/README.md`](tests/README.md)
for the naming convention and how to run a single test.

## Contributing

File issues or open pull requests against this directory. See
[`.github/CODEOWNERS`](.github/CODEOWNERS) for maintainers.
