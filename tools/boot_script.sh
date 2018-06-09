#!/bin/bash
# see https://askubuntu.com/questions/9853/how-can-i-make-rc-local-run-on-startup
# add to /etc/rc.local
#    add sh /home/oper/swmain/apps/PRP/sw/tools/boot_script.sh
# (2018-04) we added an auto reboot capability.
# This routine runs at system reboot to create a folder called ~/tmp
# with a bootlog file

  # edit 20180509T165124Z
  # REBOOT FOLDER ~/tmp
  # Create if it does not exist
file="$HOME/tmp";
if [ ! -d $file ]
then
  mkdir $file
fi
touch $HOME/tmp/AutoStartFlag
echo boot_script -- create AutoStartFlag >> $HOME/tmp/bootlog
chmod 666 $HOME/tmp/AutoStartFlag

exit 0
