#! /usr/bin/env Rscript

# Reinstalling / ensuring R packages
# ===================================
#
# C. Marquardt, Darmstadt
#
# 24 September 2026
#
# Standalone tool that installs R packages into the current (brewed) R
# library, in one of two ways:
#
#  --ensure    Make sure every package named in R/r-requirements-*.txt is
#              present in the current library; install whatever's missing.
#              Fast and safe to run unconditionally -- this is the mode
#              meant to be invoked automatically (see the update-r skill
#              in the Chores repo, which calls this via
#              plugins/update-r/skills/update-r/scripts/reinstall-engine.conf).
#
#  --recover   Recover the full package set from an older R installation
#              (a sibling <version>/site-library under the Homebrew R
#              prefix, or a saved snapshot) after a major/minor R version
#              bump left the current library empty. Computes the "roots"
#              of that old library -- packages nothing else installed
#              depends on -- and (re)installs those; pak resolves the full
#              dependency closure itself.
#
# Why roots, not the raw package list: a typical library has ~600+ packages
# installed, but the vast majority (80%+, empirically) are transitive
# dependencies pulled in automatically -- reinstalling all of them by name
# is redundant (pak will reinstall them anyway as dependencies of the
# roots) and risks forcing stale/incompatible pinned versions. See
# CLAUDE.md, "Why 'roots' instead of the raw installed-package list".
#
# See CLAUDE.md in this repository for full documentation, including the
# known build workarounds this script applies and why.

# Bootstrap pak itself if missing -- this is the normal state right after
# an R version bump (brand new, empty site-library), which is exactly the
# situation this script exists to recover from. Don't just fail and make
# every fresh-library run require a manual `install.packages("pak")`
# first.
if (!requireNamespace("pak", quietly = TRUE)) {
  cat("[bootstrap] pak not installed -- installing it first\n")
  if (identical(getOption("repos")[["CRAN"]], "@CRAN@")) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
  install.packages("pak")
  if (!requireNamespace("pak", quietly = TRUE)) {
    stop("pak installation failed -- install it manually with install.packages(\"pak\") and retry")
  }
}

SCRIPT_DIR <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)))
if (length(SCRIPT_DIR) == 0 || SCRIPT_DIR == "") SCRIPT_DIR <- "."

# 0. Helpers
# ----------

log_msg <- function(...) cat(sprintf(...), "\n", sep = "")

read.requirements <- function(filename) {
  lst <- gsub("\\s*#.*", "", readLines(filename))
  unique(lst[lst != ""])
}

# 1. Configuration
# -----------------

# Requirement files and the (fixed, dependency-aware) order to install them
# in. Deliberately excludes R/r-requirements-01.txt, a stale predecessor
# that still lists retired CRAN packages (rgdal, rgeos, maptools).
STAGE_FILES <- c(
  base    = "R/r-requirements-base.txt",
  devel   = "R/r-requirements-devel.txt",
  html    = "R/r-requirements-html.txt",
  stats   = "R/r-requirements-stats.txt",
  stats2  = "R/r-requirements-stats2.txt",
  spatial = "R/r-requirements-spatial.txt"
)
STAGE_ORDER <- c("base", "devel", "html", "stats", "stats2", "spatial")

# Locally-developed packages (not on CRAN) -- read from R/r-local-packages.txt
# as name -> pak package reference (local::<path>, git::<url>, etc.).
# Detected among reinstall candidates via installed.packages()'s Repository
# field being NA (see CLAUDE.md), but the actual source still has to be
# known explicitly, which is what this file is for.
LOCAL_PACKAGES_FILE <- file.path(SCRIPT_DIR, "R", "r-local-packages.txt")

read.local.packages <- function(filename) {
  if (!file.exists(filename)) return(character(0))
  lines <- gsub("\\s*#.*", "", readLines(filename))
  lines <- trimws(lines[lines != ""])
  parts <- strsplit(lines, "\\s*\\|\\s*")
  vals <- vapply(parts, `[`, character(1), 2)
  names(vals) <- vapply(parts, `[`, character(1), 1)
  vals
}

LOCAL_PACKAGES <- read.local.packages(LOCAL_PACKAGES_FILE)

# ROracle: not a normal CRAN install (bundled tarball, needs the Oracle
# Instant Client + an env var dance). Opt-in only via --include-oracle.
ORACLE_TARBALL <- file.path(SCRIPT_DIR, "R", "ROracle_1.3-2.tar.gz")

SNAPSHOT_DIR <- file.path(SCRIPT_DIR, "work")

# 2. Environment
# ---------------

