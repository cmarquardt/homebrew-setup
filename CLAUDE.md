# homebrew-setup

Personal setup for a non-default-prefix Homebrew installation (`/opt/brew`
rather than `/opt/homebrew`/`/usr/local`) on macOS, plus the R and Python
package sets built on top of it. See `README.md` for the full install
walkthrough (PATH setup, shell init, `install-python-packages.sh`, etc.);
this file covers what a future session needs to work on the project itself,
with most of the detail on R package management since that's the actively
evolving part.

## Layout

| Path | What |
|---|---|
| `homebrew/Brewfile` | Bundled Homebrew packages/taps/casks |
| `bash/` | Shell init files installed by `install-shell-init.sh` |
| `python/` | `python-requirements-*.txt` + `install-python-packages.sh` |
| `R/` | R package requirement files, `dot.Rprofile`, the `ROracle` tarball |
| `install-r-packages-*.R` | R package installers (see below) |
| `reinstall-r-packages.R` | Standalone R package reinstall/ensure engine (see below) |
| `virtualenvs/` | virtualenvwrapper activate script overrides |
| `work/` | Scratch: snapshots, downloaded sources. Gitignored, not source. |

## R package management

### The install-r-packages-*.R scripts

R packages are declared in `R/r-requirements-*.txt` (one bare package name
per line, `#` for comments/trailing notes) and installed with plain
`install.packages()`:

| Script | Requirement file(s) | Notes |
|---|---|---|
| `install-r-packages-base.R` | `r-requirements-base.txt` | Run first: primes `Rcpp`/`RcppParallel`, then the core/tidyverse-adjacent set |
| `install-r-packages-by-topic.R` | `r-requirements-{devel,html,stats,stats2,spatial}.txt` | `Rscript install-r-packages-by-topic.R <topic> [<topic> ...] [-f/--force]`. Run after `base`. |
| `install-r-packages-local.R` | — | Installs the personal packages (`robtools`, `mdbtools`, `ombtools`) via `remotes::install_local()` from `/Users/marq/src/R/<pkg>`. Run last — depends on packages from the stages above. |
| `install-r-packages-01.R` | `r-requirements-01.txt` | **Stale predecessor**, kept for reference only. Still lists CRAN packages retired since (`rgdal`, `rgeos`, `maptools`). Don't run this on a machine that already has the split above. |

All packages are always built from source (`options(pkgType = "source")` in
`~/.Rprofile`, copied from `R/dot.Rprofile`) — Homebrew's R doesn't share
the CRAN macOS binaries' Fortran runtime/library layout.

### reinstall-r-packages.R

Handles the case the scripts above don't: recovering (or just verifying)
the package set, most commonly after a Homebrew R version bump. Homebrew's
`r-openmp` formula keys the package library path to R's `major.minor`
version, so bumping e.g. 4.5→4.6 leaves a brand new, empty site-library —
none of the previous ~600 packages carry over automatically.

```
Rscript reinstall-r-packages.R [mode] [options]

Modes (default: --ensure):
  --ensure           Install requirement-file packages missing from the
                      current library. Fast, safe, idempotent — the mode
                      invoked automatically from Chores' update-r skill
                      (see "Integration with Chores" below).
  --recover          Recover an older library's package set into the
                      current one (see "Why roots" below).
  --reconcile-only    Report the diff between an older library's roots and
                      the requirement files; makes no changes.

Options:
  --from <path>        Site-library directory or .rds snapshot to recover/
                        reconcile from. Default: auto-detect the most
                        recent sibling <version>/site-library under the
                        Homebrew R prefix, falling back to the newest
                        snapshot in work/.
  --stages <list>       Comma-separated subset of: base,devel,html,stats,
                        stats2,spatial,local (default: all).
  --dry-run             Print the plan; make no changes (including: no
                        snapshot is written).
  --force               Reinstall even if already present.
  --include-oracle      Also attempt ROracle (off by default — see below).
```

Always snapshot the *current* library first — as `.rds`, with full
`Depends`/`Imports`/`LinkingTo`/`Repository`/`Priority` fields, to
`work/r-<version>-site-library-full-snapshot_<timestamp>.rds` — before
making any changes. `--dry-run` skips this too (it makes no changes at
all). This exists because the old R keg (and its site-library) can be
removed by `brew cleanup` at any time; without a snapshot, the only
surviving record of what was installed is gone with it.

#### Why "roots", not the raw installed-package list

A typical library has 600+ packages installed, but empirically **~80% are
pure transitive dependencies** — pulled in automatically by the ~15-20% of
packages actually asked for by name. Reinstalling the raw list is
redundant (`pak` reinstalls the dependencies anyway, as dependencies of
whatever you actually ask for) and risks forcing stale/incompatible
pinned versions of packages that may not even build against the new R.

`--recover` and `--reconcile-only` instead compute the **roots** of the
source library: packages that no other installed package
`Depends`/`Imports`/`LinkingTo`s, via `tools::package_dependencies()`.
This is a much closer approximation of "what was actually explicitly
wanted" — on the R 4.5→4.6 bump this was written for, 622 installed
packages reduced to 118 roots, close in scale to the ~190 packages
actually declared across the requirement files (the remaining gap is
expected: some requirement-file entries, like `dplyr`, are themselves
dependencies of other requirement-file entries like `tidyverse`, so they
legitimately drop out of the roots set).

