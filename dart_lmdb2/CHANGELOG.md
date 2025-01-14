## 0.9.3

* Add support for Android 64-bit
* Bundle binaries for all supported platforms (unfortunately no web-assembly)
* Build all platforms on CI
* Reorganize directory structure for all native libraries

## 0.9.2

* change exported dart file from dart_lmdb2.dart => lmdb.dart
* change LMDB2 class name to LMDB

## 0.9.1

* Bundle dynamic libraries for all native platforms and load in a sane way
* Build fat (arm64, x86_64) dylib on MacOS
* README.md: fix pub.dev package URL and adapt build matrix
* pubsepc.yml: fix example section
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
