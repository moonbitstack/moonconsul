// White-box tests for the KV API: the request shaping and the response
// parsing run against the in-memory fake, so they exercise the real wire
// format without a socket.

///|
/// Bytes as text, for readable assertions.
fn bytes_text(b : Bytes) -> String {
  @utf8.decode_lossy(b[:])
}

///|
async test "kv.get parses the pair and the blocking index" {
  let fake = FakeTransport::new([
    json_response_at(
      "[{\"Key\":\"app/db\",\"Value\":\"aGk=\",\"Flags\":3,\"CreateIndex\":10,\"ModifyIndex\":42,\"LockIndex\":0}]",
      42UL,
    ),
  ])
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (pair, meta) = client.kv().get("app/db")
  let p = match pair {
    Some(p) => p
    None => abort("expected a pair")
  }
  assert_eq(p.key, "app/db")
  assert_eq(bytes_text(p.value), "hi")
  assert_eq(p.flags, 3UL)
  assert_eq(p.modify_index, 42UL)
  assert_eq(meta.last_index, 42UL)
  assert_eq(meta.known_leader, true)
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.verb, "GET")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/kv/app/db")
}

///|
async test "kv.get returns None on 404" {
  let fake = FakeTransport::one(Response::new(404, b"not found"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (pair, _) = client.kv().get("missing")
  let absent = match pair {
    None => true
    Some(_) => false
  }
  assert_eq(absent, true)
}

///|
async test "kv.put sends the value as the raw body" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let pair : KVPair = {
    key: "app/db",
    create_index: 0UL,
    modify_index: 0UL,
    lock_index: 0UL,
    flags: 0UL,
    value: b"hi",
    session: None,
  }
  let _ = client.kv().put(pair)
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.verb, "PUT")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/kv/app/db")
  assert_eq(req.body, b"hi")
}

///|
async test "kv.cas appends the cas index and reports success" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let pair : KVPair = {
    key: "k",
    create_index: 0UL,
    modify_index: 7UL,
    lock_index: 0UL,
    flags: 0UL,
    value: b"v",
    session: None,
  }
  let (ok, _) = client.kv().cas(pair)
  assert_eq(ok, true)
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.url.contains("cas=7"), true)
}

///|
async test "kv.list requests recurse and decodes every entry" {
  let fake = FakeTransport::one(
    json_response(
      "[{\"Key\":\"a\",\"Value\":null,\"Flags\":0,\"CreateIndex\":1,\"ModifyIndex\":1,\"LockIndex\":0},{\"Key\":\"b\",\"Value\":\"eA==\",\"Flags\":0,\"CreateIndex\":2,\"ModifyIndex\":2,\"LockIndex\":0}]",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (pairs, _) = client.kv().list("")
  assert_eq(pairs.length(), 2)
  assert_eq(pairs[0].key, "a")
  assert_eq(bytes_text(pairs[1].value), "x")
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.url, "http://127.0.0.1:8500/v1/kv/?recurse=")
}

///|
async test "kv.keys decodes the string array" {
  let fake = FakeTransport::one(json_response("[\"a\",\"b/c\"]"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (keys, _) = client.kv().keys("")
  assert_eq(keys.length(), 2)
  assert_eq(keys[1], "b/c")
}

///|
async test "kv.txn sends Txn and decodes results" {
  let fake = FakeTransport::one(
    json_response_at(
      "{\"Results\":[{\"Key\":\"a\",\"Value\":\"eQ==\",\"Flags\":0,\"CreateIndex\":1,\"ModifyIndex\":5,\"LockIndex\":0}]}",
      5UL,
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let ops : Array[KVTxnOp] = [
    {
      verb: Get,
      key: "a",
      value: None,
      index: None,
      session: None,
      flags: None,
    },
  ]
  let (resp, meta) = client.kv().txn(ops)
  assert_eq(resp.results.length(), 1)
  assert_eq(bytes_text(resp.results[0].value), "y")
  assert_eq(meta.last_index, 5UL)
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.verb, "PUT")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/txn")
  assert_eq(bytes_text(req.body).contains("\"Verb\":\"get\""), true)
}

///|
/// A get against a 500, shaped so the test can inspect the raised status.
async fn get_boom() -> String raise Refused {
  let fake = FakeTransport::one(Response::new(500, @utf8.encode("boom")))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let _ = client.kv().get("k")
  "ok"
}

///|
async test "a non-2xx status raises Status" {
  let result = get_boom() catch {
    Refused::Status(_, body) => "status:" + body
    _ => "other"
  }
  assert_eq(result, "status:boom")
}
