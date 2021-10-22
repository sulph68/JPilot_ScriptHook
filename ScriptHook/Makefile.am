libdir = @libdir@/@PACKAGE@/plugins

if MAKE_SAMPLE

lib_LTLIBRARIES = libscripthook.la
libscripthook_la_SOURCES = scripthook.c
libscripthook_la_CFLAGS = @PILOT_FLAGS@ @GTK_CFLAGS@ -I$(top_srcdir)
libscripthook_la_LDFLAGS = -module -avoid-version
libscripthook_la_LIBADD = @GTK_LIBS@

endif
