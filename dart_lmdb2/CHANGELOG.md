## 0.9.7

* MacOs: Check at runtime, if we need to dynamically link lmdb or if we are already statically 
         linked.

## 0.9.6

* Add static libraries for native builds. This is to make building Flutter plugins easier.

## 0.9.5

* Adapt loading of shared library on MacOS to support Dart-only and Flutter equally
* Use also `-DMDB_USE_POSIX_SEM` on MacOS

## 0.9.4

* Compile iOS static library with `-DMDB_USE_POSIX_SEM`, otherwise it uses SYS-V semaphores,
  which are not supported
* Support Android 15 16k page size

## 0.9.3

* Add support for Android 64-bit
* Bundle binaries for all supported platforms (unfortunately no web-assembly for FFI-based projects)
* Build all platforms on CI
* Reorganize directory structure for all native libraries

## 0.9.2

* change exported dart file from `dart_lmdb2.dart` => `lmdb.dart`
* change `LMDB2` class name to `LMDB`

## 0.9.1

* Bundle dynamic libraries for all native platforms and load in a sane way
* Build fat (`arm64`, `x86_64`) dylib on MacOS
* `README.md`: fix pub.dev package URL and adapt build matrix
* `pubspec.yml`: fix example section
* Remove unneeded LMDBTxn class
* Fix CI upload of artifacts
* Fix Lint errors for pana

## 0.9.0

* Initial release
* Basic CRUD operations with auto-transactions
* Manual transaction control
* Cursor operations
* Database statistics and analysis
* Configurable initialization
* Documentation and examples
