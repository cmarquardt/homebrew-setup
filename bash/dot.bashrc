# ~/.bashrc
# ---------

#echo "Running through ~/.bashrc..."

# 1. Count how often this script has been called
# ----------------------------------------------

if [ -z $HAVE_BASHRC_COUNT ]; then
   export HAVE_BASHRC_COUNT=1
else
   export HAVE_BASHRC_COUNT=$(($HAVE_BASHRC_COUNT+1))
fi

# 2. Loop through all properly named files in ~/.bash_completion.d
# ----------------------------------------------------------------
#
# The following trick is from https://stackoverflow.com/a/17902999

if [ -z "$(find ${HOME}/.bash_completion.d name '[0-9][0-9]_*' -prune -empty 2>/dev/null)" ]; then
   for f in ${HOME}/.bash_completion.d/[0-9][0-9]_* ; do
      source "$f"
   done
fi

# 3. Loop through all properly named files in ~/.bashrc.d
# -------------------------------------------------------

for f in ${HOME}/.bashrc.d/[0-9][0-9]*; do
    . "$f"
done
