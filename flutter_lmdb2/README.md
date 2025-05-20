# flutter_lmdb2

Flutter bindings for LMDB (Lightning Memory-Mapped Database).  This package is a Flutter wrapper for [dart_lmdb2](https://github.com/grammatek/dart_lmdb2/tree/master/dart_lmdb2) and integrates this package for a Flutter app.

[![Pub Version](https://img.shields.io/pub/v/flutter_lmdb2?logo=dart)](https://pub.dev/packages/flutter_lmdb2)

| Linux | Windows | Android | MacOS | iOS | web |
|:-----:|:-------:|:-------:|:-----:|:---:|:---:|
| soon  |  soon   |   💙    |  💙   | 💙  |  -  |

## Features
- Native LMDB integration for Flutter
- Complete [dart_lmdb2](https://pub.dev/packages/dart_lmdb2) API available inside Flutter applications

## Installation
```yaml
dependencies:
  flutter_lmdb2: ^0.9.5
```

## Additional Setup Steps

You need to fetch the native libraries:

```bash
dart run flutter_lmdb2:fetch_native
```

**This step should be done every time you fetch a new version of `dart_lmdb2`.**

### iOS Architecture Support

For iOS development, the package provides separate libraries for:
- Physical iOS devices (arm64)
- iOS simulators (x86_64)

These are automatically selected based on your build target, ensuring compatibility with both:
- Simulators on Intel Macs
- Simulators on Apple Silicon Macs (M1/M2/M3/M4)
- Physical iOS devices

## Example

For a complete working example, check out the Flutter app in the [example/](example/README.md) subdirectory.

## Documentation
For detailed API documentation, please refer to [dart_lmdb2 project](https://pub.dev/documentation/dart_lmdb2/latest/).

## License
MIT, see [LICENSE](LICENSE)
