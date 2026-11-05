// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The protocol of Go's `api.Lock`, which is what `consul lock` runs: a lock here and one there
// exclude each other.

///|
/// The `Flags` of a lock's key. A key with any other value is in use for something else.
pub let lock_flag : UInt64 = 0x2DDCCBC058A50C18UL

///|
/// A lock's settings. The session comes from `entry` unless `session` names one to reuse, and a
/// session the lock created is the lock's to renew and destroy. `wait` bounds one blocking query,
/// in nanoseconds. `retry` is the pause, in milliseconds, while a lock delay runs out, and
/// `monitor_retries` and `monitor_retry` are how a held lock rides out an unreachable agent.
pub(all) struct LockOptions {
  value : Bytes
  session : String?
  entry : @moonconsul.SessionEntry
  wait : Int64
  retry : Int32
  monitor_retries : Int32
  monitor_retry : Int32
}

///|
/// The defaults of Go's `api.Lock`.
pub let default_lock_options : LockOptions = {
  value: b"",
  session: None,
  entry: {
    ..@moonconsul.default_session_entry,
    name: Some("Consul API Lock"),
    ttl: Some("15s"),
  },
  wait: 15_000_000_000L,
  retry: 5000,
  monitor_retries: 0,
  monitor_retry: 2000,
}

///|
/// A lock on one key, built on a session. A session that dies takes the lock with it, which is
/// the point: a holder that crashes does not hold the lock forever.
pub struct Lock {
  client : @moonconsul.Client
  key : String
  options : LockOptions
  priv owner : Owner
  priv mut held : Bool
}

///|
/// What one try found.
priv enum Round {
  Won
  Taken(UInt64)
  Delayed
}

///|
/// A lock on `key`.
pub fn Lock::new(
  client : @moonconsul.Client,
  key : String,
  options~ : LockOptions = default_lock_options,
) -> Lock {
  {
    client,
    key,
    options,
    owner: Owner::new(client, options.session, options.entry),
    held: false,
  }
}

///|
/// The key this lock writes for `session`.
fn Lock::entry(self : Lock, session : String) -> @moonconsul.KVPair {
  {
    key: self.key,
    create_index: 0UL,
    modify_index: 0UL,
    lock_index: 0UL,
    flags: lock_flag,
    value: self.options.value,
    session: Some(session),
  }
}

///|
/// Read the key from `index` and take it if it is free.
async fn Lock::round(
  self : Lock,
  id : String,
  index : UInt64,
) -> Round raise @moonconsul.Refused {
  let kv = self.client.kv()
  let (pair, meta) = kv.get(self.key, options={
    ..@moonconsul.default_query_options,
    wait_index: Some(index),
    wait_time: Some(self.options.wait),
  })
  if pair is Some(pair) {
    if pair.flags != lock_flag {
      raise @moonconsul.Conflict("the key is not a lock: " + self.key)
    }
    if pair.session == Some(id) {
      return Won
    }
    if pair.session is Some(_) {
      return Taken(meta.last_index)
    }
  }
  if kv.acquire(self.entry(id)).0 {
    return Won
  }
  // A free key that cannot be taken is under a lock delay, which no query waits for.
  let (pair, meta) = kv.get(self.key)
  if pair is Some({ session: Some(_), .. }) {
    Taken(meta.last_index)
  } else {
    Delayed
  }
}

///|
/// Wait until the key is ours.
async fn Lock::wait(self : Lock, id : String) -> Unit {
  let mut index = 0UL
  for ;; {
    match self.round(id, index) {
      Won => return
      Taken(seen) => index = seen
      Delayed => {
        index = 0UL
        @async.sleep(self.options.retry)
      }
    }
  }
}

///|
/// Give the key back.
async fn Lock::free(self : Lock, id : String) -> Unit raise @moonconsul.Refused {
  ignore(self.client.kv().release(self.entry(id)))
}

///|
/// Follow the key until `id` no longer holds it.
async fn Lock::monitor(self : Lock, id : String) -> Unit {
  let kv = self.client.kv()
  monitor(self.key, self.options.monitor_retries, self.options.monitor_retry, index => {
    let (pair, meta) = kv.get(self.key, options=following(index))
    if pair is Some(pair) && pair.session == Some(id) {
      Some(meta.last_index)
    } else {
      None
    }
  })
}

///|
/// Take the lock if it is free now, without waiting.
pub async fn Lock::try_acquire(self : Lock) -> Bool {
  if self.held {
    raise @moonconsul.Conflict("the lock is already held: " + self.key)
  }
  defer (if !self.held {
    @async.protect_from_cancel(() => self.owner.close() catch { _ => () })
  })
  self.held = self.round(self.owner.open(), 0UL) is Won
  self.held
}

///|
/// Wait until the lock is taken. Cancelling the task gives up, and `@async.with_timeout` bounds
/// the wait.
///
/// The session is renewed only while waiting: after this, the holder keeps it alive with
/// `keep_alive`. `hold` does all of that.
pub async fn Lock::acquire(self : Lock) -> Unit {
  if self.held {
    raise @moonconsul.Conflict("the lock is already held: " + self.key)
  }
  defer (if !self.held {
    @async.protect_from_cancel(() => self.owner.close() catch { _ => () })
  })
  let id = self.owner.open()
  self.owner.alive(id, () => self.wait(id))
  self.held = true
}

///|
/// Give the lock back, and destroy the session if this lock created it.
pub async fn Lock::release(self : Lock) -> Unit raise @moonconsul.Refused {
  guard self.held && self.owner.id is Some(id) else {
    raise @moonconsul.Conflict("the lock is not held: " + self.key)
  }
  self.held = false
  self.free(id)
  self.owner.close()
}

///|
/// Take the lock, run `body`, give the lock back. The session is renewed throughout, and if the
/// lock is lost `body` is cancelled and this raises `Conflict`.
pub async fn[T] Lock::hold(self : Lock, body : async () -> T) -> T {
  if self.held {
    raise @moonconsul.Conflict("the lock is already held: " + self.key)
  }
  let id = self.owner.open()
  defer @async.protect_from_cancel(() => self.owner.close() catch { _ => () })
  self.owner.alive(id, () => {
    self.wait(id)
    defer @async.protect_from_cancel(() => self.free(id) catch { _ => () })
    @async.with_task_group(group => {
      group.spawn_bg(no_wait=true, () => self.monitor(id))
      body()
    })
  })
}

///|
/// Delete the key of a lock nobody holds. Raises `Conflict` if it is held or is not a lock.
pub async fn Lock::destroy(self : Lock) -> Unit raise @moonconsul.Refused {
  if self.held {
    raise @moonconsul.Conflict("the lock is held: " + self.key)
  }
  let kv = self.client.kv()
  guard kv.get(self.key).0 is Some(pair) else { return }
  if pair.flags != lock_flag {
    raise @moonconsul.Conflict("the key is not a lock: " + self.key)
  }
  if pair.session is Some(_) || !kv.delete_cas(pair).0 {
    raise @moonconsul.Conflict("the lock is in use: " + self.key)
  }
}
