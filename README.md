# Settung up Homebrew (in a non-default location)

I like Homebrew, but I don't like its maintainer's of using `/usr/local` as an ordinary user, interfering with year-long best practices in the Unix world. I instead would like to have it installed in another place (which may belong to an ordinary user), say `/opt/homebrew`.

This requires a slightly different installation process, but afterwards most things work as they should, despite the different `brew --prefix` directory.

## Setting up PATHs

Obviously, `/opt/homebrew/bin` must be in the PATH. To accomplish this, edit the file `/etc/paths` with `sudo` and insert `/opt/homebrew/bin`. In my case, the resulting `/etc/paths` is:

    /opt/homebrew/bin
    /usr/local/bin
    /usr/bin
    /bin
    /usr/sbin
    /sbin

Note that the executables in omebrew now take precedence over all other ones, including those installed in `/usr/local/bin`. It might be better to insert the Homepref prefix only after `/usr/local/bin` so that software installed in `/usr/local/bin` takes precedence; that probably depends on how is using Homebrew and `/usr/local`. I tend to install software to `/usr/local` that is not available in Homebrew (e.g. (La)TeX); thus there is usually no conflict.

One conflict I did experience once is Docker; I use the installer from Docker Hub which places its command line tools into `/usr/local`. For a while, I had one Homebrew package that dependen on their Docker, so its installation would place a second set of Docker command line tools into Hombrew, shadowing the official ones. One workaround would be to install that Homebrew package without dependencies. On the other hand, I actually never experienced any real problems with Docker while I had bot sets of command line tools as the Homebrew version was reasonably aligned with offcial Docker releases.

## Setting up the shell

Initialisation scripts for`bash` are provided in the subdirectory tree with the same name; they can be installed into `$HOME` using

    install-shell-init.sh

and place files to be sourced into `~/.bashrc.d` and `~/.profile.d`. In addition, the create new initialisation files `~/.bashrc` and `~/.bash_profile`, and finally create a directory to hold command line completions for the bash shell.

## Setting up private tokens and `~/.ssh`

Further installation steps (in particular for some homebrew packges from my tap) require access to protected git repositories; therefore, the configuration of `ssh` keys and GitHub/GitLab authentication tokens is required before the following steps can proceed.

## Installing homebrew

I've cloned the Homebrew installation scripts and updated them to install into `/opt/homebrew`; the repository is [on GitHub](https://github.com/cmarquardt/homebrew-install). To install from scratch:

    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/cmarquardt/homebrew-install/feature/install-elsewhere/install)"

Note: If the paths were not set up prior to running the above installation command, the script will issue a warning that `/opt/homebrew/bin` isn't in `PATH`. That's fine, but update `/etc/paths` now.

## Installing brewed software

The `Brewfile` installs the majority of the software I use and also adds all required taps. Use it with

    cd homebrew
    brew update
    brew bundle --file Brewfile

This will install a number of software packages including Python 2 and Python 3 together with numpy, along with several editors (Atom, Text Mate and Sublime Text).

**Caveat:** The installation of the older numpy version for Python@2 conflicts with the current numpy for Python 3 due to the `f2py`binary. For the Python@2 version, this executable is therefore renamed to `f2py2`which may lead to issues when the numpy distutils call this script.

**Note:** Apparently, gdal includes Python3 bindings and install python scripts to `/opt/homebrew/bin`. This fails if another gdal for python is available; therefore, the brew formula has to be linked with `brew link --overwrite gdal` if being reinstalled.

**Note:** Some python packages make attempts to create directories immediately below /opt/homebrew in order to install documentation; examples are mx.Base and cx_Oracle. In order for this to work, run

    sudo chown marq:admin /opt/homebrew

before installing the python packages.

## Installing Python packages

The next step is to install Python packages (for both Python 3 and Python 2). The lists of python packages to be installed for both Pathon 2 and Python 3 are contained in the `python-requirements-n.n.txt`requirement files, where `n.n`denotes the version of Python. The entire collection is installed with:

    ./install-python-packages.sh

## Installing R packages

Of course, we also have R packages; they can be installed with

    ./install-r-packages.R

Note that the packages to be installed are listed in the file `r-requirements.txt`.

## Setting up virtual environments

At present, `virtualenv` and `virtualenvwrapper` are installed for both Python2 and Python3. Because the modules for Python2 is installed last, however, the actual commands are using Python2. Because of this, the virtualenv and virtualenvwrapper scripts by default install Python2-based virtual environments.

After opening up a shell for the first time after `virtualenvwrapper` has been installed, the shell initialisation script will load the `virtualenvwrapper.sh` startup file and populate the root directory of the virtual environments (through the environment variable `WORKON_HOME`). ***After*** this has happened, copy the startup files for virtual environments into this directory (they will overwrite the default versions of these files which don't do anything):

    cp ./virtualenvs/*activate $WORKON_HOME

Notes:

 - It should be possible to install `virtualenv`, `virtualenv-clone` and `virtualenvwrapper` for Python3 only, and then use virtualenv's configuration file `virtualenv.ini` to ensure that Python2 virtual environments are created by default. I did not investigate this much because virtualenvwrapper.sh searches for `python` as executable for Python; and that one points to Python2 right now.

## Setting up Jupyter Lab and Notebooks

Create a (jointly used) configuration file for Jupyter Lab and Notebook with

    jupyter notebook --generate-config

and edit the resulting file `~/.jupyter/jupyter_notebook_config.py` to

 - set the location of the notebooks,
 - set the port the notebook server serves,
 - not open the browser when launching the server,
 - not require a token upon first startup.

As some parts of the installation of Jupyter and its extensions are located in the system folders of the Python 3 installation; if the latter is newly build or upgraded (e.g., via Homebrew), some setup needs to be done:

    # Re-build jupyterlab
    jupyter lab build

    # Re-build jupyterlab templates
    jupyter labextension install jupyterlab_templates

To set up a Python kernel using a dedicated virtual environment, create a virtual environment based on the Python version required (Python 2 or Python 3) - say, a Python 2 environment named `yaros-devel`. Then:

    workon yaros-devel
    python2 -m ipykernel install --user --name yaros-devel --display-name "Python 2 (yaros-devel)”

A kernel for R can be installed by starting R ***from the command line*** (the environment variables are required, so doing this from RStudio won't work), and then running

    > IRkernel::installspec()

## Tap into things

Apart from `homebrew/core`, I'm also using the `bundle`, `casks`and `services` taps, as well as one maintained by myself (`cmarquardt/formulae`). The bundle command further requires, well, `bundle`. Running the brewfiles as described above enables them, but it's also possible to activate them manually:

    brew tap homebrew/bundle
    brew tap homebrew/casks
    brew tap homebrew/services
    brew tap cmarquardt/formulae

## Creating your own Brewfiles

I created the brewfiles with

    brew bundle dump --describe

which creates `./Brewfile`; manual editing did the rest.
