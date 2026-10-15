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

#ifndef __GITREVISION_H__
#define __GITREVISION_H__

#include "Define.h"

namespace GitRevision
{
    LF_COMMON_API char const* GetHash();
    LF_COMMON_API char const* GetDate();
    LF_COMMON_API char const* GetBranch();
    LF_COMMON_API char const* GetCMakeCommand();
    LF_COMMON_API char const* GetCMakeVersion();
    LF_COMMON_API char const* GetHostOSVersion();
    LF_COMMON_API char const* GetBuildDirectory();
    LF_COMMON_API char const* GetSourceDirectory();
    LF_COMMON_API char const* GetMySQLExecutable();
    LF_COMMON_API char const* GetFullDatabase();
    LF_COMMON_API char const* GetHotfixesDatabase();
    LF_COMMON_API char const* GetFullVersion();
    LF_COMMON_API char const* GetCompanyNameStr();
    LF_COMMON_API char const* GetLegalCopyrightStr();
    LF_COMMON_API char const* GetFileVersionStr();
    LF_COMMON_API char const* GetProductVersionStr();
}

#endif
