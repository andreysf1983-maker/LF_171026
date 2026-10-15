# set up output paths for executable binaries (.exe-files, and .dll-files on DLL-capable platforms)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(MSVC_EXPECTED_VERSION 19.10)
set(MSVC_EXPECTED_VERSION_STRING "MSVC 2017")

if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS MSVC_EXPECTED_VERSION)
  message(FATAL_ERROR "MSVC: LEGIONFORGE requires version ${MSVC_EXPECTED_VERSION} (${MSVC_EXPECTED_VERSION_STRING}) to build but found ${CMAKE_CXX_COMPILER_VERSION}")
endif()

# CMake sets warning flags by default, however we manage it manually
# for different core and dependency targets
string(REGEX REPLACE "/W[0-4] " "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
# Search twice, once for space after /W argument,
# once for end of line as CMake regex has no \b
string(REGEX REPLACE "/W[0-4]$" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
string(REGEX REPLACE "/W[0-4] " "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
string(REGEX REPLACE "/W[0-4]$" "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")

# [LEGIONFORGE] Generate PDB symbols for Release builds. Without this a crash report
# (WheatyExceptionReport) prints raw "0001:OFFSET" addresses with no function names,
# which is exactly what happened with the 2026-10-10 ACCESS_VIOLATION dump.
# /Zi writes debug info to a PDB at compile time; /DEBUG makes the linker emit
# worldserver.pdb; /OPT:REF,ICF keep the Release size/speed optimizations that
# /DEBUG would otherwise disable. build_server.ps1 already copies *.pdb to server\.
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /Zi")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Zi")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /DEBUG /OPT:REF /OPT:ICF")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /DEBUG /OPT:REF /OPT:ICF")

target_compile_options(trinity-warning-interface
  INTERFACE
    /W3)

# set up output paths ofr static libraries etc (commented out - shown here as an example only)
#set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
#set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

if(PLATFORM EQUAL 64)
  # This definition is necessary to work around a bug with Intellisense described
  # here: http://tinyurl.com/2cb428.  Syntax highlighting is important for proper
  # debugger functionality.
  target_compile_definitions(trinity-compile-option-interface
    INTERFACE
      -D_WIN64)

  message(STATUS "MSVC: 64-bit platform, enforced -D_WIN64 parameter")

else()
  # mark 32 bit executables large address aware so they can use > 2GB address space
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /LARGEADDRESSAWARE")
  message(STATUS "MSVC: Enabled large address awareness")

  target_compile_options(trinity-compile-option-interface
    INTERFACE
      /arch:SSE2)
  message(STATUS "MSVC: Enabled SSE2 support")

  set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /SAFESEH:NO")
  message(STATUS "MSVC: Disabled Safe Exception Handlers for debug builds")
endif()

# Set build-directive (used in core to tell which buildtype we used)
# msbuild/devenv don't set CMAKE_MAKE_PROGRAM, you can choose build type from a dropdown after generating projects
if("${CMAKE_MAKE_PROGRAM}" MATCHES "MSBuild")
  target_compile_definitions(trinity-compile-option-interface
    INTERFACE
      -D_BUILD_DIRECTIVE="$(ConfigurationName)")
else()
  # while all make-like generators do (nmake, ninja)
  target_compile_definitions(trinity-compile-option-interface
    INTERFACE
      -D_BUILD_DIRECTIVE="${CMAKE_BUILD_TYPE}")
endif()

# multithreaded compiling on VS
target_compile_options(trinity-compile-option-interface
  INTERFACE
    /MP)

if((PLATFORM EQUAL 64) OR (NOT CMAKE_CXX_COMPILER_VERSION VERSION_LESS 19.0.23026.0) OR BUILD_SHARED_LIBS)
  # Enable extended object support
  target_compile_options(trinity-compile-option-interface
    INTERFACE
      /bigobj)

  message(STATUS "MSVC: Enabled increased number of sections in object files")
endif()

# /Zc:throwingNew.
# When you specify Zc:throwingNew on the command line, it instructs the compiler to assume
# that the program will eventually be linked with a conforming operator new implementation,
# and can omit all of these extra null checks from your program.
# http://blogs.msdn.com/b/vcblog/archive/2015/08/06/new-in-vs-2015-zc-throwingnew.aspx
if(NOT (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 19.0.23026.0))
  # makes this flag a requirement to build TC at all
  target_compile_options(trinity-compile-option-interface
    INTERFACE
      /Zc:throwingNew)
endif()

# [LEGIONFORGE FIX 2026-10]
# Boost >= 1.81 does `using std::snprintf;` inside boost/system/detail/snprintf.hpp.
# The build used to die with
#   error C2039: '_snprintf': is not a member of 'std'
#   error C2873: '_snprintf': symbol cannot be used in a using-declaration
# The previous note blamed MSVC's secure-overload macros - that diagnosis was wrong.
# The real culprit was `#define snprintf _snprintf` in src/common/Common.h (now guarded
# behind _MSC_VER < 1900). The definitions below are still useful, so they stay, and we
# additionally hard-disable the legacy aliases for every translation unit.
target_compile_definitions(trinity-compile-option-interface
  INTERFACE
    -D_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES=0
    -D_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_COUNT=0
    -D_CRT_SECURE_NO_WARNINGS)
message(STATUS "MSVC: Disabled NON-SECURE warnings")

# Keep legacy TR1/C++98 helpers (std::unary_function, std::binary_function,
# std::random_shuffle) alive: ~20 script files and G3D still use them and MSVC removes
# them as soon as the effective standard is C++17 or newer.
target_compile_definitions(trinity-compile-option-interface
  INTERFACE
    -D_HAS_AUTO_PTR_ETC=1
    -D_SILENCE_CXX17_ADAPTOR_TYPEDEFS_DEPRECATION_WARNING
    -D_SILENCE_CXX17_RESULT_OF_DEPRECATION_WARNING
    -D_SILENCE_CXX17_OLD_ALLOCATOR_MEMBERS_DEPRECATION_WARNING
    -D_SILENCE_ALL_CXX17_DEPRECATION_WARNINGS
    -D_SILENCE_ALL_CXX20_DEPRECATION_WARNINGS
    -D_SILENCE_CXX20_CISO646_REMOVED_WARNING
    -DNOMINMAX
    -DWIN32_LEAN_AND_MEAN)
message(STATUS "MSVC: Enabled legacy STL helpers (_HAS_AUTO_PTR_ETC) + NOMINMAX")

# The core is written against C++14. Visual Studio 2022 17.14 still defaults to
# /std:c++14, but pin it so a future toolchain default (C++17/20) cannot silently
# delete std::unary_function & friends from under the scripts.
if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14 CACHE STRING "C++ standard used to build LEGIONFORGE" FORCE)
  set(CMAKE_CXX_STANDARD_REQUIRED ON CACHE BOOL "" FORCE)
  set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL "" FORCE)
