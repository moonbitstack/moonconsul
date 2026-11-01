///|
/// A handle to the Session API: sessions are ephemeral leases, bound to a set of
/// checks, that back locks and semaphores. When a session's checks fail or its
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
/// the `lock_delay` before a released key can be re-locked, the `behavior` on
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
/// A running session renewal, returned by `renew_periodic`; `stop` ends it.
pub struct SessionRenewal {
  id : String
}

///|
/// Create a session from `entry`; the returned entry carries the assigned id.
pub fn Session::create(
  self : Session,
  entry~ : SessionEntry = default_session_entry,
  options~ : WriteOptions = default_write_options,
) -> (SessionEntry, WriteMeta) raise Refused {
  let _ = (self, entry, options)
  raise Refused::Unimplemented("session.create")
}

///|
/// Destroy `id`, releasing everything it holds.
pub fn Session::destroy(
  self : Session,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("session.destroy")
}

///|
/// Renew `id`, returning the refreshed entry (or `None` if it expired).
pub fn Session::renew(
  self : Session,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> (SessionEntry?, WriteMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("session.renew")
}

///|
/// Keep `id` alive every `ttl` nanoseconds in the background; `stop` ends the
/// loop. `entry` is the template used for each renewal request.
pub fn Session::renew_periodic(
  self : Session,
  ttl : Int64,
  id : String,
  entry : SessionEntry,
  options~ : WriteOptions = default_write_options,
) -> SessionRenewal raise Refused {
  let _ = (self, ttl, id, entry, options)
  let _handle = SessionRenewal::{ id, }
  raise Refused::Unimplemented("session.renew_periodic")
}

///|
/// End the background renewal started by `renew_periodic`.
pub fn SessionRenewal::stop(self : SessionRenewal) -> Unit {
  let _ = self
  abort("not implemented: session.renewal.stop")
}

///|
/// Read one session by `id`.
pub fn Session::info(
  self : Session,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (SessionEntry?, QueryMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("session.info")
}

///|
/// The sessions active on `node`.
pub fn Session::node(
  self : Session,
  node : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[SessionEntry], QueryMeta) raise Refused {
  let _ = (self, node, options)
  raise Refused::Unimplemented("session.node")
}

///|
/// Every session in the datacenter.
pub fn Session::list(
  self : Session,
  options~ : QueryOptions = default_query_options,
) -> (Array[SessionEntry], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("session.list")
}
