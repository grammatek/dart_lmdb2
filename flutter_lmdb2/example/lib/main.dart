import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_lmdb2/flutter_lmdb2.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const FlutterLMDB2Demo());
}

class FlutterLMDB2Demo extends StatelessWidget {
  const FlutterLMDB2Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo with flutter_lmdb2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
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
      print('Starting database initialization...');

      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/lmdb_test';
      print('Using database path: $dbPath');

      // Ensure directory exists
      final dbDir = Directory(dbPath);
      if (!dbDir.existsSync()) {
        try {
          dbDir.createSync(recursive: true);
          print('Created database directory: $dbPath');
        } catch (e) {
          print('Failed to create directory: $e');
          setState(() {
            _status = 'Failed to create database directory: $e';
          });
          return;
        }
      }

      // Check directory permissions
      try {
        final file = File('${dbPath}/test.txt');
        await file.writeAsString('test');
        await file.delete();
        print('Directory permissions verified');
      } catch (e) {
        print('Directory permission test failed: $e');
        setState(() {
          _status = 'No write permission in database directory: $e';
        });
        return;
      }

      // Initialize database
      _db = LMDB2();
      print('Created LMDB2 instance');

      try {
        await _db.init(dbPath,
            config: LMDBInitConfig(mapSize: 10 * 1024 * 1024)); // 10MB
        print('Database initialized successfully');
      } catch (e) {
        print('Database initialization failed: $e');
        setState(() {
          _status = 'Database initialization failed: $e';
        });
        return;
      }

      // Test write with error handling
      late final txn;
      try {
        txn = await _db.txnStart();
        print('Transaction started');
      } catch (e) {
        print('Failed to start transaction: $e');
        setState(() {
          _status = 'Failed to start transaction: $e';
        });
        return;
      }

      try {
        await _db.putUtf8(txn, 'greeting', 'Hello from LMDB!');
        print('Data written');
        await _db.txnCommit(txn);
        print('Transaction committed');
      } catch (e) {
        print('Write operation failed: $e');
        try {
          await _db.txnAbort(txn);
        } catch (abortError) {
          print('Additionally, transaction abort failed: $abortError');
        }
        setState(() {
          _status = 'Write operation failed: $e';
        });
        return;
      }

      // Test read with error handling
      late final readTxn;
      try {
        readTxn = await _db.txnStart();
      } catch (e) {
        print('Failed to start read transaction: $e');
        setState(() {
          _status = 'Failed to start read transaction: $e';
        });
        return;
      }

      try {
        final value = await _db.getUtf8(readTxn, 'greeting');
        print('Data read: $value');
        await _db.txnCommit(readTxn);

        setState(() {
          _status = 'DB Test successful!\nRead value: $value';
        });
      } catch (e) {
        print('Read operation failed: $e');
        try {
          await _db.txnAbort(readTxn);
        } catch (abortError) {
          print('Additionally, read transaction abort failed: $abortError');
        }
        setState(() {
          _status = 'Read operation failed: $e';
        });
      }
    } catch (e) {
      print('Unexpected error during database operations: $e');
      setState(() {
        _status = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('flutter_lmdb2 Flutter Demo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Database Status:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _db.close();
      print('Database closed successfully');
    } catch (e) {
      print('Error closing database: $e');
    }
    super.dispose();
  }
}
