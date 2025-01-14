# flutter_lmdb2

Flutter bindings for LMDB (Lightning Memory-Mapped Database). 
This package is a Flutter wrapper for [dart_lmdb2](https://github.com/grammatek/dart_lmdb2/tree/master/dart_lmdb2).

[![Pub Version](https://img.shields.io/pub/v/flutter_lmbd2?logo=dart)](https://pub.dev/packages/flutter_lmbd2)

|Linux|Windows|Android|MacOS|iOS|web|
|:-:|:-:|:-:|:-:|:-:|:-:|
|💙|💙|soon|💙|💙|-|

## Features
- Native LMDB integration for Flutter
- Complete [dart_lmdb2](https://pub.dev/packages/dart_lmbd2) API available in Flutter applications

## Installation
```yaml
dependencies:
  flutter_lmdb2: ^0.9

```
## Important Build Notes

### iOS
When building for iOS, LMDB must be compiled with POSIX semaphores instead of System V semaphores. This is handled automatically in the build process through the CMake configuration:

```cmake
add_definitions(-DMDB_USE_POSIX_SEM)
```

Without this definition, the app will crash with a SIGSYS signal when trying to use System V semaphores, which are not supported in the iOS sandbox.

## Additional Setup Steps
### Android
- Minimum SDK version
- Required permissions

### iOS
- Podfile adjustments
- Minimum iOS version

## Example
```dart
// Minimal example

```
For a complete working example, check out the [example app](example/README.md) in this repository.


## Documentation
For detailed API documentation, please refer to the [dart_lmdb2 project](link).

## Differences from dart_lmdb2
- Platform-specific considerations
- Flutter-specific APIs

## License
MIT, see [LICENSE](../LICENSE)
