import 'dart:ffi';
import 'generated_bindings.dart' as bindings;

/// Represents an LMDB transaction
class LMDBTxn {
  final Pointer<bindings.MDB_txn> _ptr;
  LMDBTxn._(this._ptr);

  Pointer<bindings.MDB_txn> get ptr => _ptr;
}
