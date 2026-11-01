///|
/// A distributed semaphore over a KV key, built on a Consul session. `acquire`
/// claims up to `limit` slots; when all are taken it blocks on the key's index
/// and retries, so callers are admitted in arrival order as holders release.
pub struct Semaphore {
  client : Client
  options : SemaphoreOptions
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
  { client, options, }
}

///|
/// Acquire a slot, returning `true` when admitted.
pub fn Semaphore::acquire(
  self : Semaphore,
  options~ : WriteOptions = default_write_options,
) -> Bool raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("semaphore.acquire")
}

///|
/// Release a held slot, freeing it for the next acquirer.
pub fn Semaphore::release(
  self : Semaphore,
  options~ : WriteOptions = default_write_options,
) -> Unit raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("semaphore.release")
}
