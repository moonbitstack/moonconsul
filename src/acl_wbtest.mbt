// White-box tests for the ACL endpoints the login flow uses: the login body
// the agent validates a bearer token from, and the logout that ends the token
// it issued.

///|
async test "acl.token_login sends the method and the bearer token" {
  let fake = FakeTransport::one(
    json_response(
      "{\"AccessorID\":\"aa\",\"SecretID\":\"ss\",\"Description\":\"token created via login\",\"Roles\":[{\"ID\":\"rr\",\"Name\":\"jwt-role\"}],\"Local\":true,\"AuthMethod\":\"jwt-it\"}",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (token, _) = client
    .acl()
    .token_login({
      auth_method: Some("jwt-it"),
      bearer_token: Some("header.payload.signature"),
      token_metadata: Some(Map([("env", "ci")])),
    })
  assert_eq(token.secret_id, Some("ss"))
  assert_eq(token.roles.unwrap_or([])[0].name, Some("jwt-role"))
  let req = fake.last().unwrap()
  assert_eq(req.verb, "POST")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/acl/login")
  let body = @json.parse(bytes_text(req.body)) catch {
    e => abort("the body is not JSON: \{e}")
  }
  assert_eq(
    body,
    Json::object(
      Map([
        ("AuthMethod", Json::string("jwt-it")),
        ("BearerToken", Json::string("header.payload.signature")),
        ("Meta", Json::object(Map([("env", Json::string("ci"))]))),
      ]),
    ),
  )
}

///|
async test "acl.token_logout posts with the token it ends" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let _ = client
    .acl()
    .token_logout(options={ ..default_write_options, token: Some("ss"), })
  let req = fake.last().unwrap()
  assert_eq(req.verb, "POST")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/acl/logout")
  assert_eq(req.headers.get("X-Consul-Token"), Some("ss"))
}

///|
async test "acl.auth_method_create sends a config that mixes lists and maps" {
  let fake = FakeTransport::one(
    json_response("{\"Name\":\"jwt-it\",\"Type\":\"jwt\"}"),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (created, _) = client
    .acl()
    .auth_method_create({
      name: Some("jwt-it"),
      kind: Some("jwt"),
      description: None,
      config: Some(
        Map([
          (
            "JWTValidationPubkeys",
            Json::array([Json::string("-----BEGIN PUBLIC KEY-----")]),
          ),
        ]),
      ),
      ns: None,
      partition: None,
    })
  assert_eq(created.kind, Some("jwt"))
  let body = @json.parse(bytes_text(fake.last().unwrap().body)) catch {
    e => abort("the body is not JSON: \{e}")
  }
  let sent = json_map(body)
  assert_eq(sent.get("Type"), Some(Json::string("jwt")))
  let config = json_map(sent.get("Config").unwrap())
  assert_eq(
    config.get("JWTValidationPubkeys"),
    Some(Json::array([Json::string("-----BEGIN PUBLIC KEY-----")])),
  )
}
