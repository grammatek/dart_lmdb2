import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:dart_lmdb2/lmdb.dart';

// Helper function for transaction management
Future<T> _withTransaction<T>(
  LMDB db,
  Future<T> Function(Pointer<MDB_txn> txn) action, {
  bool readOnly = false,
}) async {
  final txn = await db.txnStart(
    flags: readOnly ? (LMDBFlagSet()..add(MDB_RDONLY)) : null,
  );
  try {
    final result = await action(txn);
    await db.txnCommit(txn);
    return result;
  } catch (e) {
    await db.txnAbort(txn);
    rethrow;
  }
}

// Helper class for pagination results
class PageResult {
  final List<CursorEntry> entries;
  final String? nextPageKey;

  PageResult(this.entries, this.nextPageKey);
}

void main() {
  late LMDB db;
  late String dbPath;
  late Directory testDir;

  setUp(() async {
    // Create test directory with unique name
    testDir = Directory(path.join(
      Directory.current.path,
      'test_data',
      'db_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
    ));

    // Ensure clean state
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);

    dbPath = testDir.path;

    // Initialize database
    db = LMDB();
    try {
      final config = LMDBInitConfig(
        mapSize: LMDBConfig.minMapSize,
      );
      await db.init(dbPath, config: config);
    } catch (e) {
      // If initialization fails, clean up and rethrow
      testDir.deleteSync(recursive: true);
      rethrow;
    }
  });

  tearDown(() async {
    // Ensure database is properly closed
    try {
      db.close();
    } catch (e) {
      print('Warning: Error during database closure: $e');
    } finally {
      // Always try to clean up the test directory
      try {
        if (testDir.existsSync()) {
          testDir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Warning: Error during test directory cleanup: $e');
      }
    }
  });

  test('Cursor operations', () async {
    // Test data
    final testData = {
      'user:1': '{"name": "John", "age": 30}',
      'user:2': '{"name": "Jane", "age": 25}',
      'user:3': '{"name": "Bob", "age": 35}',
    };

    // Write test data
    final writeTxn = await db.txnStart();
    try {
      final cursor = await db.cursorOpen(writeTxn);
      try {
        for (var entry in testData.entries) {
          await db.cursorPutUtf8(cursor, entry.key, entry.value);
        }
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(writeTxn);
    } catch (e) {
      await db.txnAbort(writeTxn);
      rethrow;
    }

    // Test reading operations
    final readTxn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
    try {
      final cursor = await db.cursorOpen(readTxn);
      try {
        // Test cursor count
        final count = await db.cursorCount(readTxn);
        expect(count, equals(testData.length));

        // Test iteration through all entries
        var entry = await db.cursorGet(cursor, null, CursorOp.first);
        var foundEntries = 0;
        while (entry != null) {
          final key = entry.keyAsString;
          final data = entry.dataAsString;

          expect(testData.containsKey(key), isTrue);
          expect(testData[key], equals(data));

          foundEntries++;
          entry = await db.cursorGet(cursor, null, CursorOp.next);
        }
        expect(foundEntries, equals(testData.length));

        // Test specific key lookup
        final specificKey = 'user:2';
        entry = await db.cursorGet(
          cursor,
          utf8.encode(specificKey),
          CursorOp.set,
        );
        expect(entry, isNotNull);
        expect(entry?.keyAsString, equals(specificKey));
        expect(entry?.dataAsString, equals(testData[specificKey]));

        // Test range search
        entry = await db.cursorGet(
          cursor,
          utf8.encode('user:'),
          CursorOp.setRange,
        );
        expect(entry, isNotNull);
        expect(entry?.keyAsString, equals('user:1')); // Should find first user
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(readTxn);
    } catch (e) {
      await db.txnAbort(readTxn);
      rethrow;
    }

    // Test deletion in a separate write transaction
    final deleteTxn = await db.txnStart();
    try {
      final cursor = await db.cursorOpen(deleteTxn);
      try {
        await db.cursorGet(
          cursor,
          utf8.encode('user:2'),
          CursorOp.set,
        );
        await db.cursorDelete(cursor);
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(deleteTxn);
    } catch (e) {
      await db.txnAbort(deleteTxn);
      rethrow;
    }

    // Verify deletion in a final read transaction
    final verifyTxn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
    try {
      final cursor = await db.cursorOpen(verifyTxn);
      try {
        // Verify deletion
        final entry = await db.cursorGet(
          cursor,
          utf8.encode('user:2'),
          CursorOp.set,
        );
        expect(entry, isNull);

        // Verify remaining count
        final newCount = await db.cursorCount(verifyTxn);
        expect(newCount, equals(testData.length - 1));
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(verifyTxn);
    } catch (e) {
      await db.txnAbort(verifyTxn);
      rethrow;
    }
  });

  test('Cursor operations with grouped keys', () async {
    // Test data with different key groups
    final testData = {
      // Customer group
      'customer:001:name': 'John Doe',
      'customer:001:email': 'john@example.com',
      'customer:001:phone': '+1234567890',
      'customer:002:name': 'Jane Smith',
      'customer:002:email': 'jane@example.com',
      'customer:002:phone': '+1987654321',
      'customer:003:name': 'Bob Wilson',
      'customer:003:email': 'bob@example.com',
      'customer:003:phone': '+1122334455',

      // Product group
      'product:001:name': 'Laptop',
      'product:001:price': '999.99',
      'product:001:stock': '50',
      'product:002:name': 'Smartphone',
      'product:002:price': '599.99',
      'product:002:stock': '100',
      'product:003:name': 'Tablet',
      'product:003:price': '399.99',
      'product:003:stock': '75',

      // Order group
      'order:001:customer': 'customer:001',
      'order:001:product': 'product:002',
      'order:001:quantity': '2',
      'order:002:customer': 'customer:002',
      'order:002:product': 'product:001',
      'order:002:quantity': '1',
      'order:003:customer': 'customer:003',
      'order:003:product': 'product:003',
      'order:003:quantity': '3',
    };

    // Write test data
    final writeTxn = await db.txnStart();
    try {
      final cursor = await db.cursorOpen(writeTxn);
      try {
        for (var entry in testData.entries) {
          await db.cursorPutUtf8(cursor, entry.key, entry.value);
        }
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(writeTxn);
    } catch (e) {
      await db.txnAbort(writeTxn);
      rethrow;
    }

    // Read and verify groups
    final readTxn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
    try {
      final cursor = await db.cursorOpen(readTxn);
      try {
        // Test customer group
        var customerEntries = <String, String>{};
        var entry = await db.cursorGet(
          cursor,
          utf8.encode('customer:'),
          CursorOp.setRange,
        );

        while (entry != null && entry.keyAsString.startsWith('customer:')) {
          customerEntries[entry.keyAsString] = entry.dataAsString;
          entry = await db.cursorGet(cursor, null, CursorOp.next);
        }

        expect(customerEntries.length, equals(9)); // 3 customers × 3 fields
        expect(customerEntries.keys.every((k) => k.startsWith('customer:')),
            isTrue);

        // Test product group
        var productEntries = <String, String>{};
        entry = await db.cursorGet(
          cursor,
          utf8.encode('product:'),
          CursorOp.setRange,
        );

        while (entry != null && entry.keyAsString.startsWith('product:')) {
          productEntries[entry.keyAsString] = entry.dataAsString;
          entry = await db.cursorGet(cursor, null, CursorOp.next);
        }

        expect(productEntries.length, equals(9)); // 3 products × 3 fields
        expect(
            productEntries.keys.every((k) => k.startsWith('product:')), isTrue);

        // Test order group
        var orderEntries = <String, String>{};
        entry = await db.cursorGet(
          cursor,
          utf8.encode('order:'),
          CursorOp.setRange,
        );

        while (entry != null && entry.keyAsString.startsWith('order:')) {
          orderEntries[entry.keyAsString] = entry.dataAsString;
          entry = await db.cursorGet(cursor, null, CursorOp.next);
        }

        expect(orderEntries.length, equals(9)); // 3 orders × 3 fields
        expect(orderEntries.keys.every((k) => k.startsWith('order:')), isTrue);

        // Test specific customer data
        var customer2Data = <String, String>{};
        entry = await db.cursorGet(
          cursor,
          utf8.encode('customer:002:'),
          CursorOp.setRange,
        );

        while (entry != null && entry.keyAsString.startsWith('customer:002:')) {
          customer2Data[entry.keyAsString] = entry.dataAsString;
          entry = await db.cursorGet(cursor, null, CursorOp.next);
        }

        expect(customer2Data.length, equals(3));
        expect(customer2Data['customer:002:name'], equals('Jane Smith'));
        expect(customer2Data['customer:002:email'], equals('jane@example.com'));
        expect(customer2Data['customer:002:phone'], equals('+1987654321'));

        // Verify no cross-contamination between groups
        expect(
            customerEntries.keys.any((k) => k.startsWith('product:')), isFalse);
        expect(
            customerEntries.keys.any((k) => k.startsWith('order:')), isFalse);
        expect(
            productEntries.keys.any((k) => k.startsWith('customer:')), isFalse);
        expect(productEntries.keys.any((k) => k.startsWith('order:')), isFalse);
        expect(
            orderEntries.keys.any((k) => k.startsWith('customer:')), isFalse);
        expect(orderEntries.keys.any((k) => k.startsWith('product:')), isFalse);
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(readTxn);
    } catch (e) {
      await db.txnAbort(readTxn);
      rethrow;
    }
  });

  test('Cursor pagination', () async {
    // Setup test data - create enough entries for multiple pages
    final testEntries = List.generate(100, (index) {
      final paddedIndex = index.toString().padLeft(3, '0');
      return MapEntry(
        'key:$paddedIndex',
        'value for entry $paddedIndex',
      );
    });

    // Write test data
    final writeTxn = await db.txnStart();
    try {
      final cursor = await db.cursorOpen(writeTxn);
      try {
        for (var entry in testEntries) {
          await db.cursorPutUtf8(cursor, entry.key, entry.value);
        }
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(writeTxn);
    } catch (e) {
      await db.txnAbort(writeTxn);
      rethrow;
    }

    // Test pagination
    final readTxn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
    try {
      final cursor = await db.cursorOpen(readTxn);
      try {
        // Test parameters
        const pageSize = 10;
        final totalPages = (testEntries.length / pageSize).ceil();

        // Helper function to get a page of results
        Future<List<CursorEntry>> getPage(int pageNumber) async {
          final results = <CursorEntry>[];

          // Always start from the beginning for each page request
          var entry = await db.cursorGet(cursor, null, CursorOp.first);

          // Skip entries for the requested page
          for (var i = 0; i < pageNumber * pageSize && entry != null; i++) {
            entry = await db.cursorGet(cursor, null, CursorOp.next);
          }

          // Collect entries for current page
          for (var i = 0; i < pageSize && entry != null; i++) {
            results.add(entry);
            entry = await db.cursorGet(cursor, null, CursorOp.next);
          }

          return results;
        }

        // Test first page (0-9)
        final firstPage = await getPage(0);
        expect(firstPage.length, equals(pageSize));
        expect(firstPage.first.keyAsString, equals('key:000'));
        expect(firstPage.last.keyAsString, equals('key:009'));

        // Test middle page (50-59)
        final middlePage = await getPage(5);
        expect(middlePage.length, equals(pageSize));
        expect(middlePage.first.keyAsString, equals('key:050'));
        expect(middlePage.last.keyAsString, equals('key:059'));

        // Test last page (90-99)
        final lastPage = await getPage(9);
        expect(lastPage.length, equals(pageSize));
        expect(lastPage.first.keyAsString, equals('key:090'));
        expect(lastPage.last.keyAsString, equals('key:099'));

        // Verify sequential access of all pages
        var allEntries = <CursorEntry>[];
        for (var i = 0; i < totalPages; i++) {
          final page = await getPage(i);
          expect(
              page.length,
              i < totalPages - 1
                  ? equals(pageSize)
                  : lessThanOrEqualTo(pageSize));
          allEntries.addAll(page);
        }

        expect(allEntries.length, equals(testEntries.length));

        // Verify order and content
        for (var i = 0; i < allEntries.length; i++) {
          final paddedIndex = i.toString().padLeft(3, '0');
          expect(allEntries[i].keyAsString, equals('key:$paddedIndex'));
          expect(allEntries[i].dataAsString,
              equals('value for entry $paddedIndex'));
        }
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(readTxn);
    } catch (e) {
      await db.txnAbort(readTxn);
      rethrow;
    }
  });

  test('Cursor range-based pagination', () async {
    // Setup test data with date-based keys
    final testEntries = List.generate(100, (index) {
      final date = DateTime(2024, 1, 1).add(Duration(days: index));
      final formattedDate = date.toIso8601String().split('T').first;
      return MapEntry(
        'entry:$formattedDate',
        'value for day $index',
      );
    });

    // Write test data
    final writeTxn = await db.txnStart();
    try {
      final cursor = await db.cursorOpen(writeTxn);
      try {
        for (var entry in testEntries) {
          await db.cursorPutUtf8(cursor, entry.key, entry.value);
        }
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(writeTxn);
    } catch (e) {
      await db.txnAbort(writeTxn);
      rethrow;
    }

    // Test range-based pagination
    final readTxn = await db.txnStart(flags: LMDBFlagSet()..add(MDB_RDONLY));
    try {
      final cursor = await db.cursorOpen(readTxn);
      try {
        // Helper function to get entries within a date range
        Future<List<CursorEntry>> getEntriesInRange(
          String startDate,
          String endDate,
        ) async {
          final results = <CursorEntry>[];

          var entry = await db.cursorGet(
            cursor,
            utf8.encode('entry:$startDate'),
            CursorOp.setRange,
          );

          while (entry != null &&
              entry.keyAsString.compareTo('entry:$endDate') <= 0) {
            results.add(entry);
            entry = await db.cursorGet(cursor, null, CursorOp.next);
          }

          return results;
        }

        // Test first month
        final januaryEntries = await getEntriesInRange(
          '2024-01-01',
          '2024-01-31',
        );
        expect(januaryEntries.length, equals(31));
        expect(januaryEntries.first.keyAsString, equals('entry:2024-01-01'));
        expect(januaryEntries.last.keyAsString, equals('entry:2024-01-31'));

        // Test middle range
        final februaryEntries = await getEntriesInRange(
          '2024-02-01',
          '2024-02-29',
        );
        expect(februaryEntries.length, equals(29));
        expect(februaryEntries.first.keyAsString, equals('entry:2024-02-01'));
        expect(februaryEntries.last.keyAsString, equals('entry:2024-02-29'));

        // Test partial range
        final marchWeek = await getEntriesInRange(
          '2024-03-01',
          '2024-03-07',
        );
        expect(marchWeek.length, equals(7));
        expect(marchWeek.first.keyAsString, equals('entry:2024-03-01'));
        expect(marchWeek.last.keyAsString, equals('entry:2024-03-07'));
      } finally {
        db.cursorClose(cursor);
      }
      await db.txnCommit(readTxn);
    } catch (e) {
      await db.txnAbort(readTxn);
      rethrow;
    }
  });

  test('Efficient cursor-based pagination', () async {
    // Setup test data - create enough entries for multiple pages
    final testEntries = List.generate(100, (index) {
      final paddedIndex = index.toString().padLeft(3, '0');
      return MapEntry(
        'key:$paddedIndex',
        'value for entry $paddedIndex',
      );
    });

    // Write test data
    await _withTransaction(db, (txn) async {
      final cursor = await db.cursorOpen(txn);
      try {
        for (var entry in testEntries) {
          await db.cursorPutUtf8(cursor, entry.key, entry.value);
        }
      } finally {
        db.cursorClose(cursor);
      }
    });

    // Test efficient pagination
    await _withTransaction(db, (txn) async {
      final cursor = await db.cursorOpen(txn);
      try {
        const pageSize = 10;

        // Helper function to get a page of results
        Future<PageResult> getPage(String? startAfterKey) async {
          final results = <CursorEntry>[];
          String? nextKey;

          // Get first entry - either from start or after the given key
          var entry = startAfterKey == null
              ? await db.cursorGet(cursor, null, CursorOp.first)
              : await db.cursorGet(
                  cursor,
                  utf8.encode(startAfterKey),
                  CursorOp.setRange,
                );

          // If we started from a specific key, we're already positioned at the next entry
          // No need for an extra next operation

          // Collect entries for current page
          while (entry != null && results.length < pageSize) {
            results.add(entry);
            entry = await db.cursorGet(cursor, null, CursorOp.next);
          }

          // Get the key for the next page
          if (entry != null) {
            nextKey = entry.keyAsString;
          }

          return PageResult(results, nextKey);
        }

        // Test first page
        final firstPage = await getPage(null);
        expect(firstPage.entries.length, equals(pageSize));
        expect(firstPage.entries.first.keyAsString, equals('key:000'));
        expect(firstPage.entries.last.keyAsString, equals('key:009'));
        expect(firstPage.nextPageKey, equals('key:010'));

        // Test middle page using next key from first page
        final middlePage = await getPage(firstPage.nextPageKey);
        expect(middlePage.entries.length, equals(pageSize));
        expect(middlePage.entries.first.keyAsString, equals('key:010'));
        expect(middlePage.entries.last.keyAsString, equals('key:019'));
        expect(middlePage.nextPageKey, equals('key:020'));

        // Collect all pages efficiently
        var allEntries = <CursorEntry>[];
        String? currentPageKey;

        while (true) {
          final page = await getPage(currentPageKey);
          allEntries.addAll(page.entries);

          if (page.nextPageKey == null) {
            break;
          }
          currentPageKey = page.nextPageKey;
        }

        // Verify complete dataset
        expect(allEntries.length, equals(testEntries.length));

        for (var i = 0; i < allEntries.length; i++) {
          final paddedIndex = i.toString().padLeft(3, '0');
          expect(allEntries[i].keyAsString, equals('key:$paddedIndex'));
          expect(allEntries[i].dataAsString,
              equals('value for entry $paddedIndex'));
        }

        // Test seeking to specific page by key
        final specificPage = await getPage('key:050');
        expect(specificPage.entries.first.keyAsString, equals('key:050'));
        expect(specificPage.entries.last.keyAsString, equals('key:059'));

        // Test last page
        final lastPage = await getPage('key:090');
        expect(lastPage.entries.length, equals(10));
        expect(lastPage.entries.first.keyAsString, equals('key:090'));
        expect(lastPage.entries.last.keyAsString, equals('key:099'));
        expect(lastPage.nextPageKey, isNull);
      } finally {
        db.cursorClose(cursor);
      }
    }, readOnly: true);
  });

  test('Cursor operations with binary data', () async {
    // Binary test data
    final binaryData = [
      MapEntry(
          [0x01, 0x02, 0x03], // Binary key
          [0xFF, 0xFE, 0xFD] // Binary value
          ),
      MapEntry(
          [0x10, 0x20, 0x30], // Binary key
          [0xAA, 0xBB, 0xCC] // Binary value
          ),
    ];

    // Write binary data
    await _withTransaction(db, (txn) async {
      final cursor = await db.cursorOpen(txn);
      try {
        for (var entry in binaryData) {
          await db.cursorPut(cursor, entry.key, entry.value, 0);
        }
      } finally {
        db.cursorClose(cursor);
      }
    });

    // Read and verify binary data
    await _withTransaction(db, (txn) async {
      final cursor = await db.cursorOpen(txn);
      try {
        var entry = await db.cursorGet(cursor, null, CursorOp.first);

        expect(entry?.key, equals([0x01, 0x02, 0x03]));
        expect(entry?.data, equals([0xFF, 0xFE, 0xFD]));

        entry = await db.cursorGet(cursor, null, CursorOp.next);
        expect(entry?.key, equals([0x10, 0x20, 0x30]));
        expect(entry?.data, equals([0xAA, 0xBB, 0xCC]));
      } finally {
        db.cursorClose(cursor);
      }
    }, readOnly: true);
  });
}
