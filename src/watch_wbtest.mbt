///|
async test "poll reads a kind at its path and passes the blocking state" {
  let fake = FakeTransport::one(json_response_at("[]", 5UL))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (json, meta) = client.poll(Nodes, options={
    ..default_query_options,
    wait_index: Some(4UL),
  })
  assert_true(json is Some(_))
  assert_eq(meta.last_index, 5UL)
  let url = fake.last().unwrap().url
  assert_true(url.contains("/v1/catalog/nodes"))
  assert_true(url.contains("index=4"))
}

///|
async test "poll takes a 404 as an absent value and keeps its index" {
  let fake = FakeTransport::one({
    status: 404,
    headers: Map::from_array([("X-Consul-Index", "9")]),
    body: b"",
  })
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (json, meta) = client.poll(Key("missing"))
  assert_true(json is None)
  assert_eq(meta.last_index, 9UL)
}

///|
async test "an index past the signed range survives the round trip" {
  let fake = FakeTransport::one(json_response_at("[]", 18446744073709551615UL))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (_, meta) = client.poll(Event("deploy"))
  assert_eq(meta.last_index, 18446744073709551615UL)
  let url = fake.last().unwrap().url
  assert_true(url.contains("/v1/event/list?name=deploy"))
}

///|
test "each kind names its path" {
  assert_eq(watch_request(KeyPrefix("a")), ("/v1/kv/a", [("recurse", "")]))
  assert_eq(
    watch_request(Service("web", passing=true)),
    ("/v1/health/service/web", [("passing", "")]),
  )
  assert_eq(
    watch_request(Service("web", passing=false)),
    ("/v1/health/service/web", []),
  )
  assert_eq(watch_request(ConnectRoots).0, "/v1/agent/connect/ca/roots")
  assert_eq(
    watch_request(ConnectLeaf("web")).0,
    "/v1/agent/connect/ca/leaf/web",
  )
  assert_eq(watch_request(AgentService("web-1")).0, "/v1/agent/service/web-1")
  assert_eq(watch_request(Services).0, "/v1/catalog/services")
  assert_eq(watch_request(Checks("web")).0, "/v1/health/checks/web")
  assert_eq(watch_request(State("any")).0, "/v1/health/state/any")
  assert_eq(watch_request(Key("a")).0, "/v1/kv/a")
}

///|
async test "poll blocks on a hash where the agent gives one" {
  let fake = FakeTransport::one({
    status: 200,
    headers: Map::from_array([("X-Consul-Contenthash", "abc")]),
    body: b"{}",
  })
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (_, meta) = client.poll(AgentService("web-1"), options={
    ..default_query_options,
    wait_hash: Some("abc"),
  })
  assert_eq(meta.last_hash, Some("abc"))
  assert_true(fake.last().unwrap().url.contains("hash=abc"))
}
