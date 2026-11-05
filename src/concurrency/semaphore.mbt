// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The protocol of Go's `api.Semaphore`, which is what `consul lock -n` runs. Each contender holds
// a key of its own under the prefix, and `<prefix>/.lock` lists who has a seat, written by
// compare-and-swap. A contender's key goes with its session, so a seat whose key is gone is free.

///|
/// The `Flags` of a semaphore's keys.
pub let semaphore_flag : UInt64 = 0xE0F69A2BAA414DE0UL

///|
/// A semaphore's settings, with the meanings they have in `LockOptions`.
pub(all) struct SemaphoreOptions {
  value : Bytes
  session : String?
  entry : @moonconsul.SessionEntry
  wait : Int64
  monitor_retries : Int32
  monitor_retry : Int32
}

///|
/// The defaults of Go's `api.Semaphore`.
pub let default_semaphore_options : SemaphoreOptions = {
  value: b"",
  session: None,
  entry: {
    ..@moonconsul.default_session_entry,
    name: Some("Consul API Semaphore"),
    ttl: Some("15s"),
    behavior: Some(Delete),
  },
  wait: 15_000_000_000L,
  monitor_retries: 0,
  monitor_retry: 2000,
}

///|
/// Up to `limit` holders at once under `prefix`.
pub struct Semaphore {
  client : @moonconsul.Client
  prefix : String
  limit : Int32
  options : SemaphoreOptions
  priv owner : Owner
  priv mut held : Bool
}

///|
/// What `<prefix>/.lock` holds.
priv struct Seats {
  limit : Int32
  holders : Map[String, Bool]
}

///|
/// What one try found.
priv enum Seat {
  Seated
  Full(UInt64)
  Again
}

///|
/// A semaphore admitting `limit` holders under `prefix`. Every contender must agree on `limit`.
pub fn Semaphore::new(
  client : @moonconsul.Client,
  prefix : String,
  limit : Int32,
  options~ : SemaphoreOptions = default_semaphore_options,
) -> Semaphore raise @moonconsul.Refused {
  if limit <= 0 {
    raise @moonconsul.Param("a semaphore needs a limit above 0")
  }
  {
    client,
    prefix: prefix.trim_end(chars="/").to_owned(),
    limit,
    options,
    owner: Owner::new(client, options.session, options.entry),
    held: false,
  }
}

///|
fn Semaphore::seats_key(self : Semaphore) -> String {
  self.prefix + "/.lock"
}

///|
/// The contender key of `session`.
fn Semaphore::contender(
  self : Semaphore,
  session : String,
) -> @moonconsul.KVPair {
  {
    key: self.prefix + "/" + session,
    create_index: 0UL,
    modify_index: 0UL,
    lock_index: 0UL,
    flags: semaphore_flag,
    value: self.options.value,
    session: Some(session),
  }
}

///|
/// The seats key among `pairs`, or an unwritten one.
fn Semaphore::seats_pair(
  self : Semaphore,
  pairs : Array[@moonconsul.KVPair],
) -> @moonconsul.KVPair {
  let key = self.seats_key()
  match pairs.search_by(pair => pair.key == key) {
    Some(at) => pairs[at]
    None =>
      {
        key,
        create_index: 0UL,
        modify_index: 0UL,
        lock_index: 0UL,
        flags: semaphore_flag,
        value: b"",
        session: None,
      }
  }
}

///|
/// The seats as the key has them, and an empty set for an unwritten key.
fn seats_of(value : Bytes, limit : Int32) -> Seats raise @moonconsul.Refused {
  if value.length() == 0 {
    return { limit, holders: Map([]), }
  }
  let text = @utf8.decode_lossy(value[:])
  let json = @json.parse(text) catch {
    e => raise @moonconsul.Json(e.to_string())
  }
  guard json is Object(fields) && fields.get("Limit") is Some(Number(n, ..)) else {
    raise @moonconsul.Json("not a semaphore: " + text)
  }
  let holders : Map[String, Bool] = Map([])
  if fields.get("Holders") is Some(Object(names)) {
    for name, _ in names {
      holders[name] = true
    }
  }
  { limit: n.to_int(), holders, }
}

///|
fn Seats::encode(self : Seats) -> Bytes {
  let holders : Map[String, Json] = Map([])
  for name, _ in self.holders {
    holders[name] = Json(true)
  }
  let fields : Map[String, Json] = Map([
    ("Limit", Json(self.limit)),
    ("Holders", Json(holders)),
  ])
  @utf8.encode(Json(fields).stringify())
}

///|
/// Clear the seats of sessions that no longer hold a key: their sessions are gone.
fn Seats::prune(self : Seats, pairs : Array[@moonconsul.KVPair]) -> Unit {
  let alive : Map[String, Bool] = Map([])
  for pair in pairs {
    if pair.session is Some(id) {
      alive[id] = true
    }
  }
  for name in self.holders.keys().to_array() {
    if !alive.contains(name) {
      self.holders.remove(name)
    }
  }
}

///|
/// Read the prefix from `index` and take a seat if one is free.
async fn Semaphore::round(
  self : Semaphore,
  id : String,
  index : UInt64,
) -> Seat raise @moonconsul.Refused {
  let kv = self.client.kv()
  let (pairs, meta) = kv.list(self.prefix, options={
    ..@moonconsul.default_query_options,
    wait_index: Some(index),
    wait_time: Some(self.options.wait),
  })
  let pair = self.seats_pair(pairs)
  if pair.flags != semaphore_flag {
    raise @moonconsul.Conflict("the key is not a semaphore: " + pair.key)
  }
  let seats = seats_of(pair.value, self.limit)
  if seats.limit != self.limit {
    raise @moonconsul.Conflict(
      "the semaphore's limit is \{seats.limit}, not \{self.limit}: \{self.prefix}",
    )
  }
  seats.prune(pairs)
  if seats.holders.length() >= seats.limit {
    return Full(meta.last_index)
  }
  seats.holders[id] = true
  if kv.cas({ ..pair, value: seats.encode(), }).0 {
    Seated
  } else {
    Again
  }
}

