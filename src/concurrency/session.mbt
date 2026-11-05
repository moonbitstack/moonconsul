// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Milliseconds in a Go duration such as `15s` or `1m30s`, the form Consul writes a TTL in.
fn millis_of(text : String) -> Int32 raise @moonconsul.Refused {
  let refused = @moonconsul.Param("not a duration: " + text)
  let mut total = 0L
  let mut number = 0L
  let mut digits = 0
  let mut unit = ""
  let flush = () => {
    let scale = match unit {
      "ms" => 1L
      "s" => 1000L
      "m" => 60_000L
      "h" => 3_600_000L
      _ => raise refused
    }
    if digits == 0 {
      raise refused
    }
    total += number * scale
    number = 0L
    digits = 0
    unit = ""
  }
  for ch in text {
    if ch is ('0'..<='9') {
      if unit != "" {
        flush()
      }
      number = number * 10L + (ch.to_int() - '0'.to_int()).to_int64()
      digits += 1
    } else {
      unit = unit + ch.to_string()
    }
  }
  flush()
  total.to_int()
}

///|
/// Keep session `id` alive until the task is cancelled, renewing at half of `ttl` milliseconds
/// and following the TTL the agent answers with, as Go's `RenewPeriodic` does.
///
/// A failed renewal is tried again each second until `ttl` has passed since the last good one,
/// and then raised. A session the agent no longer knows raises `NotFound`.
pub async fn keep_alive(
  session : @moonconsul.Session,
  id : String,
  ttl : Int32,
) -> Unit {
  let mut wait = ttl / 2
  let mut spare = ttl
  for ;; {
    @async.sleep(wait)
    spare -= wait
    let (entry, _) = session.renew(id) catch {
      e if @async.is_being_cancelled() => raise e
      e => {
        if spare <= 0 {
          raise e
        }
        wait = 1000
        continue
      }
    }
    guard entry is Some(entry) else { raise @moonconsul.NotFound }
    let answered = entry.ttl.map(millis_of).unwrap_or(ttl)
    wait = answered / 2
    spare = answered
  }
}

///|
/// The session a lock or a semaphore runs on: the one given, or one created for the hold and
/// destroyed after it.
priv struct Owner {
  session : @moonconsul.Session
  given : String?
  entry : @moonconsul.SessionEntry
  mut id : String?
}

///|
fn Owner::new(
  client : @moonconsul.Client,
  given : String?,
  entry : @moonconsul.SessionEntry,
) -> Owner {
  { session: client.session(), given, entry, id: given, }
}

///|
async fn Owner::open(self : Owner) -> String raise @moonconsul.Refused {
  if self.id is Some(id) {
    return id
  }
  let (made, _) = self.session.create(entry=self.entry)
  guard made.id is Some(id) else {
    raise @moonconsul.Json("a created session has no id")
  }
  self.id = Some(id)
  id
}

///|
/// Run `task` with the session renewed underneath it. A lock can take longer to come free than
/// a session lives.
async fn[T] Owner::alive(self : Owner, id : String, task : async () -> T) -> T {
  guard self.given is None && self.entry.ttl is Some(ttl) else { return task() }
  let ttl = millis_of(ttl)
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => keep_alive(self.session, id, ttl))
    task()
  })
}

///|
async fn Owner::close(self : Owner) -> Unit raise @moonconsul.Refused {
  if self.given is None && self.id is Some(id) {
    self.id = None
    ignore(self.session.destroy(id))
  }
}

///|
/// Follow a hold until `look`, a read blocking from an index, answers `None`, then raise
/// `Conflict` with `what`. An unreachable agent is ridden out `retries` times in a row, `retry`
/// milliseconds apart, as Go's `MonitorRetries` and `MonitorRetryTime`.
async fn monitor(
  what : String,
  retries : Int32,
  retry : Int32,
  look : async (UInt64) -> UInt64?,
) -> Unit {
  let mut index = 0UL
  let mut left = retries
  for ;; {
    let next = look(index) catch {
      e if @async.is_being_cancelled() => raise e
      @moonconsul.Transport(_) | @moonconsul.Status(500..<=599, _) as e => {
        if left <= 0 {
          raise e
        }
        left -= 1
        index = 0UL
        @async.sleep(retry)
        continue
      }
      e => raise e
    }
    match next {
      Some(seen) => {
        index = seen
        left = retries
      }
      None => raise @moonconsul.Conflict("lost: " + what)
    }
  }
}

///|
/// The consistent read that follows a hold.
fn following(index : UInt64) -> @moonconsul.QueryOptions {
  {
    ..@moonconsul.default_query_options,
    consistency: Consistent,
    wait_index: Some(index),
  }
}
