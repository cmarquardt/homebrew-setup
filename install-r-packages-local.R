#! /usr/bin/env Rscript

# Updating and installing R packages - part 01
# ==================================
#
# C. Marquardt, Darmstadt
#
# 09 July 2025
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

# 1. Environment variables
# ------------------------

# 1.1 Header and library paths
# ----------------------------

# Normal setup to support (linked) hombrew libraries

#prefix <- system("brew --prefix", intern = TRUE)

#Sys.setenv(PKG_CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
#Sys.setenv(PKG_LIBS = paste("-L", prefix, "/lib", sep = ""))

#Sys.setenv(CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
#Sys.setenv(LDFLAGS = paste("-L", prefix, "/lib", sep = ""))


# 4. Install local packages
# -------------------------

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
#remotes::install_local("/Users/marq/src/R/kde4sphere", upgrade = "never", force = TRUE)
#remotes::install_local("/Users/marq/src/R/cmarticles", upgrade = "never", force = TRUE)


# 6. Set up Jupyter Lab kernel
# ----------------------------

#IRkernel::installspec()
