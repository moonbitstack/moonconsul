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
/// The verb of a transaction operation.
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
/// A `KVPair` from its JSON object.
fn kv_pair_of(j : Json) -> KVPair {
  let m = json_map(j)
  {
    key: jstr(m, "Key"),
    create_index: ji64(m, "CreateIndex"),
    modify_index: ji64(m, "ModifyIndex"),
    lock_index: ji64(m, "LockIndex"),
    flags: ji64(m, "Flags"),
    value: match jbytes_b64_opt(m, "Value") {
      Some(b) => b
      None => b""
    },
    session: jstr_opt(m, "Session"),
  }
}

///|
/// The JSON write body for a `KVPair`; only the fields a write carries.
fn kv_pair_to_json(p : KVPair) -> Json {
  let m = jobj()
  put_str(m, "Key", Some(p.key))
  if p.value.length() > 0 {
    m["Value"] = @json.to_json(@base64.encode(p.value))
  }
  put_i64(m, "Flags", Some(p.flags))
  put_str(m, "Session", p.session)
  @json.to_json(m)
}

///|
/// The Consul txn verb string for an operation verb.
fn txn_verb_str(v : KVTxnOpVerb) -> String {
  match v {
    Set => "set"
    CAS => "cas"
    Delete => "delete"
    DeleteTree => "delete-tree"
    DeleteCAS => "delete-cas"
    Acquire => "acquire"
    Release => "release"
    Get => "get"
    GetKeys => "get-tree"
    CheckSession => "check-session"
    CheckIndex => "check-index"
    CheckNotExists => "check-not-exists"
    Lock => "lock"
    Unlock => "unlock"
    Read => "get"
  }
}

///|
/// The JSON body of one txn operation.
fn txn_op_to_json(op : KVTxnOp) -> Json {
  let kv = jobj()
  kv["Verb"] = @json.to_json(txn_verb_str(op.verb))
  kv["Key"] = @json.to_json(op.key)
  match op.value {
    Some(b) => kv["Value"] = @json.to_json(@base64.encode(b))
    None => ()
  }
  put_i64(kv, "Index", op.index)
  put_str(kv, "Session", op.session)
  put_i64(kv, "Flags", op.flags)
  @json.to_json(kv)
}

///|
/// A `KVTxnError` from its JSON object.
fn txn_error_of(j : Json) -> KVTxnError {
  let m = json_map(j)
  { op_index: ji32(m, "OpIndex"), message: jstr(m, "What"), }
}

///|
/// Read `key`, returning `None` when it does not exist.
pub fn KV::get(
  self : KV,
  key : String,
  options~ : QueryOptions = default_query_options,
) -> (KVPair?, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/kv/" + key, options, []) catch {
    Refused::NotFound => return (None, empty_query_meta())
    e => raise e
  }
  let arr = json_array(json)
  match arr.get(0) {
    Some(item) => (Some(kv_pair_of(item)), meta)
    None => (None, meta)
  }
}

///|
/// List every entry under `prefix`.
pub fn KV::list(
  self : KV,
  prefix : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[KVPair], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/kv/" + prefix, options, [
    ("recurse", ""),
  ]) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[KVPair] = []
  for item in json_array(json) {
    out.push(kv_pair_of(item))
  }
  (out, meta)
}

///|
/// List only the keys under `prefix` (lighter than `list`).
pub fn KV::keys(
  self : KV,
  prefix : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[String], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/kv/" + prefix, options, [
    ("keys", ""),
  ]) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[String] = []
  for item in json_array(json) {
    if item is String(s) {
      out.push(s)
    }
  }
  (out, meta)
}

///|
/// Write `pair`; `modify_index` is ignored on a fresh write.
pub fn KV::put(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(kv_pair_to_json(pair).stringify())
  let (_, meta) = self.client.do_put("/v1/kv/" + pair.key, body, options, [])
  meta
}

///|
/// Delete `key`.
pub fn KV::delete(
  self : KV,
  key : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/kv/" + key, options, [])
  meta
}

///|
/// Delete every entry under `prefix`.
pub fn KV::delete_tree(
  self : KV,
  prefix : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/kv/" + prefix, options, [
    ("recurse", ""),
  ])
  meta
}

///|
/// Compare-and-swap: succeed only when `pair.modify_index` matches the stored
/// index. The returned `Bool` is `true` on success.
pub fn KV::cas(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> (Bool, WriteMeta) raise Refused {
  let body = @utf8.encode(kv_pair_to_json(pair).stringify())
  let (json, meta) = self.client.do_put("/v1/kv/" + pair.key, body, options, [
    ("cas", pair.modify_index.to_string()),
  ])
  (json_bool(json), meta)
}

///|
/// Acquire the lock on `key` for `pair.session`; succeed only when the key is
/// unlocked or already held by that session.
pub fn KV::acquire(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> (Bool, WriteMeta) raise Refused {
  let session = match pair.session {
    Some(s) => s
    None => raise Refused::Param("kv.acquire: KVPair.session is required")
  }
  let body = @utf8.encode(kv_pair_to_json(pair).stringify())
  let (json, meta) = self.client.do_put("/v1/kv/" + pair.key, body, options, [
    ("acquire", session),
  ])
  (json_bool(json), meta)
}

///|
/// Release the lock on `key` held by `pair.session`; succeed only when that
/// session holds it.
pub fn KV::release(
  self : KV,
  pair : KVPair,
  options~ : WriteOptions = default_write_options,
) -> (Bool, WriteMeta) raise Refused {
  let session = match pair.session {
    Some(s) => s
    None => raise Refused::Param("kv.release: KVPair.session is required")
  }
  let body = @utf8.encode(kv_pair_to_json(pair).stringify())
  let (json, meta) = self.client.do_put("/v1/kv/" + pair.key, body, options, [
    ("release", session),
  ])
  (json_bool(json), meta)
}

///|
/// Run `ops` as an atomic batch; `results` carries the reads, `errors` the
/// failures.
pub fn KV::txn(
  self : KV,
  ops : Array[KVTxnOp],
  options~ : QueryOptions = default_query_options,
) -> (KVTxnResponse, QueryMeta) raise Refused {
  let op_array : Array[Json] = []
  for op in ops {
    op_array.push(txn_op_to_json(op))
  }
  let wrapper : Map[String, Json] = Map([])
  wrapper["Txn"] = @json.to_json(op_array)
  let body = @utf8.encode(@json.to_json(wrapper).stringify())
  let (json, meta) = self.client.do_put_q(
    "/v1/txn",
    body,
    { datacenter: options.datacenter, ns: options.ns, token: options.token, },
    [],
  )
  let m = json_map(json)
  let results : Array[KVPair] = []
  for item in jarray(m, "Results") {
    results.push(kv_pair_of(item))
  }
  let errors : Array[KVTxnError] = []
  for item in jarray(m, "Errors") {
    errors.push(txn_error_of(item))
  }
  let errors_opt = if errors.length() == 0 { None } else { Some(errors) }
  ({ results, errors: errors_opt, }, meta)
}
