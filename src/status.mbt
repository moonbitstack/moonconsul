///|
/// A handle to the Status API: the cluster's leader and its raft peer set.
pub struct Status {
  client : Client
}

///|
/// The address of the Raft leader, or empty when none is elected.
pub fn Status::leader(
  self : Status,
  options~ : QueryOptions = default_query_options,
) -> (String, QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("status.leader")
}

///|
/// The Raft peer addresses of the cluster.
pub fn Status::peers(
  self : Status,
  options~ : QueryOptions = default_query_options,
) -> (Array[String], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("status.peers")
}
