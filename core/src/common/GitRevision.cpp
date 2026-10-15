/*
 * Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "GitRevision.h"
#include "revision_data.h"

char const* GitRevision::GetHash()
{
    return _HASH;
}

char const* GitRevision::GetDate()
{
    return _DATE;
}

char const* GitRevision::GetBranch()
{
    return _BRANCH;
}

char const* GitRevision::GetCMakeCommand()
{
    return _CMAKE_COMMAND;
}

char const* GitRevision::GetCMakeVersion()
{
    return _CMAKE_VERSION;
}

char const* GitRevision::GetHostOSVersion()
{
    return _CMAKE_HOST_SYSTEM;
}

char const* GitRevision::GetBuildDirectory()
{
    return _BUILD_DIRECTORY;
}

char const* GitRevision::GetSourceDirectory()
{
    return _SOURCE_DIRECTORY;
}

char const* GitRevision::GetMySQLExecutable()
{
    return _MYSQL_EXECUTABLE;
}

char const* GitRevision::GetFullDatabase()
{
    return _FULL_DATABASE;
}

char const* GitRevision::GetHotfixesDatabase()
{
    return _HOTFIXES_DATABASE;
}

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
#  ifdef _WIN64
#    define LEGIONFORGE_PLATFORM_STR "Win64"
#  else
#    define LEGIONFORGE_PLATFORM_STR "Win32"
#  endif
#elif LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_APPLE
#  define LEGIONFORGE_PLATFORM_STR "MacOSX"
#elif LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_INTEL
#  define LEGIONFORGE_PLATFORM_STR "Intel"
#else // LEGIONFORGE_PLATFORM_UNIX
#  define LEGIONFORGE_PLATFORM_STR "Unix"
#endif

#ifndef LEGIONFORGE_API_USE_DYNAMIC_LINKING
#  define LEGIONFORGE_LINKAGE_TYPE_STR "Static"
#else
#  define LEGIONFORGE_LINKAGE_TYPE_STR "Dynamic"
#endif

char const* GitRevision::GetFullVersion()
{
  // e.g. "LEGIONFORGE rev.1 2026-10-09 14:22:31 (Legion 7.3.5.26124, Win64, Release, Static)"
  return "LEGIONFORGE rev." _REVISION " " _DATE
    " (" _BRANCH ", " LEGIONFORGE_PLATFORM_STR ", " _BUILD_DIRECTIVE ", " LEGIONFORGE_LINKAGE_TYPE_STR ")";
}

char const* GitRevision::GetCompanyNameStr()
{
    return VER_COMPANYNAME_STR;
}

char const* GitRevision::GetLegalCopyrightStr()
{
    return VER_LEGALCOPYRIGHT_STR;
}

char const* GitRevision::GetFileVersionStr()
{
    return VER_FILEVERSION_STR;
}

char const* GitRevision::GetProductVersionStr()
{
    return VER_PRODUCTVERSION_STR;
}
