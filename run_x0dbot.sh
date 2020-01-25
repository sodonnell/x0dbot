#!/usr/bin/env bash
#
# Execute this script to launch the x0dbot process and real-time 
# logging into the background. You may use the -f flag to follow 
# the log file in real-time.
#
# Sean O'Donnell <sean@seanodonnell.com>
#
# $Id: run_x0dbot.sh,v 1.1.1.1 2011/01/29 13:03:07 seanodonnell Exp $
#

SCRIPT="x0dbot.pl e"
SCRIPT_LOG=x0dbot.log

echo -e "Running the program ($SCRIPT) into the background...\n"

./$SCRIPT 2>&1 >> ./$SCRIPT_LOG &

echo -e "Done.\n"

if [ $2 -e "-f" ]; then
	echo -e "Following log file ($SCRIPT_LOG)...\n\n"
	tail -f ./$SCRIPT_LOG
fi
