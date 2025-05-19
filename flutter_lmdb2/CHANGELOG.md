## 0.9.5

* Fix fetch_native to download libraries to flutter_lmdb2 package directory when run from consumer apps
* Use Isolate.resolvePackageUri to reliably find package location

## 0.9.4

* Bump dependency to dart_lmdb2 0.9.11
* Bump dependency to flutter >= 3.29.0 (because of transitive dependencies of dart_lmdb2)

## 0.9.3

* Updated dependency to dart_lmdb2 0.9.8
* Updated path dependency to 1.9.1 for compatibility

## 0.9.2

* Revamp Mac OS build: also use static library for Flutter plugin
* Internal name changes
* Documentation updates

## 0.9.1

* Revamp fetching logic of native libs
* Documentation updates

## 0.9.0

* Initial release of package `flutter_lmdb2`, only meant for testing
* Enable Android, iOS, MacOS
* Documentation and examples