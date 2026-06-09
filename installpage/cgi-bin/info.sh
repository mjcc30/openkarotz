#!/bin/sh

check_dir () {
    if [ -d $1 ]; then
        echo "'$1' was found" 
    else
        echo "'$1' not found" 
    fi
}

check_md5 () {
    if [ -f $1 ]; then
        md5sum $1
    else
        echo "'$1' not found"
    fi
}

echo -en "Content-Type: text/plain\r\n\r\n"
cat /karotz/etc/motd
echo "=============================================================="
echo "                   UPTIME & CURRENT TIME                      "
echo "=============================================================="
echo ""
uptime
date
echo ""
echo "=============================================================="
echo "                          SYSLOG                              "
echo "=============================================================="
echo ""
cat /var/log/messages
echo ""
echo "=============================================================="
echo "                          DMESG                               "
echo "=============================================================="
echo ""
dmesg
echo ""
echo "=============================================================="
echo "                            PS                                "
echo "=============================================================="
echo ""
ps
echo ""
echo "=============================================================="
echo "                            ENV                               "
echo "=============================================================="
echo ""
env
echo ""
echo "=============================================================="
echo "                        PACKAGE CHECKS                        "
echo "=============================================================="
echo ""
check_dir "/usr/openkarotz"
check_dir "/usr/karotz/FreeRabbits"
check_md5 "/usr/scripts/dbus_watcher"
check_md5 "/usr/karotz/FreeRabbits/commander.py"
check_md5 "/usr/karotz/FreeRabbits/dbus_watcher"
echo ""
echo "=============================================================="
echo "                   LS ROOT DIRECTORY & MOUNT                  "
echo "=============================================================="
echo ""
ls -l /
mount
echo ""
echo "=============================================================="
echo "                        NETWORK CHECKS                        "
echo "=============================================================="
echo ""
ifconfig
iwconfig
cat /etc/resolv.conf
ping www.miniil.be -c1
echo ""
echo "=============================================================="
echo "                              EOF                             "
echo "=============================================================="
echo ""
echo ""

