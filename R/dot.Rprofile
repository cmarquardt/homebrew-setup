# User-specific startup file for R
# ================================

# 1. Package compilation
# ----------------------

# Always build packages from source
options(pkgType = "source")

# Paths to Hombrew libraries and eaders
prefix <- system("/opt/brew/bin/brew --prefix", intern = TRUE)

Sys.setenv(PKG_CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(PKG_LIBS = paste("-L", prefix, "/lib", sep = ""))

Sys.setenv(CPPFLAGS = paste("-I", prefix, "/include", sep = ""))
Sys.setenv(LDFLAGS = paste("-L", prefix, "/lib", sep = ""))

# Path to the gdal_config script
Sys.setenv("PATH" = paste(Sys.getenv("PATH"), paste(prefix, "opt", "gdal", "bin", sep = "/"), sep = ":"))


# 2. Python/reticulate support
# ----------------------------

# Location of virtual python environments
Sys.setenv(WORKON_HOME = "/Users/marq/Library/Virtualenvs")

# Reticulate's default python - only for individual projects, never globally (it can't be overwritten from within R)
#Sys.setenv(RETICULATE_PYTHON = "/opt/brew/bin/python3",

# 3. Clean up
# -----------

rm(prefix)

