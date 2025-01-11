cmake_minimum_required(VERSION 3.10)
project(dart_lmdb2 C)

# Platform detection
if(IOS)
    message(STATUS "Configuring for iOS")
    set(CMAKE_SYSTEM_NAME iOS)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0")
    set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)

    # Force static library for iOS
    set(BUILD_SHARED_LIBS OFF)

    # Set output directories for iOS
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
endif()

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
    if(NOT IOS)
        set(CMAKE_MACOSX_RPATH ON)
        set(CMAKE_INSTALL_RPATH "@executable_path;@loader_path")
    endif()
elseif(UNIX)
    set(CMAKE_INSTALL_RPATH "$ORIGIN")
endif()

# Add LMDB library
if(IOS)
    add_library(lmdb STATIC
        src/mdb.c
        src/midl.c
    )
else()
    add_library(lmdb SHARED
        src/mdb.c
        src/midl.c
    )
endif()

target_include_directories(lmdb PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/include
)

# Set library properties
set_target_properties(lmdb PROPERTIES
    VERSION 0.9.70
    SOVERSION 0
    PUBLIC_HEADER "src/include/lmdb.h;src/include/midl.h"
)

if(NOT IOS)
    set_target_properties(lmdb PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

if(WIN32)
    set_target_properties(lmdb PROPERTIES
        PREFIX ""
        OUTPUT_NAME "lmdb"
    )
endif()

# Installation rules
if(NOT IOS)
    include(GNUInstallDirs)
    install(TARGETS lmdb
        LIBRARY DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
        PUBLIC_HEADER DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include
    )
endif()

# iOS specific configurations
if(IOS)
    # Disable BITCODE as it's deprecated
    set_target_properties(lmdb PROPERTIES
        XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
        XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
    )

    # Set deployment target
    set_target_properties(lmdb PROPERTIES
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "12.0"
    )
endif()