prefix <- system("brew --prefix", intern = TRUE)
Sys.setenv(UDUNITS2_INCLUDE = paste0(prefix, "/include"))
Sys.setenv(UDUNITS2_LIB = paste0(prefix, "/lib"))
if (identical(getOption("repos")[["CRAN"]], "@CRAN@")) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

# 3. Build-workaround hooks
# --------------------------
# Known packages/stages that need special environment handling to build
# cleanly under this Homebrew setup. Applied around whatever install call
# touches them, regardless of why they were selected (--ensure or
# --recover) -- mirrors the inline package-name matching already used in
# Chores' update-homebrew/scripts/brew-upgrade-all.sh (Qt/libomp/assimp).
#
# Re-verify these are still needed against the current toolchain before
# trusting them blindly; several were disabled (commented out) in the
# scripts this file supersedes, and it wasn't clear from the comments
# alone whether that was intentional or drift.

with_build_hooks <- function(pkgs, install_fn) {
  cleanup <- list()

  if (any(c("RcppParallel", "RcppArmadillo") %in% pkgs)) {
    log_msg("[hook] unlinking tbb before RcppParallel/RcppArmadillo build")
    system("brew unlink tbb", ignore.stdout = TRUE, ignore.stderr = TRUE)
    cleanup <- c(cleanup, function() {
      log_msg("[hook] relinking tbb")
      system("brew link tbb", ignore.stdout = TRUE, ignore.stderr = TRUE)
    })
  }

  spatial_pkgs <- c("sf", "terra", "lwgeom", "raster", "rgeos", "rgdal")
  if (any(spatial_pkgs %in% pkgs)) {
    log_msg("[hook] adding gdal_config to PATH for spatial packages")
    old_path <- Sys.getenv("PATH")
    Sys.setenv(PATH = paste(old_path, file.path(prefix, "opt", "gdal", "bin"), sep = ":"))
    cleanup <- c(cleanup, function() Sys.setenv(PATH = old_path))
  }

  on.exit(for (f in cleanup) f(), add = TRUE)
  install_fn(pkgs)
}

# 4. Snapshotting
# -----------------
# Always snapshot the current library before making any changes -- an old
# R keg (and its site-library) can be removed by `brew cleanup` at any
# time, so this is step zero, not optional. Saved with full dependency
# fields so a later --recover can compute roots from it if the live
# library it came from is gone by then.

snapshot_library <- function(lib.loc = .libPaths()[1]) {
  dir.create(SNAPSHOT_DIR, showWarnings = FALSE, recursive = TRUE)
  ip <- installed.packages(lib.loc = lib.loc, fields = c("Repository", "Priority"))
  short_version <- paste(R.version$major, strsplit(R.version$minor, "\\.")[[1]][1], sep = ".")
  out <- file.path(SNAPSHOT_DIR, sprintf("r-%s-site-library-full-snapshot_%s.rds",
                                          short_version, format(Sys.time(), "%Y%m%d_%H%M%S")))
  saveRDS(as.data.frame(ip, stringsAsFactors = FALSE), out)
  log_msg("[snapshot] %d package(s) from %s saved to %s", nrow(ip), lib.loc, out)
  invisible(out)
}

# 5. Roots computation
# ----------------------
# A package is a "root" if no other installed package Depends/Imports/
# LinkingTo it. Empirically, ~80% of a typical library is pure transitive
# dependency -- roots are a much closer approximation of "what was
# actually explicitly wanted" than the raw installed-package list, and are
# what should be diffed against the requirement files and reinstalled
# (pak resolves the rest of the dependency graph itself).

compute_roots <- function(ip) {
  deps <- tools::package_dependencies(rownames(ip), db = ip,
                                       which = c("Depends", "Imports", "LinkingTo"),
                                       recursive = FALSE)
  required_by_others <- unique(unlist(deps))
  roots <- setdiff(rownames(ip), required_by_others)
  is_base_or_recommended <- !is.na(ip[roots, "Priority"]) &
    ip[roots, "Priority"] %in% c("base", "recommended")
  roots[!is_base_or_recommended]
}

# Load a prior library's package table, either from a live sibling
# site-library directory or a saved .rds snapshot.
load_source_table <- function(from) {
  if (identical(from, "current")) {
    installed.packages(fields = c("Repository", "Priority"))
  } else if (dir.exists(from)) {
    installed.packages(lib.loc = from, fields = c("Repository", "Priority"))
  } else if (file.exists(from) && grepl("\\.rds$", from)) {
    df <- readRDS(from)
    as.matrix(df)
  } else {
    stop(sprintf("--from path is neither \"current\", a directory, nor a .rds snapshot: %s", from))
  }
}

