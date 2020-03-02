#! /bin/bash
#
# Installing shell startup scripts
# ================================
#
# C. Marquardt, Darmstadt
#
# 29 February 2020

# ~/.bashrc.d
# -----------

mkdir -p ~/.bashrc.d
cp -v bash/dot.bashrc.d/* ~/.bashrc.d

# ~/.profile.d
# ------------

mkdir -p ~/.profile.d
if [ -L ~/.profile.d/99_prompt ]; then
   if [ -e ~/.bashrc.d/99_prompt ]; then
      rm -f ~/.profile.d/99_prompt
      ln -s ~/.bashrc.d/99_prompt ~/.profile.d
   fi
fi 

# ~/.bash_completion.d
# --------------------

mkdir -p ~/.bash_completion.d

# ~/.bashrc, ~/.profile and ~/.bash_profile
# -----------------------------------------

cp -v bash/dot.bashrc ~/.bashrc
cp -v bash/dot.bash_profile ~/.bash_profile
cp -v bash/dot.profile ~/.profile

# Done
# ----

echo "Done."
