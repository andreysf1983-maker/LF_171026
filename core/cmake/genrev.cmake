# Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
#
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# LegionForge revision generator.
#
# Produces the version string shown in the console banner, e.g.
#     LEGIONFORGE rev.1 2026-10-09 14:22:31 (Legion 7.3.5.26124, Win64, Release, Static)
#
# * The revision number is read from core/revision.txt (bump it by hand for every release).
#   It can be overridden with -DLEGIONFORGE_REVISION=<n>.
# * The date/time is the real local build time (the old generator printed
#   "unknown 1970-01-01 00:00:00 +0000" because the pack is built with -DWITHOUT_GIT=1 and
#   the build-time target never received GIT_EXECUTABLE at all).
# * If git is available the short commit hash is kept in _COMMIT for crash reports.
#
# This script runs twice: at configure time (include from CMakeLists.txt) and at every
# build through the "revision_data.h" target (cmake -P), which is why every input
# is passed explicitly on the command line from src/genrev/CMakeLists.txt.

if(NOT BUILDDIR)
  # Workaround for funny MSVC behaviour - this segment is only used when using cmake gui
  set(BUILDDIR ${CMAKE_BINARY_DIR})
endif()

# ---------------------------------------------------------------- revision number
set(rev_number "${LEGIONFORGE_REVISION}")
if(NOT rev_number AND EXISTS "${CMAKE_SOURCE_DIR}/revision.txt")
  file(STRINGS "${CMAKE_SOURCE_DIR}/revision.txt" rev_number LIMIT_COUNT 1)
  string(STRIP "${rev_number}" rev_number)
endif()
if(NOT rev_number MATCHES "^[0-9]+$")
  set(rev_number 1)
endif()

# ---------------------------------------------------------------- build date / time
string(TIMESTAMP rev_date "%Y-%m-%d %H:%M:%S")

# ---------------------------------------------------------------- client build
set(rev_branch "Legion 7.3.5.26124")

# ---------------------------------------------------------------- optional git hash
set(rev_commit "")
if(NOT WITHOUT_GIT AND GIT_EXECUTABLE AND EXISTS "${CMAKE_SOURCE_DIR}/../.git")
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" rev-parse --short=12 HEAD
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE rev_commit
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
endif()
if(NOT rev_commit)
  set(rev_commit "local")
endif()

# _HASH is used for crash dump names and the script hot-reload check, keep it short.
set(rev_hash "rev.${rev_number}")

# ---------------------------------------------------------------- source directory
# sql\ lives in the repository root (one level above core\). The DB updater resolves "$"
# in updates_include against this directory.
set(LF_SOURCE_ROOT "${CMAKE_SOURCE_DIR}")
if(NOT EXISTS "${CMAKE_SOURCE_DIR}/sql" AND EXISTS "${CMAKE_SOURCE_DIR}/../sql")
  get_filename_component(LF_SOURCE_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)
endif()

if(NOT MYSQL_EXECUTABLE)
  set(MYSQL_EXECUTABLE "")
endif()

# configure_file only rewrites revision_data.h when its content really changed.
configure_file(
  "${CMAKE_SOURCE_DIR}/revision_data.h.in.cmake"
  "${BUILDDIR}/revision_data.h"
  @ONLY
)
