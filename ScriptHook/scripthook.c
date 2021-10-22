/*******************************************************************************
 * scripthook.c
 *
 * This is a plugin for J-Pilot which sets the time on the handheld
 * to the current time of the desktop.
 *
 * Copyright (C) 1999-2014 by Judd Montgomery
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 ******************************************************************************/

/********************************* Includes ***********************************/
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <time.h>

#include <pi-dlp.h>
#include <pi-source.h>

#include "libplugin.h"
#include "i18n.h"

/********************************* Constants **********************************/
#define PLUGIN_MAJOR 1
#define PLUGIN_MINOR 0

#define SCRIPT_NAME "/.jpilot/scripthook.sh"

bool PLUGINSCRIPT_OK = false;

/********************************* Constants **********************************/
char* concat(int count, ...) {
    va_list ap;
    int i;

    // Find required length to store merged string
    int len = 1; // room for NULL
    va_start(ap, count);
    for(i=0 ; i<count ; i++)
        len += strlen(va_arg(ap, char*));
    va_end(ap);

    // Allocate memory to concat strings
    char *merged = calloc(sizeof(char),len);
    int null_pos = 0;

    // Actually concatenate strings
    va_start(ap, count);
    for(i=0 ; i<count ; i++)
    {
        char *s = va_arg(ap, char*);
        strcpy(merged+null_pos, s);
        null_pos += strlen(s);
    }
    va_end(ap);

    return merged;
}


/****************************** Main Code *************************************/
void plugin_version(int *major_version, int *minor_version) {
   *major_version = PLUGIN_MAJOR;
   *minor_version = PLUGIN_MINOR;
}

static int static_plugin_get_name(char *name, int len) {
   snprintf(name, len, "ScriptHook %d.%d", PLUGIN_MAJOR, PLUGIN_MINOR);
   return EXIT_SUCCESS;
}

int plugin_get_name(char *name, int len) {
   return static_plugin_get_name(name, len);
}

int plugin_get_help_name(char *name, int len) {
   g_snprintf(name, len, _("About %s"), _("ScriptHook"));
   return EXIT_SUCCESS;
}

int plugin_help(char **text, int *width, int *height) {
   char plugin_name[200];

   static_plugin_get_name(plugin_name, sizeof(plugin_name));
   *text = g_strdup_printf(
      /*-------------------------------------------*/
      _("%s\n"
        "\n"
        "ScriptHook plugin for J-Pilot by\n"
        "Sulph68 (c) 2021.\n"
        "sulph68 at gmail dot com\n"
        "\n"
        "ScriptHook: ~/.jpilot/scripthook.sh\n"
        ),
        plugin_name
      );
   *height = 0;
   *width = 0;

   return EXIT_SUCCESS;
}

int plugin_sync(int sd) {
  unsigned long ROMversion, majorVersion, minorVersion;

  jp_init();
  jp_logf(JP_LOG_GUI, _("ScriptHook: SYNC...\n"));
   
	if (PLUGINSCRIPT_OK == true) {
	 	char *script = concat(3,getenv("HOME"),SCRIPT_NAME," SYNC");
		int status = system(script);
  }
   
  return EXIT_SUCCESS;
}

int plugin_startup(jp_startup_info *info) {
	jp_logf(JP_LOG_INFO, _("ScriptHook: STARTUP\n"));

	// setup script name
	char *script = concat(2,getenv("HOME"),SCRIPT_NAME);
	jp_logf(JP_LOG_INFO, _(script));

	// flag boolean state
	if (access(script, X_OK) == 0) {
		jp_logf(JP_LOG_INFO, _("\nScript file executable\n"));
		PLUGINSCRIPT_OK = true;
	} else {
		jp_logf(JP_LOG_INFO, _("\nScript file don't exist or not executable\n"));
	}

	if (PLUGINSCRIPT_OK == true) {
		char *script = concat(3,getenv("HOME"),SCRIPT_NAME," STARTUP");
		int status = system(script);
  }
	return EXIT_SUCCESS;
}

int plugin_pre_sync_pre_connect(void) {
	jp_logf(JP_LOG_GUI, _("ScriptHook: PRESYNCPRECONNECT\n"));
	if (PLUGINSCRIPT_OK == true) {
		char *script = concat(3,getenv("HOME"),SCRIPT_NAME," PRESYNCPRECONNECT");
		int status = system(script);
  }
	return EXIT_SUCCESS;
}

int plugin_pre_sync(void) {
	jp_logf(JP_LOG_GUI, _("ScriptHook: PRESYNC\n"));
	if (PLUGINSCRIPT_OK == true) {
		char *script = concat(3,getenv("HOME"),SCRIPT_NAME," PRESYNC");
		int status = system(script);
  }
	return EXIT_SUCCESS;
}

int plugin_post_sync(void) {
	jp_logf(JP_LOG_GUI, _("ScriptHook: POSTSYNC\n"));
	if (PLUGINSCRIPT_OK == true) {
		char *script = concat(3,getenv("HOME"),SCRIPT_NAME," POSTSYNC");
		int status = system(script);
  }
	return EXIT_SUCCESS;
}

int plugin_exit_cleanup(void) {
	jp_logf(JP_LOG_INFO, _("ScriptHook: EXITCLEANUP\n"));
	if (PLUGINSCRIPT_OK == true) {
		char *script = concat(3,getenv("HOME"),SCRIPT_NAME," EXITCLEANUP");
		int status = system(script);
  }
	return EXIT_SUCCESS;
}
