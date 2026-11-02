///|
/// How strongly a read must reflect cluster state. `Default` is served from a
/// follower that may be stale within a bounded window; `Consistent` is served
/// from the leader and linearizable; `Stale` is served from any node, including
/// one with no leader, for maximum availability.
pub(all) enum ConsistencyMode {
  Default
  Consistent
  Stale
}

///|
/// Options for a read. `wait_index` and `wait_time` drive a blocking query: the
/// agent holds the request until the data's index advances past `wait_index` or
/// `wait_time` nanoseconds elapse, then returns the new `QueryMeta.last_index`
/// to feed the next blocking call. The agent's own endpoints block on a content
/// hash instead, which is what `wait_hash` and `QueryMeta.last_hash` carry.
/// `datacenter`, `namespace` and `token` override the client defaults for this
/// call only.
pub(all) struct QueryOptions {
  datacenter : String?
  ns : String?
  token : String?
  wait_index : UInt64?
  wait_hash : String?
  wait_time : Int64?
  consistency : ConsistencyMode
  near : String?
  filter : String?
  node_meta : Map[String, String]?
}

///|
/// The default read options: no overrides, a default-consistency non-blocking
/// read with no wait.
pub let default_query_options : QueryOptions = {
  datacenter: None,
  ns: None,
  token: None,
  wait_index: None,
  wait_hash: None,
  wait_time: None,
  consistency: Default,
  near: None,
  filter: None,
  node_meta: None,
}

///|
/// Options for a write: the datacenter and namespace to target and the ACL
/// token to use, overriding the client defaults for this call only.
pub(all) struct WriteOptions {
  datacenter : String?
  ns : String?
  token : String?
}

///|
/// The default write options: no overrides.
pub let default_write_options : WriteOptions = {
  datacenter: None,
  ns: None,
  token: None,
}

///|
/// Metadata returned by every read. `last_index` is the index the agent last
/// saw for the queried data and is the `wait_index` of the next blocking query;
/// `known_leader` and `last_contact` describe leadership; `request_time` is the
/// round-trip time in nanoseconds.
pub(all) struct QueryMeta {
  last_index : UInt64
  last_hash : String?
  last_contact : Int64
  known_leader : Bool
  request_time : Int64
}

///|
/// Metadata returned by every write: `request_time` is the round-trip time in
/// nanoseconds.
pub(all) struct WriteMeta {
  request_time : Int64
}

///|
/// A zeroed `QueryMeta`, used where a call fails before a response is read.
pub fn empty_query_meta() -> QueryMeta {
  {
    last_index: 0UL,
    last_hash: None,
    last_contact: 0L,
    known_leader: false,
    request_time: 0L,
  }
}

///|
/// A zeroed `WriteMeta`.
pub fn empty_write_meta() -> WriteMeta {
  { request_time: 0L, }
}
