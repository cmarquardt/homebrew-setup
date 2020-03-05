#! /usr/bin/env Rscript

# Updating and installing R packages
# ==================================
#
# C. Marquardt, Darmstadt
#
# 29 February 2020
#
# Note: ROracle is temporarily installed in a seperate script. However,
#       ROracle, if installed with Oracle Instant clients,
#       requires the following:
#
#          export OCI_LIB=$ORACLE_HOME
#          unset ORACLE_HOME
#
#            ...build the package ...
#
#          export ORACLE_HOME=OCI_LIB
#          unset OCI_LIB
#
#       on the shell prior to building. The code below
#       does the same manipulation of environment variables,
#       assuming that ORACLE_HOME is pointing to the
#       installation place of an Oracle Instant client.
#
#       On Homebrew, some packages (in particular: jpeg)
#       require additional compiler options which are cab
#       be passed into the R build system by setting the
#       corresponding environment variables like PKG_CPPFLAGS
#       (generic for R) or JPEG_LIBS (for jpeg).

# 0. A helper function
# --------------------

read.requirements <- function(filename) {
   lst <- gsub("\\s*#.*","", readLines(filename))
   unique(lst[lst != ""])
}


# 1. Environment variables (for the ROracle compilation)
# ------------------------------------------------------

# 1.1 ROracle
# -----------
# Note: The following lines require to have Oracle's Instant Client to be installed.
# Note 2: The proper install of the ROracle package downloaded from CRAN in the
#         current version (v1.3-1) doesn't work as there's an issue with the
#         distributed tarball (see https://community.oracle.com/thread/4014048
#         for details); for the time being, see R-oracle-install.r
# Note 3: The proper installation of the RcppArmadillo package (and those depending
#         on it, like robustreg, robustHD, and rrcovHD) fails if the brew version
#         is actively linked. Unlinking armadillo before building the R packages
#         and relinking it afterwards seem to help.

#oracle_home <- Sys.getenv("ORACLE_HOME")
#Sys.setenv(OCI_LIB = oracle_home)
#Sys.unsetenv("ORACLE_HOME")

# 1.2 Header and library paths
# ----------------------------

prefix <- system("brew --prefix", intern = TRUE)

Sys.setenv(PKG_CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(PKG_LIBS = paste("-L", prefix, "/lib", sep = ""))

Sys.setenv(CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(LDFLAGS = paste("-L", prefix, "/lib", sep = ""))

#Sys.setenv(JPEG_LIBS = paste("-L", prefix, "/lib", sep = ""))

# 2. Install packages from CRAN
# -----------------------------

# Note: The following packages are 'parked' as I currently have not installed
#       the required database backends or C APIs: RMySQL, ROracle

#package.data <- read.csv("r-requirements.txt")
#packages <- package.data$Package

packages <- read.requirements("r-requirements.txt")

#install.packages(packages, repos = "http://cran.rstudio.com/", 
#                           dependencies = "Depends", "Imports")

cat(packages)

# 3. Reset environment variables
# ------------------------------

# Note: As before, the following lines are for ROracle

#Sys.setenv(ORACLE_HOME = oracle_home)
#Sys.unsetenv("OCI_LIB")

#Sys.unsetenv("JPEG_LIBS")

Sys.unsetenv("LDFLAGS")
Sys.unsetenv("CPPFLAGS")

Sys.unsetenv("PKG_LIBS")
Sys.unsetenv("PKG_CPPFLAGS")
