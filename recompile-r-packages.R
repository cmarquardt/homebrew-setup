#! /usr/bin/env Rscript

# Recompiling R packages
# ======================
#
# C. Marquardt, Darmstadt
#
# 03 August 2020
#
# Recompile all installed R packages from source without updating.
#
# This scripts performs a recompilation of all installed R packages
# for their currently installed versions; that is, packages are not
# automatically updated. The typical usecase is an updated of the
# (Fortran or C/C++) compiler which breaks the existing packages due
# to changes in the location of shared libraries; this is a problem
# on macOS and with Homebrew.
#
# There is no sophisticated dependency resolution; packages failing
# to recompile will be tried again in a second (or third, or...) pass
# through the remaining packages. If no further packages can be
# installed, the scriptterminates (and then tries to install a custom
# version of ROracle).
#
# At the end of the process, the list of the failed packages and their
# version is printed.

# 1. Libraries and a helper function
# ----------------------------------

library(magrittr)
library(dplyr)
library(remotes)

read.requirements <- function(filename) {
   lst <- gsub("\\s*#.*","", readLines(filename))
   unique(lst[lst != ""])
}

install.package.list <- function(plst, lib) {

    success <- data.frame(Package = character(),
                          Version = character())
    failed  <- data.frame(Package = character(),
                          Version = character())

    for (i in seq_along(plst$Package)) {

        package <- plst[i, ] # extract i-th row

        tryCatch(
            error = function(cnd) {
                failed <<- rbind(failed, package)  # This function is not evaluated in the environment of tryCatch, so <<- is required...
            },
            {res <- remotes::install_version(package$Package,
                                     version = package$Version,
                                     dependencies = FALSE,
                                     quiet = TRUE,
                                     type = "source",
                                     lib = lib,
                                     repos = "https://cran.rstudio.com/")
            cat(paste("Recompiling", package$Package, "v", package$Version, "- ok.\n"))
            success <- rbind(success, package) # This statement is evaluated in the context of tryCatch() and doesn't need <<-
            }
        )
    }

    list(success = success, failed = failed)
}

# 1. Environment variables supporting Homebrew
# --------------------------------------------

# 1.1 ROracle
# -----------



# 1.2 Homebrew include and library paths
# --------------------------------------

prefix <- system("brew --prefix", intern = TRUE)

Sys.setenv(PKG_CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(PKG_LIBS = paste("-L", prefix, "/lib", sep = ""))

Sys.setenv(CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(LDFLAGS = paste("-L", prefix, "/lib", sep = ""))

# 2. Install packages from CRAN
# -----------------------------

# Note: We rebuild all packages apart from ROracle as we use our own version.
#
# Note: The proper installation of the RcppArmadillo package (and those depending
#       on it, like robustreg, robustHD, and rrcovHD) fails if the brew version
#       is actively linked. Unlinking armadillo before building the R packages
#       and relinking it afterwards seems to help.

lib      <- .libPaths()[1]

packages <- as.data.frame(installed.packages(lib), stringsAsFactors = FALSE) %>%
                 dplyr::select(Package, Version) %>%
                 dplyr::filter(Package != "ROracle")

#packages <- packages[(nrow(packages)-5):nrow(packages), ]

n.last   <- length(packages$Package) + 1
plst     <- packages
n.failed <- length(plst$Package)

while (n.failed < n.last) {
    n.last   <- n.failed
    res      <- install.package.list(plst, lib)
    n.failed <- length(res$failed$Package)
    plst     <- res$failed
}

# 3. Install ROracle
# ------------------

# Note: The following lines require to have Oracle's Instant Client to be installed,
#       with ORACLE_HOME pointing to the installation directory.
# Note: The proper install of the ROracle package downloaded from CRAN in the
#       current version (v1.3-1) doesn't work as there's an issue with the
#       distributed tarball (see https://community.oracle.com/thread/4014048
#       for details); for the time being, see R-oracle-install.r

oracle_home <- Sys.getenv("ORACLE_HOME")

Sys.setenv(OCI_LIB = oracle_home)
Sys.unsetenv("ORACLE_HOME")

install.packages('R/ROracle_1.3-2.tar.gz', repos = NULL)

# 4. Provide infomation on packages that couldn't be recompiled
# --------------------------------------------------------------

cat("\nThe following packges could not be recompiled:\n\n")
print(res$failed)

# 5. Reset environment variables
# ------------------------------

# Note: As before, the following lines are for ROracle

Sys.setenv(ORACLE_HOME = oracle_home)
Sys.unsetenv("OCI_LIB")

Sys.unsetenv("LDFLAGS")
Sys.unsetenv("CPPFLAGS")

Sys.unsetenv("PKG_LIBS")
Sys.unsetenv("PKG_CPPFLAGS")
