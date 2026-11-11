# The Mojonomicon

The Mojonomicon covers the unchecked side of Mojo: ownership and origins,
data layout, uninitialized memory, destructors and linear types, error paths,
concurrency and atomics, building a growable list and an atomically
reference-counted pointer from raw allocations, and calling C. Its outline
follows the Rustonomicon, and it teaches Mojo on its own terms.

The book targets Mojo 1.3 nightlies. Mojo's pointer and allocation APIs
changed in 1.3, so samples written for older releases often fail to compile.

## Layout

- `src/`: the chapters, one Markdown file per chapter, plus `SUMMARY.md`.
- `src/code/`: every sample as a standalone `.mojo` file, one directory per
  chapter. Each chapter quotes its samples verbatim and links to the file.
- `theme/`: styling and the Mojo syntax highlighter.
- `run_samples.sh`: compiles and runs every sample and checks it against the
  contract in its header comments.

## Reading the book

```sh
pixi run serve
```

This builds the book and serves it at <http://localhost:3000>, rebuilding on
every save. `pixi run book` builds once into `book/`. Pushing to `main`
publishes the book to GitHub Pages through `.github/workflows/pages.yml`.

## Checking the samples

```sh
pixi run test
```

To check against a different compiler, set `MOJO` and run the script
directly:

```sh
MOJO=/path/to/mojo ./run_samples.sh src/code/03-ownership
```

A sample with no marker must compile, run, and exit 0. A sample marked
`# EXPECT-ERROR:` must fail to compile, and its `# EXPECT-MATCH:` regex must
match the compiler output. A sample marked `# EXPECT-EXIT: nonzero` must
compile and then exit nonzero at run time.
