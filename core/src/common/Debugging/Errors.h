/*
 * Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
 * Copyright (C) 2005-2009 MaNGOS <http://getmangos.com/>
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

#ifndef LEGIONFORGE_ERRORS_H
#define LEGIONFORGE_ERRORS_H

#include "Define.h"

namespace LegionForge
{
    DECLSPEC_NORETURN LF_COMMON_API void Assert(char const* file, int line, char const* function, char const* message) ATTR_NORETURN;
    DECLSPEC_NORETURN LF_COMMON_API void Assert(char const* file, int line, char const* function, char const* message, char const* format, ...) ATTR_NORETURN ATTR_PRINTF(5, 6);

    DECLSPEC_NORETURN LF_COMMON_API void Fatal(char const* file, int line, char const* function, char const* message, ...) ATTR_NORETURN ATTR_PRINTF(4, 5);

    DECLSPEC_NORETURN LF_COMMON_API void Error(char const* file, int line, char const* function, char const* message) ATTR_NORETURN;

    DECLSPEC_NORETURN LF_COMMON_API void Abort(char const* file, int line, char const* function) ATTR_NORETURN;

    LF_COMMON_API void Warning(char const* file, int line, char const* function, char const* message);

    DECLSPEC_NORETURN LF_COMMON_API void AbortHandler(int sigval) ATTR_NORETURN;

    // Last step on this thread. The crash report prints it. No heap use, so it is safe to call on the way into a fault.
    LF_COMMON_API void SetCrashBreadcrumb(char const* step);
    LF_COMMON_API char const* GetCrashBreadcrumb();

} // namespace LegionForge

#if LEGIONFORGE_COMPILER == LEGIONFORGE_COMPILER_MICROSOFT
#define ASSERT_BEGIN __pragma(warning(push)) __pragma(warning(disable: 4127))
#define ASSERT_END __pragma(warning(pop))
#else
#define ASSERT_BEGIN
#define ASSERT_END
#endif

#define WPAssert(cond, ...) ASSERT_BEGIN do { if (!(cond)) LegionForge::Assert(__FILE__, __LINE__, __FUNCTION__, #cond, ##__VA_ARGS__); } while(0) ASSERT_END
#define WPFatal(cond, ...) ASSERT_BEGIN do { if (!(cond)) LegionForge::Fatal(__FILE__, __LINE__, __FUNCTION__, ##__VA_ARGS__); } while(0) ASSERT_END
#define WPError(cond, msg) ASSERT_BEGIN do { if (!(cond)) LegionForge::Error(__FILE__, __LINE__, __FUNCTION__, (msg)); } while(0) ASSERT_END
#define WPWarning(cond, msg) ASSERT_BEGIN do { if (!(cond)) LegionForge::Warning(__FILE__, __LINE__, __FUNCTION__, (msg)); } while(0) ASSERT_END
#define WPAbort() ASSERT_BEGIN do { LegionForge::Abort(__FILE__, __LINE__, __FUNCTION__); } while(0) ASSERT_END

#define ASSERT WPAssert
#define ABORT WPAbort

template <typename T>
inline T* ASSERT_NOTNULL_IMPL(T* pointer, char const* expr)
{
    ASSERT(pointer, "%s", expr);
    return pointer;
}

#define ASSERT_NOTNULL(pointer) ASSERT_NOTNULL_IMPL(pointer, #pointer)

#endif
