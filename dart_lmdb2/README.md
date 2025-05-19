# dart_lmdb2

A high-performance, embedded database for Dart applications, wrapping LMDB (Lightning Memory-Mapped Database). This package provides both high-level convenience methods and granular transaction control.

[![Pub Version](https://img.shields.io/pub/v/dart_lmdb2?logo=dart)](https://pub.dev/packages/dart_lmdb2)

|Linux|Windows|Android|MacOS|iOS|web|
|:-:|:-:|:-:|:-:|:-:|:-:|
|💙|💙|💙|💙|💙|-|

---

**Note: Native binaries for all platforms are automatically downloaded on first use. For iOS/Android you need Flutter to run them on your mobile device. See [flutter_lmdb2](https://pub.dev/packages/flutter_lmdb2)**

## Why LMDB?

LMDB is particularly well-suited for mobile and embedded applications because:

- Mobile-Friendly Design:
  - Database format is portable across all platforms
  - Battery-efficient through memory mapping and minimal I/O operations
  - No background processes or services required
  - Predictable memory usage through configurable mapping size
  - Instant app startup with lazy data loading

- Minimal Resource Requirements:
  - Ultra-compact native library (<150KB)
  - Configurable DB ceiling with fixed mapSize limit
  - Single-threaded design with minimal process overhead
  - No additional runtime dependencies

- Exceptional Performance:
  - Zero-copy reads through direct memory mapping
  - Efficient OS-level page caching eliminates I/O bottlenecks
  - Optimized for read operations through direct memory access
  - Read transactions never block writers
  - Writers never block readers
  - Sequential reads are extremely fast due to B+ tree design

- Reliability:
  - Full ACID compliance with atomic, crash-resistant transactions
  - Copy-on-write design ensures database integrity even after crashes
  - Direct page updates without separate log files
  - Optional self-contained single file design simplifies backup operations
  - Battle-tested in OpenLDAP

## Why not LMDB ?

LMDB is not a general purpose database. It's a DB for specific purposes and shines in these areas.

You should not use LMDB, if
- your schema is not K/V based, but relational
- you need to efficiently query values additionally to keys
- you want to save time series or streaming data (e.g. logging)
- you cannot provide the same amount of RAM as your DB size **in write scenarios**

## Scenarios:

- Super fast querying of big DB's with minimal memory, e.g.
  - Dictionaries
  - Tile caches
  - Texture caching
  - Multiplatform assets
- Coherent realtime data updates
  - Producer -> Consumer(s)
    - Main App -> Plugin Instances
    - Audio Engine -> Visualizers
  - Multiple Producers -> Multiple Consumers
    - Worker Pools
    - Distributed Processing
  - Resource-Constrained IPC
    - Flutter App -> AudioUnit Extension
    - Host -> Sandboxed Plugins
- Configuration data (and lots of it)

## Supported Features

The following LMDB functionality is exposed:

- Complete CRUD operations
- Named databases for data organization
- Cursor operations for range queries
- Full transaction support with ACID guarantees
- Comprehensive statistics and monitoring
- Configurable initialization with all LMDB flags

## LMDB Version

This package bundles LMDB version `0.9.70`. While this version number hasn't changed in 3 years, LMDB is actively maintained. We track the exact git repository version: [da9aeda](https://github.com/LMDB/lmdb/commit/da9aeda08c3ff710a0d47d61a079f5a905b0a10a).

## Getting Started

Add the package to your `pubspec.yaml`:
```yaml
dependencies:
  dart_lmdb2: ^0.9.5
```

Then run:
```bash
# For Dart projects:
dart pub get
# For Flutter projects:
flutter pub get
```

## Usage

Import and use:

```dart
import 'package:lmdb2/lmdb2.dart';

void main() async {
    final db = LMDB();
    await db.init('path/to/db');

    // Simple auto-transaction operations
    await db.putAuto('key', 'value'.codeUnits);
    final result = await db.getAuto('key');

    // Manual transaction control
    final txn = await db.txnStart();
    try {
        await db.put(txn, 'key1', 'value1'.codeUnits);
        await db.put(txn, 'key2', 'value2'.codeUnits);
        await db.putUtf8(txn, 'english_greeting', 'Hello World');
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

## Native Libraries

Native libraries are automatically downloaded from GitHub releases on first use. They include SHA256 checksum verification for security. You can also manually download them:

```bash
dart run dart_lmdb2:fetch_native
```

## Development

Native libraries are stored in `lib/src/native/` after download:
```bash
> tree lib/src/native/
lib/src/native/
├── android
│   ├── arm64-v8a
│   │   └── liblmdb.so
│   └── x86_64
│       └── liblmdb.so
├── ios
│   ├── device
│   │   └── liblmdb.a
│   └── simulator
│       └── liblmdb.a
├── linux
│   └── liblmdb.so
├── macos
│   └── liblmdb.dylib
├── windows
│   └── lmdb.dll
└── manifest.json
```

You can rebuild these via the following steps:

### Prerequisites

This package bundles LMDB to be built from source. The build process is automated but requires:

- CMake (3.10 or higher)
- C compiler (gcc, clang, or MSVC)
- Dart SDK (3.0 or higher)

### Platform-specific setup

#### Android

You need to have installed the Android NDK, ideally via Android Studio. Furthermore. you need to have the environment variable `ANDROID_NDK_HOME` set to the appropriate NDK location.

#### iOS / iPadOS / MacOS

Please install XCode and the XCode command line tools.

```bash
# Install build tools
brew install cmake
```

#### Linux

```bash
# Install build tools
sudo apt-get install build-essential cmake
```

#### Windows

- Install Visual Studio with C++ development tools
- Install CMake

### Build & Test

1. Clone the repository and change to the project subdirectory:
```bash
git clone https://github.com/grammatek/dart_lmdb2.git
cd dart_lmdb2/dart_lmdb2
````

2. Install dependencies:
```bash
dart pub get
```

3. (Optionally) Rebuild the generated bindings via `ffigen`
```bash
dart run ffigen
```

4. Build the native library:
```bash
dart run tool/build.dart
```
For Android, you need to pass the flag `--android`:

```bash
dart run tool/build.dart --android
```

For iOS/iPadOS, you need to pass the flag `--ios`:

```bash
dart run tool/build.dart --ios
```

5. Run tests for active platform:
```bash
dart test
```

## CREDITS

Many thanks to the OpenLDAP team to provide such a fantastic lightweight, portable and easy to use database. You can access the original source-code either directly as a GitHub [standalone version](https://github.com/LMDB/lmdb) or via the [OpenLDAP](https://git.openldap.org/openldap/openldap/tree/mdb.master) GitLab repository.

## LICENSE

MIT License - see [LICENSE](LICENSE) file