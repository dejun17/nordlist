#!/bin/bash
#
# This script works with the NordVPN Linux CLI and the JDownloader2
# "reconnect" option.  It might also work with other applications.
#
# The script creates a list of the top 20 Recommended Servers based on
# your current location.  When the script is called it checks if your
# current server is in the list, deletes that entry, and connects to
# the next server. When no servers remain it connects to another city
# and retrieves a new list.
#
# Requires 'curl' and 'jq'.  eg "sudo apt install curl jq"
# Make sure the script is executable, eg "chmod +x jd.reconnect.sh"
#
# In JDownloader2:
#   Settings - Reconnect
#       Reconnect Method: External Tool
#       Command to use = full path to this script
#   Usage: (JD2 toolbar button)
#       "Perform a Reconnect"
#
# To start off with a fresh list or a new location simply delete the
# existing server list.  A new list will be created.
#
# Known Issue
#   Connection may fail if you have another computer already connected
#   to the target server using the same technology and protocol.
#   Can delete the in-use server from the list or use another city.
#
# =====================================================================
#
# Specify the full path and filename to use for the server list.
# (Use the absolute path)
jdlist="/home/$USER/Downloads/nord_jd2servers.txt"
#
# Specify alternate cities to use as the server lists are emptied.
# These will be used in rotation.
jdcity1="Vancouver"
jdcity2="Seattle"
jdcity3="Los_Angeles"
jdcity4="Toronto"
jdcity5="Atlanta"
#
# Send notifications when changing servers. "y" or "n"
notifications="y"
#
# =====================================================================
#
function getserverlist {
    curl --silent "https://api.nordvpn.com/v1/servers/recommendations?limit=20" | jq -r '.[].hostname' > "$jdlist"
    echo "EOF" >> "$jdlist"
}
function getcurrentinfo {
    currenthost=$( nordvpn status | grep -i "Hostname" | cut -f2 -d' ' )
    currentcity=$( nordvpn status | grep -i "City" | cut -f2 -d':' | cut -c 2- | tr ' ' '_' )
    shorthost=$( echo "$currenthost" | cut -f1 -d'.' )
    servercount=$(( $(wc -l < "$jdlist") - 1 ))
}
function getnextcity {
    if [[ "$currentcity" == "$jdcity1" ]]; then
        nextcity="$jdcity2"
    elif [[ "$currentcity" == "$jdcity2" ]]; then
        nextcity="$jdcity3"
    elif [[ "$currentcity" == "$jdcity3" ]]; then
        nextcity="$jdcity4"
    elif [[ "$currentcity" == "$jdcity4" ]]; then
        nextcity="$jdcity5"
    else
        nextcity="$jdcity1"
    fi
}
# create the list if it doesn't exist
if [[ ! -e "$jdlist" ]]; then
    getserverlist
fi
#
# check if the current hostname is in the list
getcurrentinfo
if grep "$currenthost" "$jdlist"; then
    # remove the current hostname and save the list (grep inverse)
    grep -v "$currenthost" "$jdlist" > tmpfile && mv tmpfile "$jdlist"
fi
#
# get the next server from the top of the list
nextserver=$( head -n 1 "$jdlist" | cut -f1 -d'.' )
#
if [[ "$nextserver" == "EOF" ]]; then
    # if there are no more servers then change city and get a new list
    getnextcity
    nordvpn connect "$nextcity"; wait
    sleep 3
    getserverlist
else
    # connect to the next server
    nordvpn connect "$nextserver"; wait
    sleep 3
fi
#
if [[ "$notifications" =~ ^[Yy]$ ]]; then
    getcurrentinfo
    getnextcity
    notify-send "JDReconnect - $currentcity $shorthost" "$servercount servers remain.  Next city: $nextcity"
fi
