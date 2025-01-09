cmake_minimum_required(VERSION 3.10)
project(dart_lmdb2 C)

# Set output directories explicitly for all configurations
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/lib)

if(WIN32)
  # Ensure DLLs go to the same directory on Windows
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
endif()

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Platform specific settings
if(APPLE)
  set(CMAKE_MACOSX_RPATH ON)
  set(CMAKE_INSTALL_RPATH "@executable_path;@loader_path")
elseif(UNIX)
  set(CMAKE_INSTALL_RPATH "$ORIGIN")
endif()

# Add LMDB library
add_library(lmdb SHARED
  src/mdb.c
  src/midl.c
)

target_include_directories(lmdb PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/src/include
)

# Set library properties
set_target_properties(lmdb PROPERTIES
  VERSION 0.9.70
  SOVERSION 0
  PUBLIC_HEADER "src/include/lmdb.h;src/include/midl.h"
  WINDOWS_EXPORT_ALL_SYMBOLS ON
)

if(WIN32)
  set_target_properties(lmdb PROPERTIES
    PREFIX ""
    OUTPUT_NAME "lmdb"
  )
endif()

# Installation rules
include(GNUInstallDirs)
install(TARGETS lmdb
  LIBRARY DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
  PUBLIC_HEADER DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include
)