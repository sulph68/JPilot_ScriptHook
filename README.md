# JPilot_ScriptHook
JPilot Plugin to run scripts at every stage of the JPilot sync process.
This is based off the sample plugins available at https://github.com/juddmon/jpilot/tree/feature-gtk3.
Its been tested to work successfully on Jpilot version 2.0.1.

It runs a script located within `~/.jpilot/scripthook.sh` which can be edited to execute
any script necessary. This script must be executable for the plugin to run successfully.

## Installation

Download the plugin files, from release, untar and copy them into the JPilot directory `~/.jpilot/plugins`.
* libscripthook.la
* libscripthook.so

```shell
tar jxvf libscripthook.tar.bz2
mkdir ~/.jpilot/plugins
cp libscripthook.la libscriptook.so ~/.jpilot/plugins/
```

* Create the script called ~/.jpilot/scripthook.sh
* `chmod 755 ~/.jpilot/scripthook.sh`

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
A simple `scripthook.sh` file is provided in the scripts directory.

## Sample Usage

A few sample scripts are provided. These might require a little editing to suit your purpose, but they work well enough for mine.
* scripthook.sh - The initial script that the plugin calls

### Importing and Exporting ToDo from JPilot to CSV

These export the ToDos as read in JPilot into CSV files. It includes the PDB as well as JPilot's PC3 records.
* jexport_todo_csv.pl - Export ToDo records into CSV, including all unsynced changes
* jimport_todo_csv.pl - Imports CSV records into JPilot, with changes written into PC3 format for sync

Credit must be given to the author of the [Palm PERL package](https://github.com/madsen/Palm-PDB).
The [JPilot Plugin Documentation](http://www.jpilot.org/documentation/plugin.html) is also immensely helpful in getting the PC3 integration right. 

### Todoist Integration

These import/export scripts works with ToDoist and generates CSV files in the JPilot CSV format. These are meant to work with the sample jpilot import/export scripts.
When used together with `scripthook.sh`, it provides seamless import and export of records between Palm and [Todoist](https://todoist.com/).

* todoist_export.py - script to export entries into CSV
* todoist_import.py - script to import into Todoist

Take note that the scripts will add an extra note into the ToDo record in order to provide the Todoist item ID.
It does not cover all usage cases but it works well enough for me. Some simple editing might be required for it to work for you. This includes _getting an access token from Todoist_.

The [Todoist Python API](https://developer.todoist.com/sync) was used as a reference.
The [todoist-export](https://github.com/darekkay/todoist-export) project also served as the initial inspiration to make this happen.

*Note* There is a small function that maps category IDs in PDB to strings. You will need to check the ID mapping on your Palm for it to match correctly.


### Sample scripthook.sh

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