# Auto-detect the most recent sibling <version>/site-library under the
# Homebrew R prefix, other than the one currently active. Falls back to
# the most recent snapshot in work/ if no sibling directory is found (e.g.
# brew cleanup already removed the old keg).
auto_detect_from <- function() {
  r_lib_root <- file.path(prefix, "lib", "R")
  current_version <- paste(R.version$major, strsplit(R.version$minor, "\\.")[[1]][1], sep = ".")
  siblings <- list.dirs(r_lib_root, recursive = FALSE, full.names = FALSE)
  siblings <- siblings[grepl("^[0-9]+\\.[0-9]+$", siblings)]
  siblings <- setdiff(siblings, current_version)

  if (length(siblings) > 0) {
    siblings <- siblings[order(numeric_version(siblings), decreasing = TRUE)]
    candidate <- file.path(r_lib_root, siblings[1], "site-library")
    if (dir.exists(candidate) && length(list.files(candidate)) > 0) {
      return(candidate)
    }
  }

  snaps <- list.files(SNAPSHOT_DIR, pattern = "\\.rds$", full.names = TRUE)
  if (length(snaps) > 0) {
    return(snaps[order(file.info(snaps)$mtime, decreasing = TRUE)][1])
  }

  NULL
}

# 6. Install machinery
# ----------------------

# Packages that failed to install, across the whole run -- collected here
# rather than tracked per-call, so the script can report a full summary
# and exit non-zero at the end without any single failure aborting the
# rest of the run (see install_missing()/install_local_package()).
FAILED_PACKAGES <- character(0)
note_failure <- function(pkg, err) {
  FAILED_PACKAGES <<- c(FAILED_PACKAGES, pkg)
  log_msg("[fail] %s: %s", pkg, conditionMessage(err))
}

# pak solves a whole pkg_install() call's dependency graph atomically: one
# unresolvable or conflicting package (retired from CRAN, a real version
# conflict with something else in the same call, ...) fails the ENTIRE
# batch, not just that package -- so a single bad package could otherwise
# silently block every other package in the same stage. Try the batch
# first (fast path, the common case), and if that fails, fall back to
# installing one at a time so the good ones still get installed and only
# the actual offenders are reported.
install_missing <- function(pkgs, dry_run) {
  if (length(pkgs) == 0) return(invisible(NULL))
  if (dry_run) {
    log_msg("[dry-run] would install: %s", paste(pkgs, collapse = ", "))
    return(invisible(NULL))
  }
  batch_ok <- tryCatch({
    with_build_hooks(pkgs, function(p) pak::pkg_install(p, ask = FALSE))
    TRUE
  }, error = function(e) {
    log_msg("[warn] batch install of %d package(s) failed (%s) -- retrying individually",
            length(pkgs), conditionMessage(e))
    FALSE
  })
  if (batch_ok) return(invisible(NULL))

  for (p in pkgs) {
    tryCatch(
      with_build_hooks(p, function(pp) pak::pkg_install(pp, ask = FALSE)),
      error = function(e) note_failure(p, e)
    )
  }
}

install_local_package <- function(pkg, dry_run) {
  ref <- LOCAL_PACKAGES[[pkg]]
  if (is.null(ref)) {
    log_msg("[warn] %s looks like a local package (no CRAN Repository) but has no entry in %s -- skipping.",
            pkg, LOCAL_PACKAGES_FILE)
    return(invisible(NULL))
  }
  if (dry_run) {
    log_msg("[dry-run] would install local package %s from %s", pkg, ref)
    return(invisible(NULL))
  }
  # Only local::<path> refs have a directory to sanity-check up front; a
  # git::/github:: ref's validity can only be found out by pak trying it.
  if (startsWith(ref, "local::")) {
    path <- sub("^local::", "", ref)
    if (!dir.exists(path)) {
      log_msg("[warn] %s: source directory not found: %s -- skipping", pkg, path)
      return(invisible(NULL))
    }
  }
  tryCatch(
    pak::pkg_install(ref, ask = FALSE),
    error = function(e) note_failure(pkg, e)
  )
}

install_oracle <- function(dry_run) {
  if (dry_run) {
    log_msg("[dry-run] would install ROracle from %s", ORACLE_TARBALL)
    return(invisible(NULL))
  }
  if (!file.exists(ORACLE_TARBALL)) {
    log_msg("[warn] ROracle tarball not found: %s -- skipping", ORACLE_TARBALL)
    return(invisible(NULL))
  }
  oracle_home <- Sys.getenv("ORACLE_HOME")
  Sys.setenv(OCI_LIB = oracle_home)
  Sys.unsetenv("ORACLE_HOME")
  on.exit({
    Sys.setenv(ORACLE_HOME = oracle_home)
    Sys.unsetenv("OCI_LIB")
  }, add = TRUE)
  tryCatch(
    install.packages(ORACLE_TARBALL, repos = NULL),
    error = function(e) note_failure("ROracle", e)
  )
}

