import 'package:flutter/material.dart';
import 'package:dart_lmdb2/dart_lmdb2.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('LMDB2 Demo'),
        ),
        body: const LMDBDemo(),
      ),
    );
  }
}

class LMDBDemo extends StatefulWidget {
  const LMDBDemo({super.key});

  @override
  State<LMDBDemo> createState() => _LMDBDemoState();
}

class _LMDBDemoState extends State<LMDBDemo> {
  String _status = 'Initializing...';
  late LMDB2 _db;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/lmdb_test';

      _db = LMDB2();
      await _db.init(dbPath, config: LMDBInitConfig(mapSize: 10 * 1024 * 1024));

      // Test write
      final txn = await _db.txnStart();
      try {
        await _db.putUtf8(txn, 'test_key', 'test_value');
        await _db.txnCommit(txn);

        // Test read
        final readTxn = await _db.txnStart();
        try {
          final value = await _db.getUtf8(readTxn, 'test_key');
          await _db.txnCommit(readTxn);

          setState(() {
            _status = 'DB working! Read value: $value';
          });
        } catch (e) {
          await _db.txnAbort(readTxn);
          setState(() {
            _status = 'Read failed: $e';
          });
        }
      } catch (e) {
        await _db.txnAbort(txn);
        setState(() {
          _status = 'Write failed: $e';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Init failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_status),
      ),
    );
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}
