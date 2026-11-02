// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "a duration reads in Go's units" {
  assert_eq(millis_of("15s"), 15_000)
  assert_eq(millis_of("500ms"), 500)
  assert_eq(millis_of("1m30s"), 90_000)
  assert_eq(millis_of("1h"), 3_600_000)
}

///|
test "panic a duration without a unit is refused" {
  ignore(try! millis_of("15"))
}

///|
test "panic a duration without a number is refused" {
  ignore(try! millis_of("s"))
}

///|
test "an index that went backwards starts over, and 0 is never waited from" {
  assert_eq(next_index(5UL, 9UL), 9UL)
  assert_eq(next_index(5UL, 5UL), 5UL)
  assert_eq(next_index(9UL, 5UL), 0UL)
  assert_eq(next_index(0UL, 0UL), 1UL)
}

///|
test "failures back off by their square up to the limit" {
  assert_eq(backoff(1, 5000, 180_000), 5000)
  assert_eq(backoff(2, 5000, 180_000), 20_000)
  assert_eq(backoff(7, 5000, 180_000), 180_000)
  assert_eq(backoff(1_000_000, 5000, 180_000), 180_000)
}

///|
test "seats survive their own encoding, in the shape Go writes" {
  let seats = seats_of(
    @utf8.encode("{\"Limit\":3,\"Holders\":{\"a\":true}}"),
    9,
  )
  assert_eq(seats.limit, 3)
  assert_true(seats.holders.contains("a"))
  seats.holders["b"] = true
  let again = seats_of(seats.encode(), 9)
  assert_eq(again.limit, 3)
  assert_eq(again.holders.length(), 2)
}

///|
test "no value is no seats, and null holders are none" {
  assert_eq(seats_of(b"", 2).limit, 2)
  assert_eq(seats_of(b"", 2).holders.length(), 0)
  let seats = seats_of(@utf8.encode("{\"Limit\":1,\"Holders\":null}"), 2)
  assert_eq(seats.holders.length(), 0)
}

///|
test "panic a value that is not seats is refused" {
  ignore(try! seats_of(b"nonsense", 2))
}

///|
test "a seat with no live key is free" {
  let seats : Seats = {
    limit: 2,
    holders: Map([("alive", true), ("dead", true)]),
  }
  seats.prune([
    {
      key: "p/alive",
      create_index: 0UL,
      modify_index: 0UL,
      lock_index: 0UL,
      flags: semaphore_flag,
      value: b"",
      session: Some("alive"),
    },
  ])
  assert_true(seats.holders.contains("alive"))
  assert_false(seats.holders.contains("dead"))
}
