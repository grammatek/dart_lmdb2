cmake_minimum_required(VERSION 3.13)
project(dart_lmdb2 C)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.29")
    cmake_policy(SET CMP0156 NEW)
endif()
if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.31")
    cmake_policy(SET CMP0179 NEW)
endif()

# Platform detection

if(ANDROID)
    message(STATUS "Configuring for Android")
    set(BUILD_SHARED_LIBS ON)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${ANDROID_ABI})
endif()

if(APPLE AND NOT IOS)
    # MacOS Universal Binary Support
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64")
    message(STATUS "Building Universal Binary for macOS (arm64 + x86_64)")
endif()

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

# Neue Option für beide Bibliothekstypen
if(NOT IOS)
    # Baue sowohl statische als auch dynamische Libs
    option(BUILD_SHARED_LIBS "Build shared libraries" ON)
    option(BUILD_STATIC_LIBS "Build static libraries" ON)
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
if(ANDROID)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
    add_definitions(-DANDROID)
elseif(APPLE)
    if(NOT IOS)
        set(CMAKE_MACOSX_RPATH ON)
        set(CMAKE_INSTALL_RPATH "@executable_path;@loader_path")
        add_definitions(-DMDB_USE_POSIX_SEM)
    else()
        # When building for iOS, LMDB must be compiled with POSIX semaphores instead of
        # System V semaphores
        add_definitions(-DMDB_USE_POSIX_SEM)
    endif()
elseif(UNIX)
    set(CMAKE_INSTALL_RPATH "$ORIGIN")
endif()

# Add LMDB libraries
if(IOS)
    # iOS bleibt unverändert - nur statische Library
    add_library(lmdb STATIC
            src/mdb.c
            src/midl.c
    )
else()
    # Dynamische Library
    add_library(lmdb SHARED
            src/mdb.c
            src/midl.c
    )

    # Zusätzliche statische Library
    add_library(lmdb_static STATIC
            src/mdb.c
            src/midl.c
    )

    # Setze gleichen Output-Namen für statische Library
    set_target_properties(lmdb_static PROPERTIES
            OUTPUT_NAME "lmdb"
            PREFIX "lib"
    )
endif()

# Set include directories for all targets
if(IOS)
    target_include_directories(lmdb PUBLIC
            ${CMAKE_CURRENT_SOURCE_DIR}/src/include
    )
else()
    target_include_directories(lmdb PUBLIC
            ${CMAKE_CURRENT_SOURCE_DIR}/src/include
    )
    target_include_directories(lmdb_static PUBLIC
            ${CMAKE_CURRENT_SOURCE_DIR}/src/include
    )
endif()

# Set library properties
if(IOS)
    set_target_properties(lmdb PROPERTIES
            PUBLIC_HEADER "src/include/lmdb.h;src/include/midl.h"
    )
else()
    set_target_properties(lmdb PROPERTIES
            VERSION 0.9.70
            SOVERSION 0
            PUBLIC_HEADER "src/include/lmdb.h;src/include/midl.h"
    )

    set_target_properties(lmdb_static PROPERTIES
            PUBLIC_HEADER "src/include/lmdb.h;src/include/midl.h"
    )
endif()

if(ANDROID)
    # Support Android 15 16k page size
    target_link_options(lmdb PRIVATE "-Wl,-z,max-page-size=16384")
    if(NOT IOS)
        target_link_options(lmdb_static PRIVATE "-Wl,-z,max-page-size=16384")
    endif()
endif()

if(WIN32)
    set_target_properties(lmdb PROPERTIES
            PREFIX ""
            OUTPUT_NAME "lmdb"
            WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
    set_target_properties(lmdb_static PROPERTIES
            PREFIX ""
            OUTPUT_NAME "lmdb_static"
            WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

if(IOS)
    # Disable BITCODE as it's deprecated
    set_target_properties(lmdb PROPERTIES
            XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
            XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
            XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "12.0"
    )
endif()

# Installation rules
if(NOT IOS)
    include(GNUInstallDirs)
    install(TARGETS lmdb lmdb_static
            RUNTIME DESTINATION ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
            LIBRARY DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
            ARCHIVE DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
            PUBLIC_HEADER DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include
    )
else()
    include(GNUInstallDirs)
    install(TARGETS lmdb
            LIBRARY DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
            PUBLIC_HEADER DESTINATION ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include
    )
endif()