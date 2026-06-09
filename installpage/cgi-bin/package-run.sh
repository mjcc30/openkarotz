#!/bin/sh
echo -en "Cache-Control: no-cache, no-store, must-revalidate\r\n"
echo -en "Pragma: no-cache\r\n"
echo -en "Expires: 0\r\n"
echo -en "Content-Type: text/plain\r\n\r\n"

dir="/usr/www/cgi-bin/"
pck="${QUERY_STRING#*=}"

if [ -f "${dir}${pck}" ]; then
    echo "Running package script ${pck}..."
    cp -f ${pck} /tmp
    exec >&-
    exec 2>&-
    touch /tmp/package-log.txt
    exec "/tmp/${pck}" > /tmp/package-log.txt
else
    echo "${dir}${pck} was not found!"
fi

