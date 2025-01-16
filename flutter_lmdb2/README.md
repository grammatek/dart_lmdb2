# flutter_lmdb2

Flutter bindings for LMDB (Lightning Memory-Mapped Database).  This package is a Flutter wrapper for [dart_lmdb2](https://github.com/grammatek/dart_lmdb2/tree/master/dart_lmdb2) and integrates this package for a Flutter app.

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

## Additional Setup Steps

You need to fetch the native libraries:

```bash
dart run flutter_lmdb2:fetch_native
```

This step should be done every time you fetch a new version of `dart_lmdb2`.

## Example

For a complete working example, check out the Flutter app in the [example/](example/README.md) subdirectory.

## Documentation
For detailed API documentation, please refer to [dart_lmdb2 project](https://pub.dev/packages/dart_lmbd2).

## License
MIT, see [LICENSE](LICENSE)
