import 'dart:convert';

import 'generated_bindings.dart' as bindings;

/// Public cursor operation modes for LMDB
enum CursorOp {
  /// Position at first key/data item
  first(bindings.MDB_cursor_op.MDB_FIRST),

  /// Position at first data item of current key (Only for MDB_DUPSORT)
  firstDup(bindings.MDB_cursor_op.MDB_FIRST_DUP),

  /// Position at key/data pair (Only for MDB_DUPSORT)
  getBoth(bindings.MDB_cursor_op.MDB_GET_BOTH),

  /// Position at key, nearest data (Only for MDB_DUPSORT)
  getBothRange(bindings.MDB_cursor_op.MDB_GET_BOTH_RANGE),

  /// Return key/data at current cursor position
  getCurrent(bindings.MDB_cursor_op.MDB_GET_CURRENT),

  /// Return up to a page of duplicate data items from current cursor position
  /// Move cursor to prepare for nextMultiple (Only for MDB_DUPFIXED)
  getMultiple(bindings.MDB_cursor_op.MDB_GET_MULTIPLE),

  /// Position at last key/data item
  last(bindings.MDB_cursor_op.MDB_LAST),

  /// Position at last data item of current key (Only for MDB_DUPSORT)
  lastDup(bindings.MDB_cursor_op.MDB_LAST_DUP),

  /// Position at next data item
  next(bindings.MDB_cursor_op.MDB_NEXT),

  /// Position at next data item of current key (Only for MDB_DUPSORT)
  nextDup(bindings.MDB_cursor_op.MDB_NEXT_DUP),

  /// Return up to a page of duplicate data items from next cursor position
  /// Move cursor to prepare for nextMultiple (Only for MDB_DUPFIXED)
  nextMultiple(bindings.MDB_cursor_op.MDB_NEXT_MULTIPLE),

  /// Position at first data item of next key
  nextNoDup(bindings.MDB_cursor_op.MDB_NEXT_NODUP),

  /// Position at previous data item
  prev(bindings.MDB_cursor_op.MDB_PREV),

  /// Position at previous data item of current key (Only for MDB_DUPSORT)
  prevDup(bindings.MDB_cursor_op.MDB_PREV_DUP),

  /// Position at last data item of previous key
  prevNoDup(bindings.MDB_cursor_op.MDB_PREV_NODUP),

  /// Position at specified key
  set(bindings.MDB_cursor_op.MDB_SET),

  /// Position at specified key, return key + data
  setKey(bindings.MDB_cursor_op.MDB_SET_KEY),

  /// Position at first key greater than or equal to specified key
  setRange(bindings.MDB_cursor_op.MDB_SET_RANGE),

  /// Position at previous page and return up to a page of duplicate data items
  /// Only for MDB_DUPFIXED
  prevMultiple(bindings.MDB_cursor_op.MDB_PREV_MULTIPLE);

  /// Internal value used by LMDB
  final bindings.MDB_cursor_op value;
  const CursorOp(this.value);
}

/// Represents an entry returned by cursor operations
class CursorEntry {
  /// Raw binary key data
  final List<int> key;

  /// Raw binary value data
  final List<int> data;

  /// Creates a cursor entry with raw binary key and data
  CursorEntry({required this.key, required this.data});

  /// Convenience method to decode the key as UTF-8 string
  String get keyAsString => utf8.decode(key);

  /// Convenience method to decode the data as UTF-8 string
  String get dataAsString => utf8.decode(data);

  /// Creates a CursorEntry from UTF-8 encoded strings
  factory CursorEntry.fromUtf8({
    required String key,
    required String data,
  }) {
    return CursorEntry(
      key: utf8.encode(key),
      data: utf8.encode(data),
    );
  }

  @override
  String toString() =>
      'CursorEntry(key: ${key.length} bytes, data: ${data.length} bytes)';

  /// Returns a string representation with UTF-8 decoded contents
  /// Throws FormatException if the data is not valid UTF-8
  String toStringDecoded() =>
      'CursorEntry(key: $keyAsString, data: $dataAsString)';
}