///|
/// Write the contender key, which is what shows this session to be alive.
async fn Semaphore::enter(
  self : Semaphore,
  id : String,
) -> Unit raise @moonconsul.Refused {
  guard self.client.kv().acquire(self.contender(id)).0 else {
    raise @moonconsul.Conflict("no contender key under " + self.prefix)
  }
}

///|
/// Give up the seat, if there is one, and the contender key.
async fn Semaphore::leave(
  self : Semaphore,
  id : String,
) -> Unit raise @moonconsul.Refused {
  let kv = self.client.kv()
  for ;; {
    guard kv.get(self.seats_key()).0 is Some(pair) else { break }
    let seats = seats_of(pair.value, self.limit)
    guard seats.holders.contains(id) else { break }
    seats.holders.remove(id)
    if kv.cas({ ..pair, value: seats.encode(), }).0 {
      break
    }
  }
  ignore(kv.delete(self.contender(id).key))
}

///|
/// Wait for a seat.
async fn Semaphore::wait(self : Semaphore, id : String) -> Unit {
  let mut index = 0UL
  for ;; {
    match self.round(id, index) {
      Seated => return
      Full(seen) => index = seen
      Again => ()
    }
  }
}

///|
/// Follow the seats until `id` no longer has one.
async fn Semaphore::monitor(self : Semaphore, id : String) -> Unit {
  let kv = self.client.kv()
  monitor(
    self.prefix,
    self.options.monitor_retries,
    self.options.monitor_retry,
    index => {
      let (pairs, meta) = kv.list(self.prefix, options=following(index))
      let seats = seats_of(self.seats_pair(pairs).value, self.limit)
      seats.prune(pairs)
      if seats.holders.contains(id) {
        Some(meta.last_index)
      } else {
        None
      }
    },
  )
}

///|
/// Take a seat if one is free now, without waiting.
pub async fn Semaphore::try_acquire(self : Semaphore) -> Bool {
  if self.held {
    raise @moonconsul.Conflict("the semaphore is already held: " + self.prefix)
  }
  let id = self.owner.open()
  defer (if !self.held {
    @async.protect_from_cancel(() => {
      self.leave(id) catch {
        _ => ()
      }
      self.owner.close() catch {
        _ => ()
      }
    })
  })
  self.enter(id)
  for ;; {
    match self.round(id, 0UL) {
      Seated => {
        self.held = true
        return true
      }
      Full(_) => return false
      Again => ()
    }
  }
}

///|
/// Wait for a seat. Cancelling the task gives up, and `@async.with_timeout` bounds the wait.
///
/// The session is renewed only while waiting: after this, the holder keeps it alive with
/// `keep_alive`. `hold` does all of that.
pub async fn Semaphore::acquire(self : Semaphore) -> Unit {
  if self.held {
    raise @moonconsul.Conflict("the semaphore is already held: " + self.prefix)
  }
  let id = self.owner.open()
  defer (if !self.held {
    @async.protect_from_cancel(() => {
      self.leave(id) catch {
        _ => ()
      }
      self.owner.close() catch {
        _ => ()
      }
    })
  })
  self.enter(id)
  self.owner.alive(id, () => self.wait(id))
  self.held = true
}

///|
/// Give up the seat, and destroy the session if this semaphore created it.
pub async fn Semaphore::release(
  self : Semaphore,
) -> Unit raise @moonconsul.Refused {
  guard self.held && self.owner.id is Some(id) else {
    raise @moonconsul.Conflict("the semaphore is not held: " + self.prefix)
  }
  self.held = false
  self.leave(id)
  self.owner.close()
}

///|
/// Take a seat, run `body`, give it up. The session is renewed throughout, and if the seat is
/// lost `body` is cancelled and this raises `Conflict`.
pub async fn[T] Semaphore::hold(self : Semaphore, body : async () -> T) -> T {
  if self.held {
    raise @moonconsul.Conflict("the semaphore is already held: " + self.prefix)
  }
  let id = self.owner.open()
  defer @async.protect_from_cancel(() => self.owner.close() catch { _ => () })
  self.owner.alive(id, () => {
    defer @async.protect_from_cancel(() => self.leave(id) catch { _ => () })
    self.enter(id)
    self.wait(id)
    @async.with_task_group(group => {
      group.spawn_bg(no_wait=true, () => self.monitor(id))
      body()
    })
  })
}

///|
/// Delete the seats key of a semaphore nobody holds. Raises `Conflict` if it is held or is not a
/// semaphore.
pub async fn Semaphore::destroy(
  self : Semaphore,
) -> Unit raise @moonconsul.Refused {
  if self.held {
    raise @moonconsul.Conflict("the semaphore is held: " + self.prefix)
  }
  let kv = self.client.kv()
  let (pairs, _) = kv.list(self.prefix)
  let pair = self.seats_pair(pairs)
  if pair.modify_index == 0UL {
    return
  }
  if pair.flags != semaphore_flag {
    raise @moonconsul.Conflict("the key is not a semaphore: " + pair.key)
  }
  let seats = seats_of(pair.value, self.limit)
  seats.prune(pairs)
  if seats.holders.length() > 0 || !kv.delete_cas(pair).0 {
    raise @moonconsul.Conflict("the semaphore is in use: " + self.prefix)
  }
}