Caveat: a root can be an **orphan** — a package nothing depends on any
more only because whatever *used to* depend on it was removed. Since
roots get reconciled against the requirement files either way, an
orphaned root that's in neither the roots set's "known" categories nor
any requirement file is a candidate worth a second look, not something to
blindly reinstall forever.

#### Local packages

`robtools`/`mdbtools`/`ombtools` (and anything else installed via a local
source checkout) aren't on CRAN, so they need special handling — both to
avoid `pak` failing trying to resolve them by name, and because the roots
computation can hide one behind whatever else in the old library depends
on it (in which case it won't be a root at all, even though it's
genuinely wanted).

Detection is automatic and doesn't rely on a maintained list:
`installed.packages(fields = "Repository")` reports `Repository = NA` for
anything not installed from a normal repository (`"CRAN"` for everything
else) — this is what flags a package as "local-looking". The actual
*source path* still has to be known explicitly, though, so:

- `LOCAL_PACKAGES` (top of the script) maps the three known package names
  to their source directories. These are **always** attempted (via pak's
  `local::<path>` source spec — no separate `remotes` dependency needed),
  regardless of whether they show up as roots, and installed **before**
  the CRAN stages, so that any CRAN package which happens to depend on
  one finds it already present.
- Any other `Repository == NA` root — something installed once, ad hoc,
  outside `LOCAL_PACKAGES` — is reported for manual review rather than
  guessed at. (`ClaudeR` will show up here on a recover/reconcile run;
  that's expected — it's installed via a separate path, Chores'
  `update-r` skill's `update-claude-r.R`, not this script.)

#### Build-workaround hooks

A handful of packages need environment setup beyond a plain
`pak::pkg_install()` to build cleanly under this Homebrew setup. These
live in `with_build_hooks()`, keyed by package name — applied around
whatever install call touches them, regardless of *why* that package was
selected (`--ensure`, `--recover`, or a one-off). Mirrors the inline
package-name matching Chores' `update-homebrew/scripts/brew-upgrade-all.sh`
already uses for Qt/`libomp`/`assimp` special-casing.

| Trigger | Hook |
|---|---|
| `RcppParallel`, `RcppArmadillo` | `brew unlink tbb` before, `brew link tbb` after |
| `sf`, `terra`, `lwgeom`, `raster`, (`rgeos`/`rgdal` if ever needed) | add `gdal_config` to `PATH` |

`UDUNITS2_INCLUDE`/`UDUNITS2_LIB` are set unconditionally at the top of
the script (cheap, and several packages across stages need them).

**These need periodic re-verification, not blind trust.** Several of
these workarounds were disabled (commented out) in `install-r-packages-
base.R`/`-01.R` even though their header comments still describe them as
necessary, and it wasn't clear from the comments alone whether that was
intentional (no longer needed) or drift. Confirm against the current
toolchain (current `tbb`/`libomp`/`gdal` versions) when something in this
table stops mattering, rather than assuming history is still accurate.

`ROracle` is a separate case: not a normal CRAN install (a bundled
tarball, `R/ROracle_1.3-2.tar.gz`), needs the Oracle Instant Client
installed with `ORACLE_HOME` set, and an `OCI_LIB`/`ORACLE_HOME` env
swap around the install (see `install_oracle()`). Stays opt-in via
`--include-oracle` rather than part of any default run.

### Integration with Chores

The Chores repo (`~/Chores`) has an `update-r` skill/plugin that runs
after every Homebrew upgrade (chained via `run-r.sh`). It's meant to stay
generic and deployable on its own, so it doesn't hardcode a path into
this repo — instead, `plugins/update-r/skills/update-r/scripts/
reinstall-engine.conf` holds a single line: the path to this script.
`update-r.sh` reads that file (or `--engine <path>` overrides it),
invokes `Rscript reinstall-r-packages.R --ensure` if the configured path
exists, and skips the step cleanly if it doesn't. That `--ensure` run
does no harm even when nothing changed — it just checks presence against
the requirement files and installs whatever's missing.

`libomp` header patching (needed when a from-source R/OpenMP build hits a
macro collision between R's `Rinternals.h` and recent `libomp` headers)
lives in Chores (`update-homebrew/scripts/patch-libomp.sh`), not here —
that's a Homebrew-build-time fix applied whenever `libomp` itself gets
upgraded, unrelated to R package installation.

### Known gotchas

- **`brew --prefix` from the Ruby/`sandbox-exec` build environment vs. a
  normal shell**: mostly a non-issue day to day, but if a script run
  through `brew` (rather than directly) behaves differently, that's
  usually why.
- **Recommended/base packages showing as "outdated"**: `old.packages()`
  can flag R's own bundled packages (`class`, `MASS`, `Matrix`, etc.) as
  outdated even when the installed version matches CRAN exactly — a known
  quirk, not a real update. `reinstall-r-packages.R` excludes
  `Priority %in% c("base", "recommended")` from its roots computation for
  this reason; if writing anything else that inspects `old.packages()`
  output, keep that in mind.
- **`work/` is gitignored** — treat anything in there (snapshots, `arrow`
  build scratch, tarballs) as disposable/regeneratable, not something to
  back up by committing it.
