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

## Install homebrew

I've cloned the Homebrew installation scripts and updated them to install into `/opt/homebrew`; the repository is [on GitHub](https://github.com/cmarquardt/homebrew-install). To install from scratch:

    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/cmarquardt/homebrew-install/feature/install-elsewhere/install)"

Note: If the paths were not set up prior to running the above installation command, the script will issue a warning that `/opt/homebrew/bin` isn't in `PATH`. That's fine, but update `/etc/paths` now.

## Install software (part I)

The `Brewfile-main` Brewfile installs the majority of the software I use and also adds all required taps. Use it with

    brew bundle --file Brewfile-main

## Install Python packages

The main Brewfile also installs python@2; one may thus proceed with installing all Python packages (for both Python 3 and Python 2). The lists of python packages to be installed for both Pathon 2 and Python 3 are contained in the `python-requirements-n.n.txt`requirements files. They are used by the Python module installation script which is used like this:

    ./install-python-packages.sh

## Install R packages

Of course, we also have R packages; there installation proceeds with

    ./install-r-packages.R

Note that the packages to be installed are listed in the file `r-requirements.txt`.

## Install software (part II)

Finally, there are some packages that benefit in particular, form the Python 2 modules; they can be installed with

    brew bundle --file Brewfile-secondary

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
