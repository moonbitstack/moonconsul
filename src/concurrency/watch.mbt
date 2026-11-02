// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The index a blocking query goes on from. Consul's rules for clients: an index that went
/// backwards means the state was reset, so start over; and it never waits from 0.
fn next_index(last : UInt64, seen : UInt64) -> UInt64 {
  if seen < last {
    0UL
  } else if seen == 0UL {
    1UL
  } else {
    seen
  }
}

///|
/// How long to wait after `failures` failures in a row: `retry` times the square of that, up to
/// `limit`, as Go's `watch.Plan` does.
fn backoff(failures : Int32, retry : Int32, limit : Int32) -> Int32 {
  let wait = retry.to_int64() * failures.to_int64() * failures.to_int64()
  if wait > limit.to_int64() {
    limit
  } else {
    wait.to_int()
  }
}

///|
/// Follow `kind` until the task is cancelled, calling `handler` with the index and the value each
/// time the value changes. The first value is reported too, and an absent one reads as `Null`.
///
/// `options` applies to every query; `wait_index` and `wait_hash` are this loop's to set. A failed
/// query is tried again after `retry` milliseconds, then 4, 9, 16... times that, up to `limit`.
pub async fn watch(
  client : @moonconsul.Client,
  kind : @moonconsul.WatchKind,
  handler : async (UInt64, Json) -> Unit,
  options~ : @moonconsul.QueryOptions = @moonconsul.default_query_options,
  retry~ : Int32 = 5000,
  limit~ : Int32 = 180_000,
) -> Unit {
  let mut index = 0UL
  let mut hash = None
  let mut last = None
  let mut failures = 0
  for ;; {
    let (value, meta) = client.poll(kind, options={
      ..options,
      wait_index: Some(index),
      wait_hash: hash,
    }) catch {
      e if @async.is_being_cancelled() => raise e
      _ => {
        failures += 1
        @async.sleep(backoff(failures, retry, limit))
        continue
      }
    }
    failures = 0
    index = next_index(index, meta.last_index)
    hash = meta.last_hash
    let value = value.unwrap_or(@moonconsul.json_null())
    if last != Some(value) {
      last = Some(value)
      handler(meta.last_index, value)
    }
  }
}
