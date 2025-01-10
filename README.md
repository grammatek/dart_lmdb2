# dart_lmdb2

A Dart wrapper for LMDB (Lightning Memory-Mapped Database), providing both high-level convenience methods and low-level transaction control.

The following LMDB functionality is supported:

- Basic CRUD operations
- Named DB's
- Transactions
- Statistics
- Opening/Creation with all supported flags

Not yet supported:

- Cursors
- Statistics including freelist
- ???

Currently, only a subset of LMDB features are exposed to Dart, but it's relatively straight-forward to expose more functionality as demand increases.

The LMDB version bundled with this package is: `0.9.70`, but this version hasn't updated since 3 years, although the package is regularly updated. Therefore, we provide additionally the exact git repository version of `LMDB`, which is [da9aeda](https://github.com/LMDB/lmdb/commit/da9aeda08c3ff710a0d47d61a079f5a905b0a10a).


## Features

LMDB:

* High-performance, light-weight and battle-testetd database (from OpenLDAP)
* ACID conformant
* Durable even in case of crashes or sudden device shutdown (atomic commits)
* Write-ahead logging
* Fixed memory constraints via settable memory-mapped window
* Key/Value semantics, supports arbitrary binary data for keys/values
* Queryable keys via prefix-search
* Database can have multiple readers/writers from different processes/threads
* Readers don't block writers; writers just block other writers
* Platform-independent data format
* Very compact C-code (~10K LOC)

Dart LMDB2:

* Partial LMDB functionality exposed through Dart FFI
* Both automatic and manual transaction control
* Proper resource management
* Configurable database settings
* DB Statistics and analysis
* Native performance
* Unit tests for all exposed functions
* Multi-platform CI builds

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

3. (Optionally) Rebuild the generated bindings via `ffigen`
```bash
dart run ffigen
```

4. Build the native library:
```bash
dart run tool/build.dart
```

5. Run tests:
```bash
dart test
```

## CREDITS

Many thanks go to the OpenLDAP team to provide such a fantastic lightweight, portable and easy to use database. You can access the original source-code either directly as a GitHub [standalone version](https://github.com/LMDB/lmdb) or via the [OpenLDAP](https://git.openldap.org/openldap/openldap/tree/mdb.master) GitLab repository.

## LICENSE

MIT License - see [LICENSE](LICENSE) file
