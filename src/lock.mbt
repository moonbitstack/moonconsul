///|
/// A distributed lock over a KV key, built on a Consul session. `acquire`
/// returns `false` when the key is held by another session, so the caller
/// retries (this synchronous client does not block); a holder keeps the lock by
/// renewing its session, and loses it when the session fails its checks or
/// expires.
pub struct Lock {
  client : Client
  options : LockOptions
  session : Ref[String?]
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
  { client, options, session: Ref(options.session), }
}

///|
/// The backing session id, creating one if the lock has none yet.
fn Lock::ensure_session(
  self : Lock,
  options : WriteOptions,
) -> String raise Refused {
  match self.session.val {
    Some(s) => s
    None => {
      let base = match self.options.session_opts {
        Some(e) => e
        None => default_session_entry
      }
      let entry = match base.name {
        Some(_) => base
        None => { ..base, name: self.options.session_name, }
      }
      let (created, _) = self.client.session().create(entry~, options~)
      let id = match created.id {
        Some(i) => i
        None => raise Refused::Param("lock: session create returned no id")
      }
      self.session.val = Some(id)
      id
    }
  }
}

///|
/// The KV pair this lock writes while held, bound to `session`.
fn Lock::pair(self : Lock, session : String) -> KVPair {
  {
    key: self.options.key,
    create_index: 0L,
    modify_index: 0L,
    lock_index: 0L,
    flags: 0L,
    value: match self.options.value {
      Some(v) => v
      None => b""
    },
    session: Some(session),
  }
}

///|
/// Acquire the lock, returning `true` when held. The caller must keep the
/// backing session alive.
pub fn Lock::acquire(
  self : Lock,
  options~ : WriteOptions = default_write_options,
) -> Bool raise Refused {
  let session = self.ensure_session(options)
  let (ok, _) = self.client.kv().acquire(self.pair(session), options~)
  ok
}

///|
/// Release the lock, freeing the key for the next acquirer.
pub fn Lock::release(
  self : Lock,
  options~ : WriteOptions = default_write_options,
) -> Bool raise Refused {
  let session = match self.session.val {
    Some(s) => s
    None => raise Refused::Param("lock.release: the lock was never acquired")
  }
  let (ok, _) = self.client.kv().release(self.pair(session), options~)
  let _ = self.client.session().destroy(session, options~)
  self.session.val = None
  ok
}
