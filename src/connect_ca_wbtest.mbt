// White-box tests for the Connect certificate authority: the roots an agent
// trusts, the leaf an agent issues, the authorization body, and the CA
// configuration. The fake transport replays bodies copied from a live agent, so
// the parsing is checked against the real wire format.

///|
fn root_json() -> String {
  "{\"ActiveRootID\":\"aa:bb\",\"TrustDomain\":\"cluster.consul\",\"Roots\":[{\"ID\":\"aa:bb\",\"Name\":\"Consul CA Primary Cert\",\"SerialNumber\":7,\"SigningKeyID\":\"cc:dd\",\"ExternalTrustDomain\":\"cluster\",\"NotBefore\":\"2026-01-01T00:00:00Z\",\"NotAfter\":\"2036-01-01T00:00:00Z\",\"RootCert\":\"-----BEGIN CERTIFICATE-----\\nMIIB\\n-----END CERTIFICATE-----\\n\",\"IntermediateCerts\":[\"-----BEGIN CERTIFICATE-----\\nMIIC\\n-----END CERTIFICATE-----\\n\"],\"Active\":true,\"PrivateKeyType\":\"ec\",\"PrivateKeyBits\":256,\"CreateIndex\":5,\"ModifyIndex\":9}]}"
}

///|
async test "connect.ca_roots reads the trust domain and the active root" {
  let fake = FakeTransport::one(json_response_at(root_json(), 9UL))
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (roots, meta) = client.connect().ca_roots()
  assert_eq(roots.trust_domain, "cluster.consul")
  assert_eq(roots.active_root_id, "aa:bb")
  assert_eq(roots.roots.length(), 1)
  let root = roots.roots[0]
  assert_eq(root.serial_number, 7UL)
  assert_eq(root.active, true)
  assert_eq(root.intermediate_cert_pems.length(), 1)
  assert_eq(root.private_key_bits, Some(256))
  assert_eq(meta.last_index, 9UL)
  let req = fake.last().unwrap()
  assert_eq(req.verb, "GET")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/connect/ca/roots")
}

///|
async test "agent.connect_leaf encodes the service name as a path segment" {
  let fake = FakeTransport::one(
    json_response(
      "{\"SerialNumber\":\"0e\",\"CertPEM\":\"-----BEGIN CERTIFICATE-----\",\"PrivateKeyPEM\":\"-----BEGIN EC PRIVATE KEY-----\",\"Service\":\"web 2\",\"ServiceURI\":\"spiffe://cluster.consul/ns/default/dc/dc1/svc/web 2\",\"ValidAfter\":\"2026-11-05T09:15:19Z\",\"ValidBefore\":\"2026-11-08T09:15:19Z\",\"CreateIndex\":23,\"ModifyIndex\":23}",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (leaf, _) = client.agent().connect_leaf("web 2")
  assert_eq(leaf.service, "web 2")
  assert_eq(
    leaf.service_uri,
    "spiffe://cluster.consul/ns/default/dc/dc1/svc/web 2",
  )
  assert_eq(leaf.serial_number, "0e")
  let req = fake.last().unwrap()
  assert_eq(req.url, "http://127.0.0.1:8500/v1/agent/connect/ca/leaf/web%202")
}

///|
async test "agent.connect_authorize sends the certificate it was given" {
  let fake = FakeTransport::one(
    json_response(
      "{\"Authorized\":true,\"Reason\":\"Matched L4 intention: default/web => default/db (Precedence: 9, Action: ALLOW)\"}",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (decision, _) = client
    .agent()
    .connect_authorize({
      target: "db",
      client_cert_uri: "spiffe://cluster.consul/ns/default/dc/dc1/svc/web",
      client_cert_serial: "0e",
    })
  assert_true(decision.authorized)
  assert_true(decision.reason.contains("Action: ALLOW"))
  let req = fake.last().unwrap()
  assert_eq(req.verb, "POST")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/agent/connect/authorize")
  let body = @json.parse(bytes_text(req.body)) catch {
    e => abort("the body is not JSON: \{e}")
  }
  assert_eq(
    body,
    Json::object(
      Map([
        ("Target", Json::string("db")),
        (
          "ClientCertURI",
          Json::string("spiffe://cluster.consul/ns/default/dc/dc1/svc/web"),
        ),
        ("ClientCertSerial", Json::string("0e")),
      ]),
    ),
  )
}

///|
async test "connect.ca_config reads the provider and its settings" {
  let fake = FakeTransport::one(
    json_response(
      "{\"Provider\":\"consul\",\"Config\":{\"LeafCertTTL\":\"72h\",\"RootCertTTL\":\"87600h\"},\"State\":null,\"ForceWithoutCrossSigning\":false,\"CreateIndex\":5,\"ModifyIndex\":9}",
    ),
  )
  let client = Client::with_address("127.0.0.1:8500", fake)
  let (config, _) = client.connect().ca_config()
  assert_eq(config.provider, "consul")
  let settings = config.config.unwrap()
  assert_eq(settings.get("LeafCertTTL"), Some(Json::string("72h")))
  assert_eq(config.force_without_cross_signing, false)
}

///|
async test "connect.ca_set_config writes the settings and never the state" {
  let fake = FakeTransport::one(ok_response())
  let client = Client::with_address("127.0.0.1:8500", fake)
  let config = {
    ..CAConfig::new("consul"),
    config: Some(Map([("LeafCertTTL", Json::string("72h"))])),
    state: Some(Map([("RootCertID", "aa:bb")])),
  }
  let _ = client.connect().ca_set_config(config)
  let req = fake.last().unwrap()
  assert_eq(req.verb, "PUT")
  assert_eq(req.url, "http://127.0.0.1:8500/v1/connect/ca/configuration")
  let body = @json.parse(bytes_text(req.body)) catch {
    e => abort("the body is not JSON: \{e}")
  }
  let sent = json_map(body)
  assert_eq(sent.get("Provider"), Some(Json::string("consul")))
  assert_eq(sent.get("ForceWithoutCrossSigning"), Some(Json::boolean(false)))
  assert_eq(sent.get("State"), None)
}
