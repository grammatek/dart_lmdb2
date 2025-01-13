# flutter_lmdb2

LMDB (Lightning Memory-Mapped Database) implementation for Flutter.

## Important Build Notes

### iOS
When building for iOS, LMDB must be compiled with POSIX semaphores instead of System V semaphores. 
This is handled automatically in the build process through the CMake configuration:

```cmake
add_definitions(-DMDB_USE_POSIX_SEM)
```

Without this definition, the app will crash with a SIGSYS signal when trying to use System V semaphores,
which are not available in the iOS sandbox.

## Usage
...
