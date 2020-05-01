#! /usr/bin/env Rscript

# Updating and installing R packages
# ==================================
#
# C. Marquardt, Darmstadt
#
# 22 March 2020
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
# At present (March 2020), there are several unrelated issues which
# complicate (re-) building R and its packages. These are:
#
#  - Rcpp v1.04 has a bug that prohibits building packages using it
#    on MacOS; therefore, the development version is installed for
#    the time being;
#  - HDF5 v1.12 seems to have broken several software packages. This
#    affects not only the hdf5r package, but also the HDF interface
#    as available in the brewed version of the Armadillo C++ library.
#    As many R packages use RcppArmadillo, those will then not build
#    against the brewed Armadillo.
#
#    The workarounds are:
#
#     - brew unlink armadillo before running this script (relinking
#       afterwards is fine);
#     - Not building hdf5r for the time being; I don't use. The
#       maintainer knows about the problem (there's a ticket at GitHub:
#       https://github.com/hhoeflin/hdf5r/issues/142)
#
#  - SimpleFeatures (sf) doesn't discover the header files of the Proj
#    library; the problem is fixed in the development version available
#    on GitHub which is build for the time being.
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

# Temporary support for HDF5@1.10 so that hdf5r can be build (this doesn't work, though...)

#path_gen <- Sys.getenv("PATH")
#path_hdf <- paste(prefix, "/opt/hdf5@1.10/bin", sep = "")

#Sys.setenv(PATH = paste(path_hdf, path_gen, sep = ":"))

#inc_gen <- paste("-I", prefix, "/include", sep = "")
#inc_hdf <- paste("-I", prefix, "/opt/hdf5@1.10/include", sep = "")

#Sys.setenv(CPPFLAGS = paste(inc_hdf, inc_gen, sep = ":"))
#Sys.setenv(PKG_CPPFLAGS = paste(inc_hdf, inc_gen, sep = ":"))

#lib_gen <- paste("-L", prefix, "/lib", sep = "")
#lib_hdf <- paste("-L", prefix, "/opt/hdf5@1.10/lib", sep = "")

#Sys.setenv(LDFLAGS = paste(lib_hdf, lib_gen, sep = ":"))
#Sys.setenv(PKG_LDFLAGS = paste(lib_hdf, lib_gen, sep = ":"))

# 1.2 Development version of Rcpp - will be fixed with 1.0.5 (or whatever)

# See: https://community.rstudio.com/t/later-package-not-compiling-on-macos-unknown-type-name-uuid-t/57171

install.packages("Rcpp", repos = "https://RcppCore.github.io/drat")

# 1.3 Special case: Bugs fixed on Github but not yet released)

install.packages("remotes", repos = "http://cran.rstudio.com")

# See: https://github.com/r-spatial/sf/issues/1298 (closed 13 Mar 2020; contained in v0.9-x on CRAN)
# remotes::install_github("r-spatial/sf")

# See https://github.com/mjwoods/RNetCDF/issues/75 (closed 29 Apr 2020, not yet released on CRAN)
remotes::install_github("mjwoods/RNetCDF")

# See https://github.com/hhoeflin/hdf5r/issues/142 (closed 24 Mar 2020; not yet released on CRAN)
remotes::install_github("hhoeflin/hdf5r")

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

# 4. Reset environment variables
# ------------------------------

# Note: As before, the following lines are for ROracle

Sys.setenv(ORACLE_HOME = oracle_home)
Sys.unsetenv("OCI_LIB")

#Sys.setenv(PATH = path_gen)

Sys.unsetenv("LDFLAGS")
Sys.unsetenv("CPPFLAGS")

Sys.unsetenv("PKG_LIBS")
Sys.unsetenv("PKG_CPPFLAGS")
