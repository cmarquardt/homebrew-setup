#! /usr/bin/env bash
# Installing Python packages
# ==========================
#
# C. Marquardt, Darmstadt
#
# 29 February 2020
#
# Notes for Python 2.7:
# ---------------------
#  - all version numbers are considered to be frozen;
#  - virtualenv, virtualenvwrapper and friends are installed for for both
#    Python 2 and Python 3 as they rae used when virtual environments are
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

# 2.1 Update pip and setuptools

## python3 -m ensurepip --upgrade

# 2.2 Core packages

## pip3 install -r python/python-requirements-3.x.txt

# 2.3 Special cases

# Gdal version must match of the installed brewed version

#GDAL_VERSION=`brew list --versions gdal | sed -e 's/gdal //g' -e 's/\_[123456789]//g'`
#pip3 install gdal==${GDAL_VERSION}

# parmapper is only available from GitHub

## pip3 install git+https://github.com/Jwink3101/parmapper

# 3. Python 2.7
# -------------

# 3.1 Update pip and setuptools

python2 -m ensurepip --upgrade
pip2 install --no-binary :all: setuptools-scm

# 3.2 Core packages

# Note: egenix-mx-base installs documentation and header files in /opt/homebrew/mx,
#       so the Homebrew root directory must be writable. Then:

pip2 install --no-binary :all: -r python/python-requirements-2.7.txt

# 3.3 Special cases

# Cartopy requires a veriable setting because pkg-config fails with an error. It
# also needs an older version proj (proj@7)

CPPFLAGS="-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/opt/brew/opt/proj@7/include" \
LDFLAGS="-L/opt/brew/opt/proj@7/lib" \
   pip2 install Cartopy==0.17.0

# Oracle drivers are only installed if needed and require a source build

if [ "x$ORACLE_HOME" != "x" ]; then
    FORCE_RPATH=yes pip2 install --no-binary :all: cx_Oracle==7.3.0
fi

# parmapper is only available from GitHub

pip2 install git+https://github.com/Jwink3101/parmapper

# urlgrabber requires pycurl, which has special needs for installation

PKG_CONFIG_PATH="/opt/brew/opt/curl/lib/pkgconfig" \
   pip2 install --force-reinstall --no-binary :all: pycurl==7.43.0.3
pip2 install --no-deps urlgrabber==4.1.0

# netCDF4 needs to build against our own netCDF, HDF and curl libraries rather
# than using a wheel

USE_NCCONFIG=0 USE_SETUPCFG=0 \
   NETCDF4_INCDIR=/opt/brew/include NETCDF4_LIBDIR=/opt/brew/lib \
   HDF5_INCDIR=/opt/brew/include HDF5_LIBDIR=/opt/brew/lib \
   pip2 install --force-reinstall --no-deps --no-binary :all: netCDF4==1.5.3

# Basemap requires geos and needs to know where it sits

#GEOS_DIR=`brew --prefix geos` \
#   pip2 install https://github.com/matplotlib/basemap/archive/v1.1.0.tar.gz

# 4. Jupyter Lab
# --------------

# Configuration file
mkdir -p ~/.jupyter
cp python/dot.jupyter/*.py ~/.jupyter

# Re-build jupyterlab
## jupyter lab build

# Re-build jupyterlab templates
## jupyter labextension install jupyterlab_templates

# Re-build jupyterlab ipywidgets support
## jupyter labextension install @jupyter-widgets/jupyterlab-manager
