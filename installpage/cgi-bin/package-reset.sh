#!/bin/sh

remove_dir () {
    if [ -d $1 ]; then
        echo "'$1' was found. Removing..." 
        rm -rf $1
    else
        echo "'$1' not found" 
    fi
}

echo "This package will reset some settings and remove directories."
echo "Please wait while some directories are removed..."
dbus-send --system --dest=com.mindscape.karotz.Led /com/mindscape/karotz/Led com.mindscape.karotz.KarotzInterface.pulse string:"" string:"660099" string:"000000" int32:400 int32:-1 >/dev/null 2>/dev/null

remove_dir "/usr/openkarotz"
remove_dir "/usr/karotz/FreeRabbits"

echo "Your Karotz will reboot in about 10 seconds. "
echo "When startup has finished, go to the main webpage of your Karotz."
echo "Done!"

sleep 5
remove_dir "/usr/www"
reboot

