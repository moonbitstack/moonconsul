// White-box tests for the read/write groups added after KV/Session: a
// representative request-and-parse check per group against the fake.

///|
async test "status.leader parses the string body" {
  let fake = FakeTransport::one(json_response("\"10.0.0.1:8300\""))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (leader, _) = client.status().leader()
  assert_eq(leader, "10.0.0.1:8300")
}

///|
async test "agent.service_register posts the service body" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let reg : AgentServiceRegistration = {
    id: Some("web-1"),
    name: "web",
    tags: Some(["http"]),
    address: Some("10.0.0.9"),
    port: Some(8080),
    meta: None,
    ns: None,
    check: None,
    checks: None,
    enable_tag_override: None,
    weights: None,
  }
  let _ = client.agent().service_register(reg)
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.verb, "PUT")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/agent/service/register")
  let body = bytes_text(req.body)
  assert_eq(body.contains("\"Name\":\"web\""), true)
  assert_eq(body.contains("\"Port\":8080"), true)
}

///|
async test "catalog.service decodes instances" {
  let fake = FakeTransport::one(
    json_response(
      "[{\"ServiceID\":\"web-1\",\"Node\":\"n1\",\"ServiceAddress\":\"10.0.0.9\",\"ServiceName\":\"web\",\"ServiceTags\":[\"http\"],\"ServicePort\":8080}]",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (svcs, _) = client.catalog().service("web")
  assert_eq(svcs.length(), 1)
  assert_eq(svcs[0].id, "web-1")
  assert_eq(svcs[0].service, "web")
  assert_eq(svcs[0].address, "10.0.0.9")
  assert_eq(svcs[0].port, Some(8080))
}

///|
async test "health.service adds passing and decodes entries" {
  let fake = FakeTransport::one(
    json_response(
      "[{\"Node\":{\"Node\":\"n1\",\"Address\":\"10.0.0.9\"},\"Service\":{\"ID\":\"web-1\",\"Service\":\"web\",\"Port\":8080},\"Checks\":[{\"Node\":\"n1\",\"CheckID\":\"c1\",\"Status\":\"passing\"}]}]",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (entries, _) = client.health().service("web", passing=true)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].node.node, "n1")
  assert_eq(entries[0].checks.length(), 1)
  assert_eq(entries[0].checks[0].check_id, "c1")
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.url.contains("passing=true"), true)
}

///|
async test "prepared_query.create returns the assigned id" {
  let fake = FakeTransport::one(json_response("{\"ID\":\"pq-1\"}"))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let def : PreparedQueryDefinition = {
    id: None,
    name: Some("q"),
    token: None,
    ns: None,
    partition: None,
    service: Some({
      service: "web",
      ns: None,
      tags_any: None,
      only_passing: Some(true),
      node_type: None,
      failover: None,
    }),
    dns: None,
  }
  let (id, _) = client.prepared_query().create(def)
  assert_eq(id, "pq-1")
  let req = match fake.last() {
    Some(r) => r
    None => abort("expected a request")
  }
  assert_eq(req.url, "http://127.0.0.1:8500/v1/query")
  assert_eq(bytes_text(req.body).contains("\"Service\":\"web\""), true)
}

///|
async test "config_entries.get dispatches on kind" {
  let fake = FakeTransport::one(
    json_response(
      "{\"Kind\":\"service-defaults\",\"Name\":\"web\",\"Protocol\":\"http\"}",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (entry, _) = client.config_entries().get("service-defaults", "web")
  let proto = match entry {
    ServiceDefault(d) => d.protocol
    _ => None
  }
  assert_eq(proto, Some("http"))
}

///|
async test "acl.token_create decodes accessor and secret" {
  let fake = FakeTransport::one(
    json_response("{\"AccessorID\":\"acc-1\",\"SecretID\":\"sec-1\"}"),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let token : ACLToken = {
    id: None,
    accessor_id: None,
    secret_id: None,
    description: Some("t"),
    policies: None,
    roles: None,
    is_local: None,
    ns: None,
    partition: None,
    hash: None,
    expiration_time: None,
  }
  let (created, _) = client.acl().token_create(token)
  assert_eq(created.accessor_id, Some("acc-1"))
  assert_eq(created.secret_id, Some("sec-1"))
}
