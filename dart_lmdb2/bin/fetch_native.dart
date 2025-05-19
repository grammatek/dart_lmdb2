#!/usr/bin/env dart

import 'dart:io';
import 'package:dart_lmdb2/src/fetch_native.dart';

Future<void> main(List<String> args) async {
  try {
    await fetchNativeLibraries();
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