# 7. Modes
# ---------

installed_names <- function() rownames(installed.packages(fields = c("Repository", "Priority")))

# --ensure: install whatever the requirement files declare that isn't
# already present. Safe and cheap to run unconditionally.
mode_ensure <- function(stages, dry_run, force) {
  if (!dry_run) snapshot_library()
  have <- if (force) character(0) else installed_names()

  # Local packages first -- see the matching comment in mode_recover() for
  # why: anything in the requirement files that happens to depend on one
  # of these needs it already present, since pak can't resolve it from
  # CRAN on its own.
  if ("local" %in% stages) {
    for (pkg in names(LOCAL_PACKAGES)) {
      if (force || !(pkg %in% have)) install_local_package(pkg, dry_run)
    }
  }

  for (stage in intersect(stages, STAGE_ORDER)) {
    file <- file.path(SCRIPT_DIR, STAGE_FILES[[stage]])
    if (!file.exists(file)) {
      log_msg("[warn] stage '%s': requirement file not found: %s -- skipping", stage, file)
      next
    }
    wanted <- read.requirements(file)
    missing <- setdiff(wanted, have)
    if (length(missing) == 0) {
      log_msg("[stage %s] all %d package(s) already present", stage, length(wanted))
      next
    }
    log_msg("[stage %s] %d missing of %d declared: %s", stage, length(missing), length(wanted),
            paste(missing, collapse = ", "))
    install_missing(missing, dry_run)
  }
}

# --recover: pull the roots of an older library (or snapshot) and
# (re)install them into the current one.
mode_recover <- function(from, stages, dry_run, force) {
  if (!dry_run) snapshot_library()

  if (is.null(from)) from <- auto_detect_from()
  if (is.null(from)) stop("--recover: no sibling site-library or saved snapshot found; pass --from explicitly")
  log_msg("[recover] source: %s", from)

  ip <- load_source_table(from)
  roots <- compute_roots(ip)
  log_msg("[recover] %d package(s) total, %d root(s)", nrow(ip), length(roots))

  repos_field <- ip[roots, "Repository"]
  local_roots <- roots[is.na(repos_field)]
  cran_roots  <- roots[!is.na(repos_field)]

  have <- if (force) character(0) else installed_names()
  missing_cran <- setdiff(cran_roots, have)

  log_msg("[recover] %d CRAN/Bioc root(s) to install, %d local root(s), %d already present",
          length(missing_cran), length(local_roots), length(cran_roots) - length(missing_cran))

  # Install known local packages FIRST, always attempting the full known
  # list rather than gating on root-membership: a local package can be a
  # dependency of something else in the old library (so it drops out of
  # the roots computation) without being resolvable by pak on its own,
  # since it isn't on CRAN. Installing it up front means CRAN packages
  # reinstalled afterward that depend on it find it already present.
  if ("local" %in% stages) {
    for (pkg in names(LOCAL_PACKAGES)) {
      if (force || !(pkg %in% have)) install_local_package(pkg, dry_run)
    }
    unknown_local <- setdiff(local_roots, names(LOCAL_PACKAGES))
    if (length(unknown_local) > 0) {
      log_msg("[warn] local-looking root(s) with no known source path -- review manually: %s",
              paste(unknown_local, collapse = ", "))
    }
  }

  # Install in the same staged order as --ensure would, for the build
  # hooks (tbb, gdal PATH) to apply correctly; anything not covered by a
  # requirement file still gets installed, just in one final batch.
  remaining <- missing_cran
  for (stage in intersect(stages, STAGE_ORDER)) {
    file <- file.path(SCRIPT_DIR, STAGE_FILES[[stage]])
    if (!file.exists(file)) next
    wanted <- intersect(read.requirements(file), remaining)
    if (length(wanted) == 0) next
    log_msg("[stage %s] installing %d root(s): %s", stage, length(wanted), paste(wanted, collapse = ", "))
    install_missing(wanted, dry_run)
    remaining <- setdiff(remaining, wanted)
  }
  if (length(remaining) > 0) {
    log_msg("[stage other] %d root(s) not in any requirement file: %s",
            length(remaining), paste(remaining, collapse = ", "))
    install_missing(remaining, dry_run)
  }
}