endif()
message(STATUS "MSVC: C++ standard pinned to C++${CMAKE_CXX_STANDARD}")

# Ignore warnings about POSIX deprecation
target_compile_definitions(trinity-compile-option-interface
  INTERFACE
    -D_CRT_NONSTDC_NO_WARNINGS
    -D_CRT_NONSTDC_NO_DEPRECATE)

message(STATUS "MSVC: Disabled POSIX warnings")

# Ignore specific warnings
# C4351: new behavior: elements of array 'x' will be default initialized
# C4091: 'typedef ': ignored on left of '' when no variable is declared
target_compile_options(trinity-compile-option-interface
  INTERFACE
    /wd4351
    /wd4091)

if(NOT WITH_WARNINGS)
  target_compile_options(trinity-compile-option-interface
    INTERFACE
      /wd4996
      /wd4355
      /wd4244
      /wd4985
      /wd4267
      /wd4619
      /wd4512)

  message(STATUS "MSVC: Disabled generic compiletime warnings")
endif()

if (BUILD_SHARED_LIBS)
  # C4251: needs to have dll-interface to be used by clients of class '...'
  # C4275: non dll-interface class ...' used as base for dll-interface class '...'
  target_compile_options(trinity-compile-option-interface
    INTERFACE
      /wd4251
      /wd4275)

  message(STATUS "MSVC: Enabled shared linking")
endif()

# Enable and treat as errors the following warnings to easily detect virtual function signature failures:
# 'function' : member function does not override any base class virtual member function
# 'virtual_function' : no override available for virtual member function from base 'class'; function is hidden
target_compile_options(trinity-compile-option-interface
  INTERFACE
    /we4263
    /we4264)

# Disable incremental linking in debug builds.
# To prevent linking getting stuck (which might be fixed in a later VS version).
macro(DisableIncrementalLinking variable)
  string(REGEX REPLACE "/INCREMENTAL *" "" ${variable} "${${variable}}")
  set(${variable} "${${variable}} /INCREMENTAL:NO")
endmacro()

DisableIncrementalLinking(CMAKE_EXE_LINKER_FLAGS_DEBUG)
DisableIncrementalLinking(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO)
DisableIncrementalLinking(CMAKE_SHARED_LINKER_FLAGS_DEBUG)
DisableIncrementalLinking(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO)
