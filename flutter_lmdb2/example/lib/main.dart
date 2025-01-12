import 'package:flutter/material.dart';
import 'package:flutter_lmdb2/flutter_lmdb2.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _status = 'Initializing...';
  late LMDB2 _db;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/lmdb_test';

      // Initialize database
      _db = LMDB2();
      await _db.init(dbPath,
          config: LMDBInitConfig(mapSize: 10 * 1024 * 1024)); // 10MB

      // Test write
      final txn = await _db.txnStart();
      try {
        await _db.putUtf8(txn, 'greeting', 'Hello from LMDB!');
        await _db.txnCommit(txn);

        // Test read
        final readTxn = await _db.txnStart();
        try {
          final value = await _db.getUtf8(readTxn, 'greeting');
          await _db.txnCommit(readTxn);

          setState(() {
            _status = 'DB Test successful!\nRead value: $value';
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
        _status = 'DB initialization failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LMDB Flutter Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _status,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}
