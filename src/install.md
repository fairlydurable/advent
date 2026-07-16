# Install Mojo 🔥

This workbook uses the Mojo nightly build.

## System requirements

Ensure your system supports Mojo.

<details>
  <summary>🍎 macOS</summary>
  <p>
  macOS requirements:
  </p>
  <ul>
    <li>macOS Sequoia (15) or later</li>
    <li>Apple silicon (M1 or later)</li>
    <li>8 GiB minimum for Mojo development.</li>
    <li>Xcode or Xcode Command Line Tools 16 or later on macOS.</li>
  </ul>
</details>
<details>
  <summary>🐧 Linux</summary>
  <p>
  Linux requirements:
  </p>
  <ul>
    <li>glibc 2.34 or later. For example, Ubuntu 22.04 LTS or later.</li>
    <li>x86-64-v3 (Haswell-class or newer; CPUs from approximately 2013 onward) or ARM64 Neoverse N1 or newer (for example, AWS Graviton2 and later)</li>
    <li>8 GiB RAM minimum for Mojo development</li>
    <li>A C compiler (such as cc, gcc, or clang), used as a linker.</li>
  </ul>
</details>
<details>
  <summary>🪟 Windows</summary>
  <p>
    Windows isn't officially supported. Try Mojo on Windows using
    <a href="https://learn.microsoft.com/en-us/windows/wsl/install">WSL</a>
    with Ubuntu 22.04 LTS.
  </p>
</details>

## Install

Pick an installer. Each one creates a project directory and virtual
environment with Mojo.

<details>
  <summary>Install with pixi (recommended)</summary>
  <p>
    <a href="https://pixi.sh">Pixi</a> handles package management and
    virtual environments with lock files and cross-language support.
  </p>

```bash
# Install pixi
curl -fsSL https://pixi.sh/install.sh | sh

# Create project with Modular channels (Release)
pixi init hello-world \
  -c https://conda.modular.com/max/ -c conda-forge \
  && cd hello-world

# OR

# Create project with Modular channels (Nightly)
pixi init hello-world \
  -c https://conda.modular.com/max-nightly/ -c conda-forge \
  && cd hello-world

# Install Mojo
pixi add mojo

# Enter the pixi environment
pixi shell
```

Configure pixi to automatically use nightly Mojo builds:

```bash
echo 'default-channels = ["https://conda.modular.com/max-nightly",' \
     '"conda-forge"]' >> ~/.pixi/config.toml 
```

</details>

<details>
  <summary>Install with uv</summary>

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create project and environment
uv init hello-world && cd hello-world
uv venv && source .venv/bin/activate

# Install Mojo (Release)
uv pip install mojo \
  --index https://whl.modular.com/nightly/simple/ \
```

## Install Mojo (Nightly)

uv pip install mojo \
  --index https://whl.modular.com/nightly/simple/ \
  --prerelease allow

```text

The `--prerelease allow` flag is required only when installing beta
(or dev) builds.

</details>

**After installing**:

Run `source ~/.bashrc` (or `source ~/.zshrc` on Mac) to refresh your
paths, then verify with `mojo --version`.

## VS Code extension

Install the
[Mojo extension](https://marketplace.visualstudio.com/items?itemName=modular-mojotools.vscode-mojo)
for syntax highlighting, code completion, and debugging. Also available on
[Open VSX](https://open-vsx.org/extension/modular-mojotools/vscode-mojo).
Verify the publisher is Modular.

## Update Mojo

* **pixi**: `pixi update mojo`
* **uv**: `uv sync --upgrade-package mojo`

## Uninstall Mojo

* **pixi**: `pixi remove mojo && exit`
* **uv**: `uv pip uninstall mojo && uv sync && deactivate`
