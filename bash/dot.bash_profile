# ~/.bash_profile
# ---------------

#echo "Running through ~/.bash_profile..."

# 1. Count how often this script has been called
# ----------------------------------------------

if [ -z $HAVE_BASH_PROFILE_COUNT ]; then
   export HAVE_BASH_PROFILE_COUNT=1
else
   export HAVE_BASH_PROFILE_COUNT=$(($HAVE_BASH_PROFILE_COUNT+1))
fi
    
# 2. Source .bashrc
# -----------------

if [ -z $HAVE_BASHRC_COUNT ]; then
   if [ -f ${HOME}/.bashrc ]; then
       . ${HOME}/.bashrc
   fi
fi

# 3. Loop through all properly named files in ~/.profile.d
# --------------------------------------------------------

for f in ${HOME}/.profile.d/[0-9][0-9]* ; do
#    echo "Sourcing $f..."
    . "$f"
done
