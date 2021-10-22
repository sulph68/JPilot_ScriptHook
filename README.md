# JPilot_ScriptHook
JPilot Plugin to run scripts at every stage of the JPilot sync process.
This is based off the sample plugins available at https://github.com/juddmon/jpilot/tree/feature-gtk3.
Its been tested to work successfully on Jpilot version 2.0.1.

It runs a script located within `~/.jpilot/scripthook.sh` which can be edited to execute
any script necessary. This script must be executable for the plugin to run successfully.

## Installation

Download the plugin files and copy them into the JPilot directory `~/.jpilot/plugins`.
* libscripthook.la
* libscripthook.so

* Create the script called ~/.jpilot/scripthook.sh
* chmod 755 ~/.jpilot/scripthook.sh

Restart JPilot and check to make sure that the plugin is enabled.
Start Jpilot with "-d" (debug mode) and verify if the plugin is running.
Any STDOUT messages in the script will show in debug mode.

`jpilot -d`

## Building from source

If you are interested in building from source, clone the JPilot repository and this repository.
switch to the feature-gtk3 branch for best results. Copy the ScriptHook directory into the repo.

Rerun `autogen.sh` and build with `make`.
The resulting plugin will be built in the `ScriptHook` directory and within `ScriptHook/.libs`
Running `make install` will install the entire JPilot with the ScriptHook plugin.

## Usage

The following arguments are passed to the script during the Hotsync process.
* STARTUP
* PRESYNCPRECONNECT
* PRESYNC
* SYNC
* POSTSYNC
* EXITCLEANUP

These mirrors the sync stages in JPilot as documented in http://www.jpilot.org/documentation/plugin.html.
A simple "scripthook.sh" file is shown below.

```shell
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
```

