// White-box tests for the Session API.

///|
async test "session.create returns the assigned id and sends the body" {
  let fake = FakeTransport::one(json_response("{\"ID\":\"s-1\"}"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let entry : SessionEntry = {
    ..default_session_entry,
    name: Some("n"),
    ttl: Some("10s"),
    behavior: Some(Release),
  }
  let (created, _) = client.session().create(entry~)
  assert_eq(created.id, Some("s-1"))
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.verb, "PUT")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/session/create")
  let body = bytes_text(req.body)
  assert_eq(body.contains("\"Name\":\"n\""), true)
  assert_eq(body.contains("\"Behavior\":\"release\""), true)
  assert_eq(body.contains("\"TTL\":\"10s\""), true)
}

///|
async test "session.info parses an entry" {
  let fake = FakeTransport::one(
    json_response(
      "[{\"ID\":\"s\",\"Name\":\"n\",\"TTL\":\"15s\",\"Behavior\":\"delete\",\"LockDelay\":5000000000}]",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (info, _) = client.session().info("s")
  let e = match info {
    Some(e) => e
    None => abort("expected an entry")
  }
  assert_eq(e.id, Some("s"))
  assert_eq(e.ttl, Some("15s"))
  let is_delete = match e.behavior {
    Some(Delete) => true
    _ => false
  }
  assert_eq(is_delete, true)
  assert_eq(e.lock_delay, Some(5000000000L))
}

///|
async test "session.list decodes every entry" {
  let fake = FakeTransport::one(
    json_response(
      "[{\"ID\":\"a\",\"Name\":\"x\"},{\"ID\":\"b\",\"Name\":\"y\"}]",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (list, _) = client.session().list()
  assert_eq(list.length(), 2)
  assert_eq(list[1].id, Some("b"))
}

///|
async test "session.renew returns None when the session expired" {
  let fake = FakeTransport::one(Response::new(404, b"session not found"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (renewed, _) = client.session().renew("gone")
  let absent = match renewed {
    None => true
    Some(_) => false
  }
  assert_eq(absent, true)
}
