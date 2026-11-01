///|
/// A distributed lock over a KV key, built on a Consul session. `acquire`
/// blocks (via the session) until the key is free or held by this session; a
/// holder keeps the lock by renewing its session, and loses it when the session
/// fails its checks or expires.
pub struct Lock {
  client : Client
  options : LockOptions
}

///|
/// Options for a lock: the `key` it guards and the `value` written while held.
/// A `session` reuses an existing session; otherwise a session is created from
/// `session_opts` and `session_name`.
pub(all) struct LockOptions {
  key : String
  value : Bytes?
  session : String?
  session_opts : SessionEntry?
  session_name : String?
  behavior : SessionBehavior?
}

///|
/// A lock over `key`; `session_opts`/`session_name` seed the backing session.
pub fn Lock::new(client : Client, options : LockOptions) -> Lock {
  { client, options, }
}

///|
/// Acquire the lock, returning `true` when held. The caller must keep the
/// backing session alive.
pub fn Lock::acquire(
  self : Lock,
  options~ : WriteOptions = default_write_options,
) -> Bool raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("lock.acquire")
}

///|
/// Release the lock, freeing the key for the next acquirer.
pub fn Lock::release(
  self : Lock,
  options~ : WriteOptions = default_write_options,
) -> Bool raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("lock.release")
}
