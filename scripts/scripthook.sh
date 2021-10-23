#!/bin/sh

LOGFILE="/tmp/jpilot_plugin.log"

startup() {
	echo "" > ${LOGFILE}
	echo "startup" >> ${LOGFILE}
}

presyncpreconnect() {
	echo "presyncpreconnect" >> ${LOGFILE}
}

presync() {
	echo "presync" >> ${LOGFILE}
}

sync() {
	echo "sync" >> ${LOGFILE}
}

postsync() {
	echo "postsync" >> ${LOGFILE}
}

exitcleanup() {
	echo "exitcleanup" >> ${LOGFILE}
}

case "$1" in
	STARTUP)
		startup
		;;
	PRESYNCPRECONNECT)
		presyncpreconnect
		;;
	PRESYNC)
		presync
		;;
	SYNC)
		sync
		;;
	POSTSYNC)
		postsync
		;;
	EXITCLEANUP)
		exitcleanup
		;;
	*)
		echo "$0: Missing Argument" >> ${LOGFILE}

esac

exit 0
