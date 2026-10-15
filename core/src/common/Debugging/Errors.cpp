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

#include "Errors.h"

#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <cstdarg>

/**
    @file Errors.cpp

    @brief This file contains definitions of functions used for reporting critical application errors

    It is very important that (std::)abort is NEVER called in place of *((volatile int*)NULL) = 0;
    Calling abort() on Windows does not invoke unhandled exception filters - a mechanism used by WheatyExceptionReport
    to log crashes. exit(1) calls here are for static analysis tools to indicate that calling functions defined in this file
    terminates the application.
 */

namespace LegionForge {

static thread_local char s_crashBreadcrumb[512] = "none";

void SetCrashBreadcrumb(char const* step)
{
    if (!step || !step[0])
        step = "none";

    size_t i = 0;
    for (; i + 1 < sizeof(s_crashBreadcrumb) && step[i]; ++i)
        s_crashBreadcrumb[i] = step[i];
    s_crashBreadcrumb[i] = '\0';
}

char const* GetCrashBreadcrumb()
{
    return s_crashBreadcrumb;
}

void Assert(char const* file, int line, char const* function, char const* message)
{
    fprintf(stderr, "\n%s:%i in %s ASSERTION FAILED:\n  %s\n  breadcrumb: %s\n",
            file, line, function, message, s_crashBreadcrumb);
    fflush(stderr);
    // [LEGIONFORGE] WheatyExceptionReport writes the crash .txt but NOT stderr, so an ASSERT
    // used to look like a bare "C0000005 ACCESS_VIOLATION / Last breadcrumb: none" and the real
    // reason was lost. Record the assert text as the breadcrumb before the deliberate fault.
    // Stack buffer only - no heap allocation on the way into a fault.
    char assertBreadcrumb[sizeof(s_crashBreadcrumb)];
    snprintf(assertBreadcrumb, sizeof(assertBreadcrumb), "ASSERT %s:%d in %s: %s", file, line, function, message);
    SetCrashBreadcrumb(assertBreadcrumb);
    *((volatile int*)NULL) = 0;
    exit(1);
}

void Assert(char const* file, int line, char const* function, char const* message, char const* format, ...)
{
    va_list args;
    va_start(args, format);

    fprintf(stderr, "\n%s:%i in %s ASSERTION FAILED:\n  %s ", file, line, function, message);
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n  breadcrumb: %s\n", s_crashBreadcrumb);
    fflush(stderr);

    // [LEGIONFORGE] Keep the full formatted assert text for the crash report as well.
    char assertBreadcrumb[sizeof(s_crashBreadcrumb)];
    int written = snprintf(assertBreadcrumb, sizeof(assertBreadcrumb), "ASSERT %s:%d in %s: %s ", file, line, function, message);
    if (written > 0 && static_cast<std::size_t>(written) < sizeof(assertBreadcrumb))
    {
        va_list argsCopy;
        va_start(argsCopy, format);
        vsnprintf(assertBreadcrumb + written, sizeof(assertBreadcrumb) - static_cast<std::size_t>(written), format, argsCopy);
        va_end(argsCopy);
    }
    SetCrashBreadcrumb(assertBreadcrumb);

    va_end(args);
    *((volatile int*)NULL) = 0;
    exit(1);
}

void Fatal(char const* file, int line, char const* function, char const* message, ...)
{
    va_list args;
    va_start(args, message);

    fprintf(stderr, "\n%s:%i in %s FATAL ERROR:\n  ", file, line, function);
    vfprintf(stderr, message, args);
    fprintf(stderr, "\n");
    fflush(stderr);

    // [LEGIONFORGE] Make the fatal reason visible in the crash report too.
    char fatalBreadcrumb[sizeof(s_crashBreadcrumb)];
    int written = snprintf(fatalBreadcrumb, sizeof(fatalBreadcrumb), "FATAL %s:%d in %s: ", file, line, function);
    if (written > 0 && static_cast<std::size_t>(written) < sizeof(fatalBreadcrumb))
    {
        va_list argsCopy;
        va_start(argsCopy, message);
        vsnprintf(fatalBreadcrumb + written, sizeof(fatalBreadcrumb) - static_cast<std::size_t>(written), message, argsCopy);
        va_end(argsCopy);
    }
    SetCrashBreadcrumb(fatalBreadcrumb);

    std::this_thread::sleep_for(std::chrono::seconds(10));
    *((volatile int*)NULL) = 0;
    exit(1);
}

void Error(char const* file, int line, char const* function, char const* message)
{
    fprintf(stderr, "\n%s:%i in %s ERROR:\n  %s\n",
                   file, line, function, message);
    fflush(stderr);
    char errorBreadcrumb[sizeof(s_crashBreadcrumb)];
    snprintf(errorBreadcrumb, sizeof(errorBreadcrumb), "ERROR %s:%d in %s: %s", file, line, function, message);
    SetCrashBreadcrumb(errorBreadcrumb);
    *((volatile int*)NULL) = 0;
    exit(1);
}

void Warning(char const* file, int line, char const* function, char const* message)
{
    fprintf(stderr, "\n%s:%i in %s WARNING:\n  %s\n",
                   file, line, function, message);
}

void Abort(char const* file, int line, char const* function)
{
    fprintf(stderr, "\n%s:%i in %s ABORTED.\n",
                   file, line, function);
    fflush(stderr);
    char abortBreadcrumb[sizeof(s_crashBreadcrumb)];
    snprintf(abortBreadcrumb, sizeof(abortBreadcrumb), "ABORT %s:%d in %s", file, line, function);
    SetCrashBreadcrumb(abortBreadcrumb);
    *((volatile int*)NULL) = 0;
    exit(1);
}

void AbortHandler(int /*sigval*/)
{
    // nothing useful to log here, no way to pass args
    *((volatile int*)NULL) = 0;
    exit(1);
}

} // namespace LegionForge
