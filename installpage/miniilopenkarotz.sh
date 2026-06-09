#!/bin/sh
echo "Welcome to the installation of OpenKarotz."
echo "Please wait while OpenKarotz is installed..."
dbus-send --system --dest=com.mindscape.karotz.Led /com/mindscape/karotz/Led com.mindscape.karotz.KarotzInterface.pulse string:"" string:"660099" string:"000000" int32:400 int32:-1 >/dev/null 2>/dev/null

# start download the files we need
echo "Downloading openkarotz as ZIP file, please wait..."
wget -O /tmp/miniilopenkarotz.zip http://karotz.miniil.be/miniilosok/miniilopenkarotz.zip
if [ $? -eq 0 ]; then
    echo "Download successful"
else
    echo "Download failed with error code $?"
    echo "Done !"
    exit 1
fi
echo "Installation will start..."
# end download the files we need

# Start extract package file
echo "Checking file integrity, please wait..."
md5sum /tmp/miniilopenkarotz.zip
if [ $? -eq 0 ]; then
    echo "Integrity check successful"
else
    echo "Integrity check failed with error code $?"
    echo "Done !"
    exit 1
fi

echo "Extracting the zip file, please wait..."
/bin/unzip -oq /tmp/miniilopenkarotz.zip -d /tmp
if [ $? -eq 0 ]; then
    echo "extraction successful"
else
    echo "extraction failed $?"
    echo "Done !"
    exit 1
fi
# End extract package file

# Start Install OpenKarotz
echo "Installing /usr/openkarotz, please wait..."
[ ! -d "/usr/openkarotz" ] && mkdir /usr/openkarotz
/bin/unzip -oq /tmp/openkarotzusr.zip -d /usr/openkarotz
echo "OpenKarotz installed in /usr/openkarotz"
# End Install OpenKarotz

# Start Install WWW
echo "Installing /usr/www including /usr/www/cgi-bin, please wait..."
[ ! -d "/usr/www" ] && mkdir /usr/www
/bin/unzip -oq /tmp/openkarotzwww.zip -d /usr/www
chmod -R 755 /usr/www/cgi-bin
cp -f /usr/www/cgi-bin/dbus_events /usr/scripts/dbus_watcher
ln -s /usr/openkarotz/Snapshots /usr/www/snapshots
ln -s /usr/openkarotz/Tmp /usr/www/ttscache
echo "WWW installed in /usr/www"
# End Install WWW

dbus-send --system --dest=com.mindscape.karotz.Led /com/mindscape/karotz/Led com.mindscape.karotz.KarotzInterface.pulse string:"" string:"00FF00" string:"000000" int32:700 int32:-1 >/dev/null 2>/dev/null
echo "End installing OpenKarotz."
echo "Go to the homepage of your Karotz and press F5 (refresh the page) to start OpenKarotz."
echo "Done!"
