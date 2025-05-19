#!/usr/bin/env dart

import 'dart:io';
import 'package:dart_lmdb2/lmdb.dart' as lmdb;

Future<void> main(List<String> args) async {
  try {
    await lmdb.fetchNativeLibraries();
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
