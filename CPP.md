# Starting a C++ project

How to create a C++ project that works with the Neovim + clangd setup this repo
installs. Copy the files below; only `CMakeLists.txt` changes between projects.

## What each tool does

| Tool | Job |
|---|---|
| Nix / flake | Downloads and pins exact tool versions. Nothing is installed to the Mac. |
| direnv | Activates those tools on `cd` into the folder. |
| CMake | Reads `CMakeLists.txt`, generates build instructions. |
| Ninja | Runs those instructions, calling the compiler. |
| clang++ | The compiler. Turns `.cpp` into a program. |
| clangd | Reads the code, feeds Neovim errors, definitions, completion. |

CMake does not compile. Ninja does not understand C++. The compiler does the work.

## Setup

```sh
mkdir -p ~/github/myproject/src && cd ~/github/myproject
git init
```

Git first, always. Nix only reads files that Git tracks. Skipping this gives
`Path 'flake.nix' is not tracked by Git`; the fix is always `git add -A`.

## `flake.nix`

Which tools this project needs. Copy verbatim, change the name.

```nix
{
  description = "myproject";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      llvm = pkgs.llvmPackages_22;
    in {
      devShells.${system}.default = (pkgs.mkShell.override { stdenv = llvm.stdenv; }) {
        packages = [ pkgs.cmake pkgs.ninja llvm.clang-tools ];
      };
    };
}
```

- `inputs.nixpkgs.url` - package collection, same release this repo pins.
- `system` - Apple Silicon. Intel is `x86_64-darwin`.
- `llvmPackages_22` - **must be 22.** ASan hangs forever on macOS 26 with LLVM 21
  and with Apple clang, from a compiler-rt bug in `get_dyld_hdr()`. Fixed in 22.
- `mkShell.override { stdenv = llvm.stdenv; }` - makes the compiler come from the
  same `llvm` as clangd. Mismatched versions make clangd read the standard library
  with the wrong internals and report errors the build does not have.
- `packages` - what lands on PATH: cmake, ninja, clangd, clang-format.

## `.envrc`

```
use flake
```

Then once per project:

```sh
direnv allow
```

direnv refuses to run an unapproved `.envrc`, so a cloned repo cannot silently run
code. After approval, `cd` in and the tools appear in about 0.2s.

## `CMakeLists.txt`

The only file edited regularly.

```cmake
cmake_minimum_required(VERSION 4.1)
project(myproject LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(myproject
  src/main.cpp
)
target_include_directories(myproject PRIVATE include)
target_compile_options(myproject PRIVATE -Wall -Wextra -Wpedantic)

option(SANITIZE "Extra runtime checks while developing" OFF)
if(SANITIZE)
  target_compile_options(myproject PRIVATE
    -fsanitize=address,undefined -fno-sanitize-recover=all
    -g -fno-omit-frame-pointer)
  target_link_options(myproject PRIVATE -fsanitize=address,undefined)
endif()
```

- `cmake_minimum_required(VERSION 4.1)` - matches the CMake the flake pins.
- `project(... LANGUAGES CXX)` - C++ only, skips probing for a C compiler.
- `CMAKE_CXX_STANDARD 23` - use C++23.
- `..._REQUIRED ON` - fail loudly instead of silently falling back to an older standard.
- `CMAKE_CXX_EXTENSIONS OFF` - standard C++23, not GNU's dialect.
- `CMAKE_EXPORT_COMPILE_COMMANDS ON` - **this is what makes the editor work.**
  Writes `build/compile_commands.json` recording the exact flags per file. clangd
  reads it for include paths and language standard. Without it clangd guesses and
  shows errors everywhere.
- `add_executable(name sources...)` - the program. **Every `.cpp` goes here.**
- `target_include_directories(... PRIVATE include)` - allows `#include "nn/vec.hpp"`
  instead of long relative paths.
- `target_compile_options(... -Wall -Wextra -Wpedantic)` - warnings. Read them.

### Headers vs `.cpp`

A header is a *declaration*: "a function `dot` exists." `#include` pastes that text
in. A `.cpp` is the *definition*, the actual body. Each `.cpp` compiles separately,
then the linker joins them.

List a header in `add_executable` and nothing breaks, but it is pointless. Forget a
`.cpp` and it compiles fine then fails with `Undefined symbol` at link time: the
compiler believed the promise, the linker could not find the goods.

**Headers never go in `CMakeLists.txt`. Every `.cpp` does.** Exception: a header
where everything is `inline` or a template needs no `.cpp` at all.

## `.gitignore`

```
build*/
.direnv/
.cache/
```

The rule: ignore anything regenerated automatically.

- `build*/` - CMake output. The `*` also catches `build-san/`.
- `.direnv/` - direnv's cached environment.
- `.cache/` - clangd's index.

**Commit** `flake.nix`, `flake.lock`, `CMakeLists.txt`, `.envrc`, `.clang-format`,
and all source. `flake.lock` especially: it records the exact nixpkgs revision, so
it *is* the reproducibility. Ignore it and another machine gets other versions.

## `.clang-format`

```yaml
BasedOnStyle: LLVM
```

LLVM style already means 80 columns, 2-space indent, no tabs, and `Standard: Latest`.
No overrides needed. In Neovim, `:lua vim.lsp.buf.format()` applies it through clangd.

## Build and run

```sh
git add -A
cmake -S . -B build -G Ninja
cmake --build build && ./build/myproject
```

- `git add -A` - Nix only sees tracked files.
- `-S .` source dir, `-B build` build dir, `-G Ninja` use Ninja.
  **Re-run this whenever a `.cpp` is added.**
- `cmake --build build` - compiles. Run after every edit.

## Sanitizers

Without them, reading `p[7]` of a 3-element array returns garbage and the program
"succeeds" with exit code 0. With them, the program aborts and names the file and
line. ASan catches memory bugs (out of bounds, use-after-free); UBSan catches
undefined behaviour (overflow, bad shifts). Roughly 2x slower, so develop with them
and benchmark without.

Separate build folder, so a fast build is always available:

```sh
cmake -S . -B build-san -G Ninja -DSANITIZE=ON
cmake --build build-san && ./build-san/myproject
```

## Daily loop

```sh
cd ~/github/myproject          # direnv loads the tools
nvim src/main.cpp
cmake --build build && ./build/myproject
```

Neovim:

| Key | Does |
|---|---|
| `gd` | go to definition |
| `Ctrl-O` / `Ctrl-I` | jump back / forward |
| `K` | hover docs. Press `K` again to move into the window, then scroll normally and `q` to close |
| `grn` | rename everywhere |
| `grr` | find usages |
| `Ctrl-N` / `Ctrl-P` | next / previous completion suggestion |
| `Ctrl-Y` / `Ctrl-E` | accept / dismiss the suggestion |
| `Ctrl-X Ctrl-O` | force the completion menu open |

The menu opens on its own after `.`, `->` and `::`, but nothing is selected until
`Ctrl-N` is pressed, so it never types over what you are writing.

## When something breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Path 'flake.nix' is not tracked by Git` | new file not added | `git add -A` |
| `Undefined symbol: foo(...)` | a `.cpp` missing from CMake | add to `add_executable`, re-run cmake |
| Red squiggles on `#include <vector>` | no `compile_commands.json` | `cmake -S . -B build -G Ninja` |
| clangd ignores a new file | stale compile database | re-run the cmake configure command |
| Tools not found after `cd` | `.envrc` not approved | `direnv allow` |
| Sanitized binary hangs forever | LLVM below 22 on macOS 26 | use `llvmPackages_22` |
