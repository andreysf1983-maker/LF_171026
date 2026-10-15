# Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
#
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


# basic packagesearching and setup
# (further support will be needed, this is a preliminary release!)
set(OPENSSL_EXPECTED_VERSION 1.0.0)

# Pre-set version to bypass multi-line OPENSSL_VERSION_NUMBER parsing (OpenSSL 3.x)
if(NOT _OPENSSL_VERSION)
  set(_OPENSSL_VERSION "3.0.0")
endif()

# OpenSSL 3.x: try find_package first; if it fails (e.g. non-standard install
# layout on Windows with VC libs), fall back to manual path detection.
# You can override OPENSSL_ROOT_DIR on the CMake command line:
#   cmake -DOPENSSL_ROOT_DIR="C:/Program Files/OpenSSL-Win64" ...
if(NOT OPENSSL_ROOT_DIR AND WIN32)
  # Default Windows installer path for Win64 OpenSSL from slproweb.com
  set(OPENSSL_ROOT_DIR "C:/Program Files/OpenSSL-Win64" CACHE PATH "OpenSSL root directory")
endif()

find_package(OpenSSL QUIET)

if(NOT OPENSSL_FOUND)
  # find_package failed — manually resolve VC-layout lib paths
  if(NOT OPENSSL_ROOT_DIR)
    message(FATAL_ERROR "OpenSSL not found. Set OPENSSL_ROOT_DIR to your OpenSSL install path.")
  endif()
  set(OPENSSL_INCLUDE_DIR "${OPENSSL_ROOT_DIR}/include" CACHE PATH "" FORCE)
  set(OPENSSL_SSL_LIBRARY "${OPENSSL_ROOT_DIR}/lib/VC/x64/MD/libssl.lib" CACHE FILEPATH "" FORCE)
  set(OPENSSL_CRYPTO_LIBRARY "${OPENSSL_ROOT_DIR}/lib/VC/x64/MD/libcrypto.lib" CACHE FILEPATH "" FORCE)
  set(OPENSSL_LIBRARIES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_CRYPTO_LIBRARY})
  set(OPENSSL_FOUND TRUE CACHE BOOL "" FORCE)
  message(STATUS "OpenSSL manually configured from: ${OPENSSL_ROOT_DIR}")
else()
  message(STATUS "OpenSSL found by find_package: ${OPENSSL_VERSION}")
endif()

add_library(openssl INTERFACE)

target_link_libraries(openssl
  INTERFACE
    ${OPENSSL_LIBRARIES}
    $<$<BOOL:${WIN32}>:crypt32>
    $<$<BOOL:${WIN32}>:ws2_32>)

target_include_directories(openssl
  INTERFACE
    ${OPENSSL_INCLUDE_DIR})
