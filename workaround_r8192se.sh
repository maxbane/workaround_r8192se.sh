#!/bin/bash

# workaround_r8192se.sh
# Written in 2011 by Max Bane.
# Hereby released into the public domain.

DEFAULTPINGHOST="192.168.1.1"

function printSummary {
    echo -e 'workaround_r8192se.sh\n'

    echo -e 'A simple bash script for working around buggy drivers for the Realtek 8192SE wifi card. The 64 bit version of the official driver (kernel module r8192se_pci) tends to drop connections randomly. This script regularly pings your router (or any other host you specify) to check whether the connection is still up; if not, it reloads the kernel module and waits for NetworkManager (or whatever you use) to reassociate with your wireless access point. This usually fixes things up until the next random disconnect. Joy!\n' | fold -s

    echo -e 'If the necessity of running this script just to use wifi on your 64 bit machine bothers you, complain to Realtek, the authors of the buggy driver.\n' | fold -s

    echo -e 'Written in 2011 by Max Bane.\nHereby released into the public domain.'
}

function printUsage {
    echo -e "USAGE: $0 [-h] [-t SECS] [-s SECS] [-r SECS] [PINGHOST]\n"
    echo -e "PINGHOST optionally specifies the host to ping; if omitted, the default PINGHOST is $DEFAULTPINGHOST" | fold -s
    echo -e "\nOPTIONS:"
    echo -e "  -h:\t\tPrint this help and exit." | fold -s
    echo -e "  -t SECS:\tSet the ping timeout in seconds." | fold -s
    echo -e "  -s SECS:\tSet the sleep time in seconds between pings." | fold -s
    echo -e "  -r SECS:\tSet the delay in seconds to wait for wifi reassociation after reloading the kernel module." | fold -s
}

# seconds to wait for ping responses
PINGTIMEOUT=2

# seconds to wait in between ping attempts
SLEEPTIME=4

# seconds to wait for wifi reassociation after module reload
# (in addition to SLEEPTIME)
REASSOCTIME=5

while getopts ":ht:s:r:" option; do
    case $option in
        h) printSummary; echo; printUsage; exit 0;;

        t) PINGTIMEOUT=$OPTARG;;
        s) SLEEPTIME=$OPTARG;;
        r) REASSOCTIME=$OPTARG;;

        \?) echo "Unknown option: -$OPTARG" >&2
             exit 1;;

        :) echo "Option -$OPTARG requires an argument." >&2
             exit 1;;
    esac
done

shift $((OPTIND-1))

if [ `whoami` != "root" ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# whom to ping to check connection status
if [ "$1" ]; then
    PINGHOST=$1
else
    PINGHOST=$DEFAULTPINGHOST
fi

# we'll keep track of how long we've been running, and how many times we've had
# to reload the module
let STARTTIME=`date +%s`
let NUMRELOADS=0

function report {
    echo -e "$NUMRELOADS reloads in $((`date +%s` - STARTTIME)) seconds."
}

function quitOnINT {
    reset
    report
    echo "Exiting."
    trap "" SIGINT
    kill -s SIGINT $$ # let SIGINT propagate to any parent procs
    exit 0
}

trap quitOnINT SIGINT 

function doCommand {
    case $1 in
        "r") report;;

        "q") echo
             report
             echo "Exiting."
             exit 0;;

        "f") doReload;;

        "p") echo -n "Paused. Strike RETURN to continue. "
             read -s && echo;;
    esac
}

function doReload {
    echo -n "Reloading r8192se_pci kernel module... "
    modprobe -r r8192se_pci && modprobe r8192se_pci && echo "DONE"
    ((NUMRELOADS += 1))
    echo "Waiting for wifi reassociation..."
    sleep $REASSOCTIME
}

# print out intro message
echo -e "[Run \"$0 -h\" for help.]"
echo -e "Pinging host $PINGHOST every $SLEEPTIME seconds."
echo -e "Ping timeout: ${PINGTIMEOUT}s."
echo -e "Wifi reassociation delay: ${REASSOCTIME}s.\n"

# main loop
while true 
do
    echo -n "Pinging host at $PINGHOST... "
    if ping -q -i 0.2 -w $PINGTIMEOUT $PINGHOST > /dev/null; then
        echo "ALIVE"
    else
        echo "DEAD"
        doReload
    fi

    echo -e "[p: pause | r: report | f: force reload | q: quit]"
    read -s -t $SLEEPTIME -N 1 COMMAND && doCommand $COMMAND
done
