#! /usr/bin/env bash
# Re-installing Python packages
# =============================
#
# C. Marquardt, Darmstadt
#
# 21 March 2020
#
# This script is supposed to re-install (re-compile) all existing Python
# packages in the same versions as they are currently available. The purpose
# is to perform a clean rebuild of all packages, e.g. after an update of
# Homebrew libraries or even the compiler(s).
#
# For some packages, a special treatment is required, either because they
# are installed viw Homebrew, or they require certain environment variables.
# In one case (gdal), the version of the python module depends on the version
# of the corresponding library being installed with Homebrew.
#
# Notes for Python 2.7:
# ---------------------
#  - all version numbers are considered to be frozen;
#  - virtualenv, virtualenvwrapper and friends are installed for for both
#    Python 2 and Python 3 as they are used when virtual environments are
#    build for the respective python; however, the Python 2 version is
#    later on as that makes the installed executable/shell script to install
#    Python 2 virtual environments by default;
#  - numpy and scipy are installed via brew, with me maintaining packages
#    for python@2;
#  - some special cases are treated outside of the requirements file below
#    as they require special environment variable settings or similar;
#  - pip utilities (pip-date, pip-chill, ...) are installed for Python 3.
#
# Notes for Python 3.7:
# ---------------------
#  - So far, we only have a base set of modules - it will grow over time.
#  - All pip related tools (pipdate, pip-chill. pip-check. pipdeptree) are
#    in Python 3 only, as Python 2 is frozen.

# 1. Shell variables
# ------------------

HOMEBREW_PREFIX=`brew --prefix`

export HDF5_DIR=${HOMEBREW_PREFIX}  # Apparently required for netCDF4

# 2. Python 3.x
# -------------

# 2.1 Core packages - numpy and gdal require special treatment...

pip3 install --force-reinstall --no-deps $(pip3 freeze | grep -ivE 'numpy|scipy|gdal')

# 2.2 Special cases

# Numpy and Scipy are maintained via Homebrew

brew unlink numpy
brew reinstall numpy

brew unlink scipy
brew reinstall scipy

# Gdal version must match of the installed brewed version

GDAL_VERSION=`brew list --versions gdal | sed -e 's/gdal //g' -e 's/\_[123456789]//g'`
pip3 install --force-reinstall --no-deps gdal==${GDAL_VERSION}

# 3. Python 2.7
# -------------

# 3.1 Core packages - various packages require special treatment

pip2 install --force-reinstall --no-deps $(pip2 freeze | grep -ivE 'numpy|scipy|basemap|cartopy|gdal|cx_oracle|eccodes|eugene|fix-osx-virtualenv')

# 3.2 Special cases

# Numpy, eugene and ecccodes are maintained via Homebrew

brew unlink numpy4python@2
brew reinstall numpy4python@2

brew unlink scipy4python@2
brew reinstall scipy4python@2

brew reinstall eccodes-cm
brew reinstall eugene

# fix-osx-virtualenv is build from github

pip2 install --force-reinstall --no-deps git+https://github.com/gldnspud/virtualenv-pythonw-osx

# Cartopy requires a veriable setting because pkg-config fails with an error

CPPFLAGS="-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H" \
   pip2 install --force-reinstall --no-deps Cartopy==0.17.0

# Oracle drivers are only installed if needed and require a source build

if [ "x$ORACLE_HOME" != "x" ]; then
    FORCE_RPATH=yes pip2 install --force-reinstall --no-deps --no-binary :all: cx_Oracle==7.3.0
fi

# urlgrabber requires pycurl, which has special needs for installation

#PYCURL_CURL_CONFIG=${HOMEBREW_PREFIX}/opt/curl/bin/curl-config \
#   pip2 install --no-binary :all: pycurl==7.43.0.5
#pip2 install urlgrabber==4.1.0

# Basemap requires geos and needs to know where it sits

#GEOS_DIR=`brew --prefix geos` \
#   pip2 install --force-reinstall --no-deps https://github.com/matplotlib/basemap/archive/v1.1.0.tar.gz

