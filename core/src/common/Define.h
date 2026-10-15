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

#ifndef LEGIONFORGE_DEFINE_H
#define LEGIONFORGE_DEFINE_H

#include "CompilerDefs.h"

#if LEGIONFORGE_COMPILER == LEGIONFORGE_COMPILER_GNU
#  if !defined(__STDC_FORMAT_MACROS)
#    define __STDC_FORMAT_MACROS
#  endif
#  if !defined(__STDC_CONSTANT_MACROS)
#    define __STDC_CONSTANT_MACROS
#  endif
#  if !defined(_GLIBCXX_USE_NANOSLEEP)
#    define _GLIBCXX_USE_NANOSLEEP
#  endif
#  if defined(HELGRIND)
#    include <valgrind/helgrind.h>
#    undef _GLIBCXX_SYNCHRONIZATION_HAPPENS_BEFORE
#    undef _GLIBCXX_SYNCHRONIZATION_HAPPENS_AFTER
#    define _GLIBCXX_SYNCHRONIZATION_HAPPENS_BEFORE(A) ANNOTATE_HAPPENS_BEFORE(A)
#    define _GLIBCXX_SYNCHRONIZATION_HAPPENS_AFTER(A)  ANNOTATE_HAPPENS_AFTER(A)
#  endif
#endif

#include <cstddef>
#include <cinttypes>
#include <climits>

#define LEGIONFORGE_LITTLEENDIAN 0
#define LEGIONFORGE_BIGENDIAN    1

#if !defined(LEGIONFORGE_ENDIAN)
#  if defined (BOOST_BIG_ENDIAN)
#    define LEGIONFORGE_ENDIAN LEGIONFORGE_BIGENDIAN
#  else
#    define LEGIONFORGE_ENDIAN LEGIONFORGE_LITTLEENDIAN
#  endif
#endif

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
#  define LEGIONFORGE_PATH_MAX 260
#  define _USE_MATH_DEFINES
#  ifndef DECLSPEC_NORETURN
#    define DECLSPEC_NORETURN __declspec(noreturn)
#  endif //DECLSPEC_NORETURN
#  ifndef DECLSPEC_DEPRECATED
#    define DECLSPEC_DEPRECATED __declspec(deprecated)
#  endif //DECLSPEC_DEPRECATED
#else // LEGIONFORGE_PLATFORM != LEGIONFORGE_PLATFORM_WINDOWS
#  define LEGIONFORGE_PATH_MAX PATH_MAX
#  define DECLSPEC_NORETURN
#  define DECLSPEC_DEPRECATED
#endif // LEGIONFORGE_PLATFORM

#if !defined(COREDEBUG)
#  define LEGIONFORGE_INLINE inline
#else //COREDEBUG
#  if !defined(LEGIONFORGE_DEBUG)
#    define LEGIONFORGE_DEBUG
#  endif //LEGIONFORGE_DEBUG
#  define LEGIONFORGE_INLINE
#endif //!COREDEBUG

#if LEGIONFORGE_COMPILER == LEGIONFORGE_COMPILER_GNU
#  define ATTR_NORETURN __attribute__((__noreturn__))
#  define ATTR_PRINTF(F, V) __attribute__ ((__format__ (__printf__, F, V)))
#  define ATTR_DEPRECATED __attribute__((__deprecated__))
#else //LEGIONFORGE_COMPILER != LEGIONFORGE_COMPILER_GNU
#  define ATTR_NORETURN
#  define ATTR_PRINTF(F, V)
#  define ATTR_DEPRECATED
#endif //LEGIONFORGE_COMPILER == LEGIONFORGE_COMPILER_GNU

#ifdef LEGIONFORGE_API_USE_DYNAMIC_LINKING
#  if LEGIONFORGE_COMPILER == LEGIONFORGE_COMPILER_MICROSOFT
#    define LF_API_EXPORT __declspec(dllexport)
#    define LF_API_IMPORT __declspec(dllimport)
#  elif LEGIONFORGE_COMPILER == LEGIONFORGE_COMPILER_GNU
#    define LF_API_EXPORT __attribute__((visibility("default")))
#    define LF_API_IMPORT
#  else
#    error compiler not supported!
#  endif
#else
#  define LF_API_EXPORT
#  define LF_API_IMPORT
#endif

#ifdef LEGIONFORGE_API_EXPORT_COMMON
#  define LF_COMMON_API LF_API_EXPORT
#else
#  define LF_COMMON_API LF_API_IMPORT
#endif

#ifdef LEGIONFORGE_API_EXPORT_PROTO
#  define LF_PROTO_API LF_API_EXPORT
#else
#  define LF_PROTO_API LF_API_IMPORT
#endif

#ifdef LEGIONFORGE_API_EXPORT_DATABASE
#  define LF_DATABASE_API LF_API_EXPORT
#else
#  define LF_DATABASE_API LF_API_IMPORT
#endif

#ifdef LEGIONFORGE_API_EXPORT_SHARED
#  define LF_SHARED_API LF_API_EXPORT
#else
#  define LF_SHARED_API LF_API_IMPORT
#endif

#ifdef LEGIONFORGE_API_EXPORT_GAME
#  define LF_GAME_API LF_API_EXPORT
#else
#  define LF_GAME_API LF_API_IMPORT
#endif

#define UI64FMTD "%" PRIu64
#define UI64LIT(N) UINT64_C(N)

#define SI64FMTD "%" PRId64
#define SI64LIT(N) INT64_C(N)

#define SZFMTD "%" PRIuPTR

typedef int64_t int64;
typedef int32_t int32;
typedef int16_t int16;
typedef int8_t int8;
typedef uint64_t uint64;
typedef uint32_t uint32;
typedef uint16_t uint16;
typedef uint8_t uint8;

enum DBCFormer
{
    FT_STRING = 's',                                        // LocalizedString*
    FT_STRING_NOT_LOCALIZED = 'S',                          // char*
    FT_FLOAT = 'f',                                         // float
    FT_INT = 'i',                                           // uint32
    FT_BYTE = 'b',                                          // uint8
    FT_SHORT = 'h',                                         // uint16
    FT_LONG = 'l'                                           // uint64
};

#endif //LEGIONFORGE_DEFINE_H
