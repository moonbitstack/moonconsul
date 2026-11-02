///|
/// A handle to the Status API: the cluster's leader and its raft peer set.
pub struct Status {
  client : Client
}

///|
/// The address of the Raft leader, or empty when none is elected.
pub async fn Status::leader(
  self : Status,
  options~ : QueryOptions = default_query_options,
) -> (String, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/status/leader", options, [])
  let leader = match json {
    String(s) => s
    _ => ""
  }
  (leader, meta)
}

///|
/// The Raft peer addresses of the cluster.
pub async fn Status::peers(
  self : Status,
  options~ : QueryOptions = default_query_options,
) -> (Array[String], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/status/peers", options, [])
  let out : Array[String] = []
  for item in json_array(json) {
    if item is String(s) {
      out.push(s)
    }
  }
  (out, meta)
}
