#! /usr/bin/env Rscript

# Updating and installing R packages
# ==================================
#
# C. Marquardt, Darmstadt
#
# 13 July 2025
#
# This script (re-)installs a default set of R packages in a brewed
# environment. It also rebuilds Jupyter's R kernel modules. I run 
# this script to
#
#  - Recompile R packages after a new major version of R was released.
#
#  - Recompile R packages after new versions of core dependencies
#    became available in brew. At present, recompiling is required 
#    after upgrades of
#
#     - the LLVM compiler suite if R is build with OpenMP (or of the
#       GNU compiler suite if not)
#     - the GNU Fortran compiler;
#     - the OpenBlas library.
#
#    If the recompilation is not done, package imports will fail
#    because loading of versioned shared libraries of either the
#    compiler runtimes or the OpenBlas library will fail.
#
#    Because of the dependency on Fortran and OpenBlas, all packages
#    being linked against them must be rebuild first. I manually
#    rearranged the dependency file to list these first and explicitly,
#    although the list probably isn't complete.
#
#  - Install R packages on a clean machine, after all required software
#    has been installed via brew.
#
# In recent years, the R community started to provide binary versions
# of R packages also for macOS. The problem with those binary versions
# is that they are compiled for and linked with the CRAN MacOS version
# of R, which includes a framework install as well as a dedicated
# Fortran compiler and runtime library. In a Homebrew build of R, the
# corresponding shared libraries don't exists, or at at least installed
# in other places so that the dynamic loader fails to load them. As a
# workaround, put the follolwing line in either the system wide profile
# ${R_HOME}/lib/etc/Rprofile.site, or your own local one ~/.Rprofile:
#
#    # Always build packages from source
#    options(pkgType = "source")
#
# Note that per-project profile files (in <project-rppt>/.Rprofile), if
# they exist, are sourced *instead* of the user profile.
#
# Other notes:
#
#  - Homebrew sometimes doesn't install or symlink gdal-config into its 
#    standard bin directory; the utility then cannot be found. For this
#    reason, the path to the tool must be added in some variant of 
#    ~/.Rprofile.
#  - ROracle requires special dealings with environment variables
#    (assuming the Oracle instant client is installed, and ORACLE_HOME
#    points to its root directory):
#
#        export OCI_LIB=$ORACLE_HOME
#        unset ORACLE_HOME
#
#        ...build the package ...
#
#        export ORACLE_HOME=OCI_LIB
#        unset OCI_LIB
#
#     This is replicated below.

# 0. A helper function
# --------------------

read.requirements <- function(filename) {
   lst <- gsub("\\s*#.*","", readLines(filename))
   unique(lst[lst != ""])
}

# 1. Command line arguments
# -------------------------

# Get command line arguments, skipping the script name
args <- commandArgs(trailingOnly = TRUE)

# Known keywords
known_keywords <- c("base", "devel", "html", "stats", "stats2", "spatial")

# Check for empty input
if (length(args) == 0) {
  stop("No keywords provided. Usage: Rscript install-r-topic.R <keyword1> [keyword2 ...]")
}

# 2. Environment variables
# ------------------------

# 2.1 Header and library paths
# ----------------------------

# Normal setup to support (linked) hombrew libraries

prefix <- system("brew --prefix", intern = TRUE)

#Sys.setenv(PKG_CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
#Sys.setenv(PKG_LIBS = paste("-L", prefix, "/lib", sep = ""))

#Sys.setenv(CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
#Sys.setenv(LDFLAGS = paste("-L", prefix, "/lib", sep = ""))

# Support for the gdal_config script of gdal

#Sys.setenv("PATH" = paste(Sys.getenv("PATH"), paste(prefix, "/gdal/bin/", sep = ":")))

#Sys.setenv(UDUNITS2_INCLUDE = paste0(prefix, "/include"))
#Sys.setenv(UDUNITS2_LIB = paste0(prefix, "/lib"))


# 3. Install topical packages from CRAN
# -------------------------------------

force   <- FALSE
jupyter <- FALSE

# Loop over provided arguments
for (kw in args) {
  # Force installation of subsequent package groups with -f/--force
  if (kw == "-f" | kw == "--force") {
    force <- TRUE
  } else if (kw %in% known_keywords) {
    # Run command for each valid keyword
    cat(sprintf("Installing %s packages...\n", kw))

    # Replace with your custom logic
    if (kw == "base") {
      packages <- read.requirements("R/r-requirements-base.txt")
    } else if (kw == "devel") {
      packages <- read.requirements("R/r-requirements-devel.txt")
      jupyter <- TRUE
    } else if (kw == "html") {
      packages <- read.requirements("R/r-requirements-html.txt")
    } else if (kw == "stats") {
      packages <- read.requirements("R/r-requirements-stats.txt")
    } else if (kw == "stats2") {
      packages <- read.requirements("R/r-requirements-stats2.txt")
    } else if (kw == "spatial") {
      packages <- read.requirements("R/r-requirements-spatial.txt")
    }
    if (force) {
      install.packages(packages, repos = "http://cran.rstudio.com/")
      } else {
      packages <- packages[!packages %in% rownames(installed.packages())]
      if (length(packages) > 0) {
        install.packages(packages, repos = "http://cran.rstudio.com/")
      }
    }
    if (jupyter) {
      cat("\nActivating Jupyter R kernel...\n")
      IRkernel::installspec()
      jupyter <- FALSE
    }
  } else {
    warning(sprintf("Unknown keyword ignored: %s", kw))
  }
}
