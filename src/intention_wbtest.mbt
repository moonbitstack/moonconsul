// White-box tests for Connect intentions: the request each call shapes and the
// precedence order every list comes back in.

///|
async test "connect.intention_upsert names both services in the query" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let _ = client
    .connect()
    .intention_upsert({
      ..Intention::new("web", "db", Allow),
      source_ns: Some("default"),
      destination_ns: Some("default"),
      description: Some("web reaches db"),
    })
  let req = fake.last().unwrap()
  assert_eq(req.verb, "PUT")
  assert_eq(
    req.url,
    "http://127.0.0.1:8500/v1/connect/intentions/exact?source=default%2Fweb&destination=default%2Fdb",
  )
  let body = @json.parse(bytes_text(req.body)) catch {
    e => abort("the body is not JSON: \{e}")
  }
  let sent = json_map(body)
  assert_eq(sent.get("SourceName"), Some(Json::string("web")))
  assert_eq(sent.get("DestinationName"), Some(Json::string("db")))
  assert_eq(sent.get("Action"), Some(Json::string("allow")))
}

///|
async test "connect.intention_upsert refuses a nameless service" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let refused = try {
    let _ = client.connect().intention_upsert(Intention::new("", "db", Deny))
    false
  } catch {
    Refused::Param(_) => true
    _ => false
  }
  assert_true(refused)
  assert_eq(fake.seen().length(), 0)
}

///|
async test "connect.intention_match orders each name's rules by precedence" {
  let fake = FakeTransport::one(
    json_response(
      "{\"web\":[{\"SourceName\":\"web\",\"DestinationName\":\"db\",\"Action\":\"deny\",\"Precedence\":7},{\"SourceName\":\"web\",\"DestinationName\":\"db\",\"Action\":\"allow\",\"Precedence\":9},{\"SourceName\":\"*\",\"DestinationName\":\"db\",\"Action\":\"deny\",\"Precedence\":8}]}",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (matched, _) = client.connect().intention_match(Source, ["web", "api"])
  let rules = matched.get("web").unwrap()
  assert_eq(rules.length(), 3)
  assert_eq(rules[0].precedence, 9)
  assert_eq(rules[1].precedence, 8)
  assert_eq(rules[2].precedence, 7)
  assert_eq(rules[0].action.code(), "allow")
  assert_true(matched.get("api") is None)
  let req = fake.last().unwrap()
  assert_eq(
    req.url,
    "http://127.0.0.1:8500/v1/connect/intentions/match?by=source&name=web&name=api",
  )
}

///|
async test "connect.intention_get_exact answers None when nothing matches" {
  let fake = FakeTransport::one(Response::new(404, b"Intention not found"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (found, _) = client.connect().intention_get_exact("web", "db")
  assert_true(found is None)
}

///|
async test "connect.intention_check reports the agent's decision" {
  let fake = FakeTransport::one(json_response("{\"Allowed\":false}"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (allowed, _) = client.connect().intention_check("web", "db")
  assert_false(allowed)
}

///|
async test "connect.intention_delete_exact deletes by the pair" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let _ = client.connect().intention_delete_exact("web", "db")
  let req = fake.last().unwrap()
  assert_eq(req.verb, "DELETE")
  assert_eq(
    req.url,
    "http://127.0.0.1:8500/v1/connect/intentions/exact?source=web&destination=db",
  )
}

///|
async test "connect.intention_list puts the highest precedence first" {
  let fake = FakeTransport::one(
    json_response(
      "[{\"SourceName\":\"*\",\"DestinationName\":\"db\",\"Action\":\"deny\",\"Precedence\":8},{\"SourceName\":\"web\",\"DestinationName\":\"db\",\"Action\":\"allow\",\"Precedence\":9}]",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (listed, _) = client.connect().intention_list()
  assert_eq(listed.length(), 2)
  assert_eq(listed[0].source_name, "web")
  assert_eq(listed[0].action.code(), "allow")
  assert_eq(listed[1].action.code(), "deny")
}
