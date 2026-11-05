// Connect and ACL authentication against live agents: the certificates an agent
// issues, the intentions that decide who may talk to whom, the cluster's CA
// configuration, and a JWT login that trades a signed token for a Consul one.

///|
/// The base64 body of a PEM block, decoded.
fn pem_body(pem : String) -> Bytes {
  let mut body = ""
  for line in pem.split("\n") {
    let text = line.to_owned()
    if text.contains("-----BEGIN") || text.contains("-----END") {
      continue
    }
    body = body + text
  }
  @base64.decode_lossy(body)
}

///|
/// Register a service instance with no checks, so a name exists in the catalog.
async fn register_service(c : @moonconsul.Client, name : String) -> Unit {
  ignore(
    c
    .agent()
    .service_register({
      ..@moonconsul.default_service_registration,
      id: Some(name),
      name,
      port: Some(9200),
    }),
  )
}

///|
async test "connect: a leaf carries the service's SPIFFE identity" {
  guard live() is Some(c) else { return }
  let service = stamped("leaf")
  register_service(c, service)
  let (roots, _) = c.agent().connect_roots()
  assert_true(roots.trust_domain.has_suffix(".consul"))
  assert_true(roots.roots.length() >= 1)
  assert_true(roots.roots.iter().any(r => r.id == roots.active_root_id))
  assert_true(
    roots.roots.iter().any(r => r.root_cert_pem.contains("BEGIN CERTIFICATE")),
  )
  let (leaf, _) = c.agent().connect_leaf(service)
  assert_eq(leaf.service, service)
  assert_eq(
    leaf.service_uri,
    "spiffe://" + roots.trust_domain + "/ns/default/dc/dc1/svc/" + service,
  )
  assert_true(leaf.cert_pem.contains("BEGIN CERTIFICATE"))
  assert_true(leaf.private_key_pem.contains("PRIVATE KEY"))
  assert_true(leaf.serial_number.length() > 0)
  // The identity is in the certificate itself, not only in the JSON beside it.
  let certificate = @utf8.decode_lossy(pem_body(leaf.cert_pem)[:])
  assert_true(certificate.contains(leaf.service_uri))
  ignore(c.agent().service_deregister(service))
}

///|
async test "connect: a leaf escapes a name that needs it" {
  guard live() is Some(c) else { return }
  // A space in the name is a path segment's worst case: the request has to
  // percent-encode it, and the identity it comes back with carries the escape.
  let service = stamped("spaced") + " web"
  let (leaf, _) = c.agent().connect_leaf(service)
  assert_eq(leaf.service, service)
  let escaped = service.replace_all(old=" ", new="%20")
  assert_true(leaf.service_uri.has_suffix("/svc/" + escaped))
}

///|
async test "connect: the CA configuration reads and rewrites without rotating" {
  guard live() is Some(c) else { return }
  let connect = c.connect()
  let (config, _) = connect.ca_config()
  assert_eq(config.provider, "consul")
  assert_true(config.config is Some(_))
  let (before, _) = c.agent().connect_roots()
  ignore(connect.ca_set_config(config))
  let (after, _) = c.agent().connect_roots()
  assert_eq(after.active_root_id, before.active_root_id)
}

///|
/// The agent's authorization decision, waiting out its intention cache: a write
/// reaches the decision within milliseconds, but not by the time its reply
/// lands.
async fn authorize_settles(
  c : @moonconsul.Client,
  params : @moonconsul.AgentAuthorizeParams,
  want : Bool,
) -> Bool {
  for _ in 0..<100 {
    let (decision, _) = c.agent().connect_authorize(params)
    if decision.authorized == want {
      return true
    }
    @async.sleep(20)
  }
  false
}

///|
/// The same wait around the check endpoint.
async fn check_settles(
  connect : @moonconsul.Connect,
  source : String,
  destination : String,
  want : Bool,
) -> Bool {
  for _ in 0..<100 {
    if connect.intention_check(source, destination).0 == want {
      return true
    }
    @async.sleep(20)
  }
  false
}

