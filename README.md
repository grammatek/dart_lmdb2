# dart_lmdb2

A modern Dart wrapper for LMDB (Lightning Memory-Mapped Database), providing both high-level convenience methods and low-level transaction control.

## Features

* Partial LMDB functionality through Dart FFI
* Both automatic and manual transaction control
* Proper resource management
* Configurable database settings
* Statistics and analysis
* Native performance

## Getting Started

Add the package to your `pubspec.yaml`:
```yaml
dependencies:
  dart_lmdb2: ^1.0.0
```

## Usage

Import and use:

```dart
import 'package:dart_lmdb2/dart_lmdb2.dart';

void main() async {
    final db = LMDB2();
    await db.init('path/to/db');

    // Simple auto-transaction operations
    await db.putAuto('key', 'value'.codeUnits);
    final result = await db.getAuto('key');

    // Manual transaction control
    final txn = await db.txnStart();
    try {
        await db.put(txn, 'key1', 'value1'.codeUnits);
        await db.put(txn, 'key2', 'value2'.codeUnits);
        await db.txnCommit(txn);
    } catch (e) {
        await db.txnAbort(txn);
        rethrow;
    }
}
```

Configure database settings using `LMDBInitConfig`:

```dart
final config = LMDBInitConfig(
  mapSize: 10 * 1024 * 1024,  // 10MB
  maxDbs: 1,
  envFlags: 0,
  mode: 0664,
);

await db.init('path/to/db', config: config);
```

## Installation

### Prerequisites

This package requires LMDB to be built from source. The build process is automated but requires:

- CMake (3.10 or higher)
- C compiler (gcc, clang, or MSVC)
- Dart SDK (3.0 or higher)

### Platform-specific setup

#### Linux

```bash
# Install build tools
sudo apt-get install build-essential cmake
```

#### MacOS

```bash
# Install build tools
brew install cmake
```

#### Windows

- Install Visual Studio with C++ development tools
- Install CMake


## Development Setup

If you're developing this package:

1. Clone the repository:
```bash
git clone https://github.com/grammatek/dart_lmdb2.git
````

2. Install dependencies:
```bash
dart pub get
```

3. Build the native library:
```bash
dart run tool/build.dart
```

4. Run tests:
```bash
dart test
```

## LICENSE

MIT License - see LICENSE file
