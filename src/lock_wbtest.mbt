// White-box tests for the Lock and Semaphore primitives, which build on
// Session + KV.

///|
test "lock.acquire creates a session then claims the key" {
  let fake = FakeTransport::new([
    json_response("{\"ID\":\"s-9\"}"),
    ok_response(),
  ])
  let client = Client::with_address("127.0.0.1:8500", fake)
  let lock = Lock::new(client, {
    key: "l",
    value: Some(b"me"),
    session: None,
    session_opts: None,
    session_name: Some("lock-a"),
    behavior: None,
  })
  let ok = lock.acquire()
  assert_eq(ok, true)
  let reqs = fake.seen()
  assert_eq(reqs.length(), 2)
  assert_eq(reqs[0].url, "http://127.0.0.1:8500/v1/session/create")
  assert_eq(reqs[1].url.contains("/v1/kv/l?acquire=s-9"), true)
}

///|
test "lock.release frees the key and destroys the session" {
  let fake = FakeTransport::new([ok_response(), ok_response()])
  let client = Client::with_address("127.0.0.1:8500", fake)
  let lock = Lock::new(client, {
    key: "l",
    value: Some(b"me"),
    session: Some("s-9"),
    session_opts: None,
    session_name: None,
    behavior: None,
  })
  let ok = lock.release()
  assert_eq(ok, true)
  let reqs = fake.seen()
  assert_eq(reqs[0].url.contains("/v1/kv/l?release=s-9"), true)
  assert_eq(reqs[1].url, "http://127.0.0.1:8500/v1/session/destroy/s-9")
}

///|
test "semaphore.acquire claims the first free slot" {
  let fake = FakeTransport::new([
    json_response("{\"ID\":\"s-1\"}"),
    ok_response(),
  ])
  let client = Client::with_address("127.0.0.1:8500", fake)
  let sem = Semaphore::new(client, {
    key: "gate",
    limit: 2,
    value: None,
    session_opts: None,
    session_name: None,
  })
  let ok = sem.acquire()
  assert_eq(ok, true)
  let reqs = fake.seen()
  assert_eq(reqs[1].url.contains("/v1/kv/gate/0?acquire=s-1"), true)
}

///|
test "semaphore.acquire reports false when every slot is taken" {
  let fake = FakeTransport::new([
    json_response("{\"ID\":\"s-1\"}"),
    false_response(),
  ])
  let client = Client::with_address("127.0.0.1:8500", fake)
  let sem = Semaphore::new(client, {
    key: "gate",
    limit: 1,
    value: None,
    session_opts: None,
    session_name: None,
  })
  let ok = sem.acquire()
  assert_eq(ok, false)
}