///|
async test "connect: intentions decide who a service may reach" {
  guard live() is Some(c) else { return }
  let connect = c.connect()
  let source = stamped("intent-src")
  let destination = stamped("intent-dst")
  register_service(c, source)
  register_service(c, destination)
  let (leaf, _) = c.agent().connect_leaf(source)
  let params : @moonconsul.AgentAuthorizeParams = {
    target: destination,
    client_cert_uri: leaf.service_uri,
    client_cert_serial: leaf.serial_number,
  }
  // An agent without ACLs allows by default.
  assert_true(authorize_settles(c, params, true))
  // A deny between the two services turns that around.
  ignore(
    connect.intention_upsert({
      ..@moonconsul.Intention::new(source, destination, Deny),
      description: Some("closed"),
    }),
  )
  assert_true(authorize_settles(c, params, false))
  assert_true(check_settles(connect, source, destination, false))
  let (stored, _) = connect.intention_get_exact(source, destination)
  guard stored is Some(read) else { fail("the intention is not there") }
  assert_eq(read.action.code(), "deny")
  assert_eq(read.description, Some("closed"))
  assert_true(read.precedence > 0)
  assert_true(
    connect.intention_list().0
    .iter()
    .any(i => i.destination_name == destination),
  )
  // An allow of the same pair replaces it, as the pair names the intention.
  ignore(
    connect.intention_upsert(
      @moonconsul.Intention::new(source, destination, Allow),
    ),
  )
  assert_true(authorize_settles(c, params, true))
  assert_true(check_settles(connect, source, destination, true))
  // A wildcard deny does not outrank the exact allow.
  ignore(
    connect.intention_upsert(@moonconsul.Intention::new("*", destination, Deny)),
  )
  assert_true(authorize_settles(c, params, true))
  let (matched, _) = connect.intention_match(Destination, [destination])
  let rules = matched.get(destination).unwrap_or([])
  assert_true(rules.length() >= 2)
  assert_eq(rules[0].source_name, source)
  assert_true(rules[0].precedence > rules[1].precedence)
  // With the exact rule gone the wildcard is what decides.
  ignore(connect.intention_delete_exact(source, destination))
  assert_true(authorize_settles(c, params, false))
  ignore(connect.intention_delete_exact("*", destination))
  assert_true(authorize_settles(c, params, true))
  assert_true(connect.intention_get_exact(source, destination).0 is None)
  assert_true(
    connect.intention_get("00000000-0000-0000-0000-000000000000").0 is None,
  )
  ignore(c.agent().service_deregister(source))
  ignore(c.agent().service_deregister(destination))
}

///|
async test "acl: a JWT login trades a signed token for a Consul one" {
  guard live_acl() is Some(c) else { return }
  let acl = c.acl()
  let name = stamped("jwt")
  let auth_method_name = "am-" + name
  let (policy, _) = acl.policy_create({
    id: None,
    name: Some(name),
    description: Some("the login test's key space"),
    rules: Some("key_prefix \"it/jwt/\" { policy = \"write\" }"),
    datacenter: None,
    ns: None,
    partition: None,
    hash: None,
  })
  let (role, _) = acl.role_create({
    id: None,
    name: Some(name),
    description: Some("bound by the login test's rule"),
    policies: Some([{ id: policy.id, name: None, }]),
    ns: None,
    partition: None,
    hash: None,
  })
  let (created, _) = acl.auth_method_create({
    name: Some(auth_method_name),
    kind: Some("jwt"),
    description: Some("the login test's method"),
    config: Some(
      Map([
        ("JWTValidationPubkeys", Json::array([Json::string(jwt_public_pem())])),
        ("ClaimMappings", Json::object(Map([("sub", Json::string("sub"))]))),
      ]),
    ),
    ns: None,
    partition: None,
  })
  assert_eq(created.kind, Some("jwt"))
  let (rule, _) = acl.binding_rule_create({
    id: None,
    description: Some("the login test's rule"),
    auth_method: Some(auth_method_name),
    selector: Some("value.sub == \"" + jwt_subject + "\""),
    bind_type: Some("role"),
    bind_name: role.name,
    ns: None,
    partition: None,
  })
  assert_eq(rule.bind_type, Some("role"))
  assert_eq(acl.binding_rule_read(rule.id.unwrap()).0.id, rule.id)
  // A workload holds no Consul token: it trades the JWT it was issued for one.
  let anonymous = @fetch.connect(config={
    ..@moonconsul.default_config,
    address: "127.0.0.1:18500",
  })
  let (token, _) = anonymous
    .acl()
    .token_login({
      auth_method: Some(auth_method_name),
      bearer_token: Some(jwt_login_token()),
      token_metadata: None,
    })
  let secret = match token.secret_id {
    Some(s) => s
    None => fail("the login returned no secret id")
  }
  assert_true(token.roles.unwrap_or([]).iter().any(r => r.name == role.name))
  let leased = @fetch.connect(config={
    ..@moonconsul.default_config,
    address: "127.0.0.1:18500",
    token: Some(secret),
  })
  ignore(
    leased
    .kv()
    .put({
      key: "it/jwt/leased",
      create_index: 0UL,
      modify_index: 0UL,
      lock_index: 0UL,
      flags: 0UL,
      value: b"written by the logged-in token",
      session: None,
    }),
  )
  assert_true(leased.kv().get("it/jwt/leased").0 is Some(_))
  // Logging out ends the token's life.
  ignore(leased.acl().token_logout())
  let refused = try {
    ignore(
      leased
      .kv()
      .put({
        key: "it/jwt/leased",
        create_index: 0UL,
        modify_index: 0UL,
        lock_index: 0UL,
        flags: 0UL,
        value: b"after logout",
        session: None,
      }),
    )
    false
  } catch {
    @moonconsul.Status(403, _) => true
    _ => false
  }
  assert_true(refused)
  ignore(acl.binding_rule_delete(rule.id.unwrap()))
  ignore(acl.auth_method_delete(auth_method_name))
  ignore(acl.role_delete(role.id.unwrap()))
  ignore(acl.policy_delete(policy.id.unwrap()))
  ignore(c.kv().delete_tree("it/jwt"))
}
