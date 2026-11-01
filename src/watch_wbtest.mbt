// White-box tests for the blocking-query watch primitive.

///|
test "client.watch calls the handler when the index advances" {
  let fake = FakeTransport::one(
    json_response_at("[{\"Node\":\"n1\",\"Address\":\"1.2.3.4\"}]", 5L),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let plan : WatchPlan = {
    kind: "nodes",
    key: None,
    service: None,
    datacenter: None,
    token: None,
    index: 0L,
    wait_time: 0L,
    filter: None,
    near: None,
  }
  let seen = Ref(0L)
  let handler : (Int64, Json) -> Unit raise Refused = fn(index, _json) {
    seen.val = index
  }
  let w = client.watch(plan, handler)
  assert_eq(seen.val, 5L)
  assert_eq(w.plan.index, 5L)
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.url.contains("/v1/catalog/nodes"), true)
}

///|
test "client.watch skips the handler when the index is unchanged" {
  let fake = FakeTransport::one(json_response_at("[]", 3L))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let plan : WatchPlan = {
    kind: "nodes",
    key: None,
    service: None,
    datacenter: None,
    token: None,
    index: 3L,
    wait_time: 0L,
    filter: None,
    near: None,
  }
  let seen = Ref(0L)
  let handler : (Int64, Json) -> Unit raise Refused = fn(index, _json) {
    seen.val = index
  }
  let w = client.watch(plan, handler)
  assert_eq(seen.val, 0L)
  assert_eq(w.plan.index, 3L)
}

///|
/// A watch over an unknown kind, shaped so the test can inspect the error.
fn watch_bogus() -> String raise Refused {
  let fake = FakeTransport::one(json_response("[]"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let plan : WatchPlan = {
    kind: "bogus",
    key: None,
    service: None,
    datacenter: None,
    token: None,
    index: 0L,
    wait_time: 0L,
    filter: None,
    near: None,
  }
  let handler : (Int64, Json) -> Unit raise Refused = fn(_index, _json) { () }
  let _ = client.watch(plan, handler)
  "ok"
}

///|
test "client.watch rejects an unknown kind" {
  let result = watch_bogus() catch {
    Refused::Param(_) => "param"
    _ => "other"
  }
  assert_eq(result, "param")
}
