# Maintenance

Things this config does **not** update for you. `./rebuild.sh` applies your
declared configuration; it does not refresh package versions.

Automating these is a planned follow-up, once the Nix config is settled.

| Task | Cadence | Command |
|---|---|---|
| Nix inputs | monthly | `nix flake update && ./rebuild.sh` |
| Homebrew | monthly | `brew update && brew upgrade` |
| Neovim plugins | occasionally | `:Lazy update` inside nvim |
| conda | occasionally | `conda update -n base conda` |
| Nix garbage collection | every few months | `nix store gc` |
| macOS | when prompted | System Settings |

## Nix inputs

```sh
cd ~/.dotfiles
nix flake update
./rebuild.sh
```

Updates `nixpkgs`, `nix-darwin`, `home-manager`, and `nix-homebrew` together.
Commit the resulting `flake.lock` change.

This only moves you forward *within* the release your `flake.nix` pins (26.05).
It never switches you to unstable. Only editing the `url` lines in `flake.nix`
can do that, and the next stable release (26.11) lands around November 2026.

To move a single input without touching the others:

```sh
nix flake update nixpkgs
```

## Homebrew

```sh
brew update && brew upgrade
```

**This is fully manual.** `configuration.nix` sets
`homebrew.onActivation.autoUpdate = false`, so `./rebuild.sh` installs missing
packages but never upgrades existing ones.

Keeping `ruby-build` current matters: rbenv can only install Ruby versions that
its copy of `ruby-build` knows about.

> [!WARNING]
> Do not casually run `brew autoremove`. It reasons only about Homebrew's own
> dependency graph and cannot see software compiled outside it. It once deleted
> `gmp`, which every rbenv-built Ruby links against, breaking all of them with
> `dyld: Library not loaded: libgmp.10.dylib`. `gmp` is declared in
> `configuration.nix` now, but the same hazard applies to any future library an
> rbenv Ruby or other non-Homebrew build depends on.

## Neovim plugins

From inside nvim:

```
:Lazy update
```

This rewrites `home/.config/nvim/lazy-lock.json`, which **is tracked in this
repo**. Commit it. That lock is what pins plugin versions reproducibly on
another machine.

## conda

Conda is the single source of truth for Python here; nothing about it is managed
by Nix except the shell hook in `home.nix`.

```sh
conda update -n base conda   # conda itself
conda update --all           # packages in the active environment
```

`auto_activate_base` is deliberately `false`, so a plain shell has no conda
Python on `PATH` and bare `python3` is macOS's own 3.9.6. Run
`conda activate <env>` before Python work.

## Nix garbage collection

Nix never deletes old generations on its own. That is what makes rollback
possible, but the store grows forever.

```sh
nix store gc                  # safe: unreferenced paths only, rollback preserved
sudo nix-collect-garbage -d   # aggressive: also deletes old generations
```

Use the first routinely. Use `-d` only when you are sure you will not need to
roll back to an earlier generation.

Check current size with `du -sh /nix/store` and count generations with
`ls /nix/var/nix/profiles/`.

A direnv project's `.direnv/` directory protects that project's toolchain from
being collected. Delete `.direnv/` (or the project) to release it.

## Things that update themselves

VS Code, Chrome, Slack, Spotify, Discord, and Docker all self-update. No action
needed, and declaring them as casks does not change that.

## Gotchas worth remembering

- **Versioned Homebrew formulae are keg-only.** `postgresql@17` is never
  symlinked into `/opt/homebrew/bin`. `brew link` works but gets undone, so the
  path is declared via `home.sessionPath` in `home.nix` instead.
- **`nix eval nixpkgs#foo` does not query your pinned nixpkgs.** It uses the
  flake registry, which points at a rolling snapshot. To check what *you* would
  actually get, evaluate through the flake:
  `nix eval .#darwinConfigurations.mac.config...`.
- **Editing `~/.zshrc` is pointless.** Home Manager regenerates it from
  `programs.zsh` in `home.nix` on every switch. Edit `home.nix`.
- **A project flake pins itself, not this repo.** Each project's `flake.lock`
  is separate, so `nix flake update` here does not move a project's toolchain.
  Run it inside the project to update that one.