# --reconcile-only: diff the roots of an older library against the
# requirement files. Report only, no changes.
mode_reconcile <- function(from) {
  # Unlike --recover (about migrating FROM an older library), the natural
  # default for reconciling is the live, currently-evolving library --
  # "has anything drifted from config" is an ongoing maintenance question,
  # not a version-bump-specific one. Pass --from <path> explicitly to
  # compare against an older library/snapshot instead.
  if (is.null(from)) from <- "current"
  log_msg("[reconcile] source: %s", from)

  ip <- load_source_table(from)
  roots <- compute_roots(ip)

  repos_field <- ip[roots, "Repository"]
  cran_roots  <- roots[!is.na(repos_field)]
  local_roots <- roots[is.na(repos_field)]

  configured <- unique(unlist(lapply(STAGE_FILES, function(f) {
    path <- file.path(SCRIPT_DIR, f)
    if (file.exists(path)) read.requirements(path) else character(0)
  })))

  not_in_config <- setdiff(cran_roots, configured)
  not_installed <- setdiff(configured, rownames(ip))
  unknown_local <- setdiff(local_roots, names(LOCAL_PACKAGES))

  log_msg("\n%d CRAN/Bioc root(s) not in any requirement file (candidates to add):", length(not_in_config))
  if (length(not_in_config) > 0) cat(paste(" -", sort(not_in_config)), sep = "\n")

  log_msg("\n%d local-looking root(s) with no known source path (review manually -- not counted above):",
          length(unknown_local))
  if (length(unknown_local) > 0) cat(paste(" -", sort(unknown_local)), sep = "\n")

  log_msg("\n%d configured package(s) not present in the source library (candidates to prune, or just not yet installed there):",
          length(not_installed))
  if (length(not_installed) > 0) cat(paste(" -", sort(not_installed)), sep = "\n")
}

# 8. CLI
# -------

args <- commandArgs(trailingOnly = TRUE)

mode <- "ensure"
from <- NULL
stages <- c(STAGE_ORDER, "local")
dry_run <- FALSE
force <- FALSE
include_oracle <- FALSE

i <- 1
while (i <= length(args)) {
  a <- args[i]
  if (a == "--ensure") {
    mode <- "ensure"
  } else if (a == "--recover") {
    mode <- "recover"
  } else if (a == "--reconcile-only") {
    mode <- "reconcile"
  } else if (a == "--from") {
    i <- i + 1; from <- args[i]
  } else if (a == "--stages") {
    i <- i + 1; stages <- strsplit(args[i], ",")[[1]]
  } else if (a == "--dry-run") {
    dry_run <- TRUE
  } else if (a == "--force") {
    force <- TRUE
  } else if (a == "--include-oracle") {
    include_oracle <- TRUE
  } else if (a == "--help" || a == "-h") {
    cat(readLines(textConnection("
Usage: reinstall-r-packages.R [mode] [options]

Modes (default: --ensure):
  --ensure           Install requirement-file packages missing from the
                      current library.
  --recover          Recover an older library's roots into the current one.
  --reconcile-only   Report roots-vs-requirement-file diff for the CURRENT
                      library by default -- run this any time to check for
                      config drift (manually installed packages missing
                      from the requirement files, or vice versa); no
                      changes made. Pass --from to check an older library
                      instead (e.g. right after a version bump, before
                      running --recover).

Options:
  --from <path|current>  Site-library dir or .rds snapshot to read from.
                       'current' (the default for --reconcile-only) reads
                       the live library directly. --recover instead
                       defaults to auto-detecting a sibling <version>/
                       site-library under the Homebrew R prefix.
  --stages <list>      Comma-separated subset of: base,devel,html,stats,
                       stats2,spatial,local (default: all).
  --dry-run            Print the plan; install nothing.
  --force              Reinstall even if already present.
  --include-oracle     Also attempt ROracle (off by default).
")), sep = "\n")
    quit(status = 0)
  } else {
    stop(sprintf("Unknown argument: %s", a))
  }
  i <- i + 1
}

# 9. Main
# --------

if (mode == "ensure") {
  mode_ensure(stages, dry_run, force)
} else if (mode == "recover") {
  mode_recover(from, stages, dry_run, force)
} else if (mode == "reconcile") {
  mode_reconcile(from)
}

if (include_oracle) install_oracle(dry_run)

if (length(FAILED_PACKAGES) > 0) {
  log_msg("[done] mode=%s -- %d package(s) failed: %s",
          mode, length(FAILED_PACKAGES), paste(FAILED_PACKAGES, collapse = ", "))
  quit(status = 1)
} else {
  log_msg("[done] mode=%s", mode)
}
