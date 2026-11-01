///|
/// A distributed semaphore over a KV key, built on a Consul session. `acquire`
/// claims one of `limit` slot keys; when every slot is taken it returns
/// `false`, so the caller retries (this synchronous client does not block).
/// Slots are tied to the session, so a dead holder frees its slot.
pub struct Semaphore {
  client : Client
  options : SemaphoreOptions
  session : Ref[String?]
  held : Ref[String?]
}

///|
/// Options for a semaphore: the `key` it guards, the `limit` of concurrent
/// holders, and the `value` written while held. The backing session comes from
/// `session_opts` and `session_name`.
pub(all) struct SemaphoreOptions {
  key : String
  limit : Int32
  value : Bytes?
  session_opts : SessionEntry?
  session_name : String?
}

///|
/// A semaphore over `key` admitting `limit` holders.
pub fn Semaphore::new(client : Client, options : SemaphoreOptions) -> Semaphore {
  { client, options, session: Ref(None), held: Ref(None), }
}

///|
/// The backing session id, creating one if there is none yet.
fn Semaphore::ensure_session(
  self : Semaphore,
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
        None => raise Refused::Param("semaphore: session create returned no id")
      }
      self.session.val = Some(id)
      id
    }
  }
}

///|
/// The KV pair for slot key `slot`, bound to `session`.
fn Semaphore::slot_pair(
  self : Semaphore,
  slot : String,
  session : String,
) -> KVPair {
  {
    key: slot,
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
/// Acquire a slot, returning `true` when admitted.
pub fn Semaphore::acquire(
  self : Semaphore,
  options~ : WriteOptions = default_write_options,
) -> Bool raise Refused {
  let session = self.ensure_session(options)
  let mut admitted = false
  let mut index = 0
  while index < self.options.limit && !admitted {
    let slot = self.options.key + "/" + index.to_string()
    let (ok, _) = self.client
      .kv()
      .acquire(self.slot_pair(slot, session), options~)
    if ok {
      self.held.val = Some(slot)
      admitted = true
    } else {
      index = index + 1
    }
  }
  admitted
}

///|
/// Release a held slot, freeing it for the next acquirer.
pub fn Semaphore::release(
  self : Semaphore,
  options~ : WriteOptions = default_write_options,
) -> Unit raise Refused {
  let slot = match self.held.val {
    Some(s) => s
    None => raise Refused::Param("semaphore.release: no slot is held")
  }
  let session = match self.session.val {
    Some(s) => s
    None => raise Refused::Param("semaphore.release: no session")
  }
  let (_, _) = self.client.kv().release(self.slot_pair(slot, session), options~)
  let _ = self.client.session().destroy(session, options~)
  self.held.val = None
  self.session.val = None
}
