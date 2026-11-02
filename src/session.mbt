///|
/// A handle to the Session API: sessions are ephemeral leases, bound to a set of
/// checks, that back locks and semaphores. `moonconsul/concurrency` keeps one
/// alive. When a session's checks fail or its
/// TTL lapses, its held keys are released.
pub struct Session {
  client : Client
}

///|
/// What happens to a session's held keys when it is invalidated: `Release`
/// frees them, `Delete` removes them.
pub(all) enum SessionBehavior {
  Release
  Delete
}

///|
/// A session: its `id` (assigned by Consul), the `checks` that keep it alive,
/// the `lock_delay` before a key can be locked again after the session dies, in
/// nanoseconds (Consul reads a value under 1000 as seconds), the `behavior` on
/// invalidation, and the `ttl` that bounds its life without a renewal.
pub(all) struct SessionEntry {
  id : String?
  name : String?
  node : String?
  checks : Array[String]?
  lock_delay : Int64?
  behavior : SessionBehavior?
  ttl : String?
}

///|
/// The default session: no id, the default checks, and Consul's default lock
/// delay and TTL.
pub let default_session_entry : SessionEntry = {
  id: None,
  name: None,
  node: None,
  checks: None,
  lock_delay: None,
  behavior: None,
  ttl: None,
}

///|
/// A `SessionEntry` from its JSON object.
fn session_entry_of(j : Json) -> SessionEntry {
  let m = json_map(j)
  {
    id: jstr_opt(m, "ID"),
    name: jstr_opt(m, "Name"),
    node: jstr_opt(m, "Node"),
    checks: jstr_array_opt(m, "Checks"),
    lock_delay: ji64_opt(m, "LockDelay"),
    behavior: match jstr_opt(m, "Behavior") {
      Some("delete") => Some(Delete)
      Some("release") => Some(Release)
      _ => None
    },
    ttl: jstr_opt(m, "TTL"),
  }
}

///|
/// The JSON write body for a `SessionEntry`; the id is assigned by Consul.
fn session_entry_to_json(e : SessionEntry) -> Json {
  let m = jobj()
  put_str(m, "Name", e.name)
  put_str(m, "Node", e.node)
  put_str_array(m, "Checks", e.checks)
  put_i64(m, "LockDelay", e.lock_delay)
  match e.behavior {
    Some(Release) => m["Behavior"] = @json.to_json("release")
    Some(Delete) => m["Behavior"] = @json.to_json("delete")
    None => ()
  }
  put_str(m, "TTL", e.ttl)
  @json.to_json(m)
}

///|
/// Create a session from `entry`; the returned entry carries the assigned id.
pub async fn Session::create(
  self : Session,
  entry~ : SessionEntry = default_session_entry,
  options~ : WriteOptions = default_write_options,
) -> (SessionEntry, WriteMeta) raise Refused {
  let body = @utf8.encode(session_entry_to_json(entry).stringify())
  let (json, meta) = self.client.do_put("/v1/session/create", body, options, [])
  let m = json_map(json)
  ({ ..entry, id: jstr_opt(m, "ID"), }, meta)
}

///|
/// Destroy `id`, releasing everything it holds.
pub async fn Session::destroy(
  self : Session,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/session/destroy/" + id,
    b"",
    options,
    [],
  )
  meta
}

///|
/// Renew `id`, returning the refreshed entry (or `None` if it expired).
pub async fn Session::renew(
  self : Session,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> (SessionEntry?, WriteMeta) raise Refused {
  let (json, meta) = self.client.do_put(
    "/v1/session/renew/" + id,
    b"",
    options,
    [],
  ) catch {
    Refused::NotFound => return (None, empty_write_meta())
    e => raise e
  }
  let arr = json_array(json)
  match arr.get(0) {
    Some(item) => (Some(session_entry_of(item)), meta)
    None => (None, meta)
  }
}

///|
/// Read one session by `id`.
pub async fn Session::info(
  self : Session,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (SessionEntry?, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/session/info/" + id, options, []) catch {
    Refused::NotFound => return (None, empty_query_meta())
    e => raise e
  }
  let arr = json_array(json)
  match arr.get(0) {
    Some(item) => (Some(session_entry_of(item)), meta)
    None => (None, meta)
  }
}

///|
/// The sessions active on `node`.
pub async fn Session::node(
  self : Session,
  node : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[SessionEntry], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/session/node/" + node, options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[SessionEntry] = []
  for item in json_array(json) {
    out.push(session_entry_of(item))
  }
  (out, meta)
}

///|
/// Every session in the datacenter.
pub async fn Session::list(
  self : Session,
  options~ : QueryOptions = default_query_options,
) -> (Array[SessionEntry], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/session/list", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[SessionEntry] = []
  for item in json_array(json) {
    out.push(session_entry_of(item))
  }
  (out, meta)
}
