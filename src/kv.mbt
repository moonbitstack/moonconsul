///|
/// A handle to the KV API: the key/value store. Reads and writes are paired
/// with blocking queries; compare-and-swap, acquire and release are the
/// primitives that locks and semaphores build on.
pub struct KV {
  client : Client
}

///|
/// One key/value entry: `create_index` and `modify_index` are the indexes that
/// gate blocking reads and CAS; `lock_index`, `flags` and `session` are used by
/// the lock primitives.
pub(all) struct KVPair {
  key : String
  create_index : Int64
  modify_index : Int64
  lock_index : Int64
  flags : Int64
  value : Bytes
  session : String?
}

///|
/// The verb of a transaction operation. `Set`/`CAS`/`Delete`/`DeleteTree`/
/// `DeleteCAS`/`Acquire`/`Release` mutate; `Get`/`GetKeys`/`Lock`/`Unlock`/
/// `Read` read; `CheckSession`/`CheckIndex`/`CheckNotExists` assert without
/// mutating.
pub(all) enum KVTxnOpVerb {
  Set
  CAS
  Delete
  DeleteTree
  DeleteCAS
  Acquire
  Release
  Get
  GetKeys
  CheckSession
  CheckIndex
  CheckNotExists
  Lock
  Unlock
  Read
}

///|
/// One operation in a `txn` batch.
pub(all) struct KVTxnOp {
  verb : KVTxnOpVerb
  key : String
  value : Bytes?
  index : Int64?
  session : String?
  flags : Int64?
}

///|
/// A per-operation failure inside a transaction.
pub(all) struct KVTxnError {
  op_index : Int32
  message : String
}

///|
/// The outcome of a `txn`: the `results` for the read verbs and the `errors`
/// for any operation that failed.
pub(all) struct KVTxnResponse {
  results : Array[KVPair]
  errors : Array[KVTxnError]?
}

///|
/// Read `key`, returning `None` when it does not exist.
pub fn KV::get(
  self : KV,
  key : String,
  options~ : QueryOptions = default_query_options,
) -> (KVPair?, QueryMeta) raise Refused {
  let _ = (self, key, options)
  raise Refused::Unimplemented("kv.get")
}

///|
/// List every entry under `prefix`.
pub fn KV::list(
  self : KV,
  prefix : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[KVPair], QueryMeta) raise Refused {
  let _ = (self, prefix, options)
  raise Refused::Unimplemented("kv.list")
}

///|
/// List only the keys under `prefix` (lighter than `list`).
pub fn KV::keys(
  self : KV,
  prefix : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[String], QueryMeta) raise Refused {
  let _ = (self, prefix, options)
  raise Refused::Unimplemented("kv.keys")
}

///|
/// Write `pair`; `modify_index` is ignored on a fresh write.
pub fn KV::put(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, pair, options)
  raise Refused::Unimplemented("kv.put")
}

///|
/// Delete `key`.
pub fn KV::delete(
  self : KV,
  key : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, key, options)
  raise Refused::Unimplemented("kv.delete")
}

///|
/// Delete every entry under `prefix`.
pub fn KV::delete_tree(
  self : KV,
  prefix : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, prefix, options)
  raise Refused::Unimplemented("kv.delete_tree")
}

///|
/// Compare-and-swap: succeed only when `pair.modify_index` matches the stored
/// index. The returned `Bool` is `true` on success.
pub fn KV::cas(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> (Bool, WriteMeta) raise Refused {
  let _ = (self, pair, options)
  raise Refused::Unimplemented("kv.cas")
}

///|
/// Acquire the lock on `key` for `pair.session`; succeed only when the key is
/// unlocked or already held by that session.
pub fn KV::acquire(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> (Bool, WriteMeta) raise Refused {
  let _ = (self, pair, options)
  raise Refused::Unimplemented("kv.acquire")
}

///|
/// Release the lock on `key` held by `pair.session`; succeed only when that
/// session holds it.
pub fn KV::release(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> (Bool, WriteMeta) raise Refused {
  let _ = (self, pair, options)
  raise Refused::Unimplemented("kv.release")
}

///|
/// Run `ops` as an atomic batch; `results` carries the reads, `errors` the
/// failures.
pub fn KV::txn(
  self : KV,
  ops : Array[KVTxnOp],
  options~ : QueryOptions = default_query_options,
) -> (KVTxnResponse, QueryMeta) raise Refused {
  let _ = (self, ops, options)
  raise Refused::Unimplemented("kv.txn")
}
