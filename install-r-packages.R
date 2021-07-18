#! /usr/bin/env Rscript

# Updating and installing R packages
# ==================================
#
# C. Marquardt, Darmstadt
#
# 21 March 2021
#
# This script (re-)installs a default set of R packages in a brewed
# environment. I run it to
#
#  - Install R packages on a clean machine, after all required software
#    has been installed via brew;
#  - Re-compile R packages after new versions of core dependencies
#    became available in brew and require R and its packages to be
#    recompiled. At present, recompiling is required after upgrades
#    of
#
#     - the GNU C / Fortran compiler;
#     - the OpenBlas library.
#
#    If the recompilation is not done, package imports will fail
#    because loading of versioned shared libraries of either the
#    Fortran runtime or the OpenBlas library will fail. In practise,
#    this most often occurs when updating existing or installing
#    new R packages from source. It is then advisable to recompile
#    all packages.
#
#    Because of the dependency on Fortran and OpenBlas, all packages
#    being linked against them must be rebuild first. I manually
#    rearranged the dependency file to list these first and explicitly,
#    although the list probably isn't complete.
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

# 1. Environment variables
# ------------------------

# 1.1 Header and library paths
# ----------------------------

# Normal setup to support (linked) hombrew libraries

prefix <- system("brew --prefix", intern = TRUE)

Sys.setenv(PKG_CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(PKG_LIBS = paste("-L", prefix, "/lib", sep = ""))

Sys.setenv(CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(LDFLAGS = paste("-L", prefix, "/lib", sep = ""))

# 1.2 Rcpp and RcppParallel

install.packages("Rcpp", repos = "http://cran.rstudio.com")

system("brew unlink tbb")
install.packages("RcppParallel", repos = "http://cran.rstudio.com")
system("brew link tbb")

# 1.3 Special case: Bugs fixed on Github but not yet released)

install.packages("remotes", repos = "http://cran.rstudio.com")

# See: https://github.com/r-spatial/sf/issues/1298 (closed 13 Mar 2020; contained in v0.9-x on CRAN)
# remotes::install_github("r-spatial/sf")

# See https://github.com/mjwoods/RNetCDF/issues/75 (closed 29 Apr 2020, contained in v2.3-1 on CRAN)
# remotes::install_github("mjwoods/RNetCDF")

# See https://github.com/hhoeflin/hdf5r/issues/142 (closed 24 Mar 2020; probably released with v1.3.3 on CRAN)
# remotes::install_github("hhoeflin/hdf5r")

# 2. Install packages from CRAN
# -----------------------------

packages <- read.requirements("R/r-requirements.txt")

install.packages(packages, repos = "http://cran.rstudio.com/")

# 3. ROracle
# ----------

# Note: The following lines require to have Oracle's Instant Client to be installed,
#       with ORACLE_HOME pointing to the installation directory.

oracle_home <- Sys.getenv("ORACLE_HOME")

Sys.setenv(OCI_LIB = oracle_home)
Sys.unsetenv("ORACLE_HOME")

install.packages('R/ROracle_1.3-2.tar.gz', repos = NULL)

# 4. Install my own packages
# --------------------------

# The following remote access installs via EUMETSAT's gitlab don't work for the time being.

#remotes::install_git("https://gitlab.eumetsat.int/ro/R/robtools.git",
#                     credentials = git2r::cred_token(token = "GITLAB_EUMETSAT_READONLY_TOKEN"))

#remotes::install_git("https://gitlab.eumetsat.int/ro/R/mdbtools.git",
#                     credentials = git2r::cred_token(token = "GITLAB_EUMETSAT_READONLY_TOKEN"))

#remotes::install_git("https://gitlab.eumetsat.int/ro/R/ombtools.git",
#                     credentials = git2r::cred_token(token = "GITLAB_EUMETSAT_READONLY_TOKEN"))

 ## FIXME: This should work, but it doesn't... and the package is by now deprecated...
 ##remotes::install_git("https://gitlab.com/marq/yaros-rtools.git",
 ##                     credentials = git2r::cred_token(token = "GITLAB_COM_READONLY_TOKEN"))

#remotes::install_git("https://gitlab.eumetsat.int/marq/R-cmarticles.git",
#                     credentials = git2r::cred_token(token = "GITLAB_EUMETSAT_READONLY_TOKEN"))

# Instead, we live off local directories - make sure they are up-to-date...

remotes::install_local("/Users/marq/src/R/robtools", upgrade = "never", force = TRUE)
remotes::install_local("/Users/marq/src/R/mdbtools", upgrade = "never", force = TRUE)
remotes::install_local("/Users/marq/src/R/ombtools", upgrade = "never", force = TRUE)
remotes::install_local("/Users/marq/src/R/cmarticles", upgrade = "never", force = TRUE)

# 5. Reset environment variables
# ------------------------------

# Note: As before, the following lines are for ROracle

Sys.setenv(ORACLE_HOME = oracle_home)
Sys.unsetenv("OCI_LIB")

#Sys.setenv(PATH = path_gen)

Sys.unsetenv("LDFLAGS")
Sys.unsetenv("CPPFLAGS")

Sys.unsetenv("PKG_LIBS")
Sys.unsetenv("PKG_CPPFLAGS")

# 6. Set up Jupyter Lab kernel
# ----------------------------

IRkernel::installspec()
