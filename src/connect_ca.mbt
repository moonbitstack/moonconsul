// The Connect certificate authority: the roots an agent trusts, the leaf
// certificate an agent issues for a service, and the cluster-wide CA
// configuration. A leaf's identity is its SPIFFE URI, which is what a proxy
// presents and what `Agent::connect_authorize` decides on.

///|
/// One trusted root certificate of the Connect CA.
pub(all) struct CARoot {
  /// The root's globally unique id, also its certificate serial in hex.
  id : String
  /// A human-friendly name; Consul does not interpret it.
  name : String
  /// The certificate serial number.
  serial_number : UInt64
  /// The id of the key that signed this root.
  signing_key_id : String
  /// The trust domain of the Consul cluster that owns the root.
  external_trust_domain : String
  /// The start of the root's validity, as the agent reports it.
  not_before : String?
  /// The end of the root's validity.
  not_after : String?
  /// The PEM-encoded root certificate.
  root_cert_pem : String
  /// The PEM-encoded intermediates between the root and a leaf, if any.
  intermediate_cert_pems : Array[String]
  /// Whether this is the root the CA signs with now.
  active : Bool
  /// The key type, e.g. `ec`.
  private_key_type : String?
  /// The key size in bits.
  private_key_bits : Int32?
  create_index : UInt64
  modify_index : UInt64
}

///|
/// The roots an agent trusts: the active root's id, the trust domain every
/// SPIFFE identity of the cluster sits under, and the roots themselves.
pub(all) struct CARoots {
  active_root_id : String
  trust_domain : String
  roots : Array[CARoot]
}

///|
/// A leaf certificate the CA issued for one service: the PEM certificate and
/// key, and the SPIFFE identity they carry.
pub(all) struct LeafCert {
  /// The serial number in hex, colon-separated.
  serial_number : String
  /// The PEM-encoded certificate.
  cert_pem : String
  /// The PEM-encoded private key.
  private_key_pem : String
  /// The service the certificate was issued for.
  service : String
  /// The SPIFFE identity in the certificate, e.g.
  /// `spiffe://<trust domain>/ns/default/dc/dc1/svc/web`.
  service_uri : String
  /// The start of the certificate's validity.
  valid_after : String?
  /// The end of the certificate's validity.
  valid_before : String?
  create_index : UInt64
  modify_index : UInt64
}

///|
/// The cluster-wide Connect CA configuration: the provider that signs, its
/// arbitrary settings, and the read-only state the provider persisted.
pub(all) struct CAConfig {
  /// The CA provider, e.g. `consul` or `vault`.
  provider : String
  /// Provider settings, held as the JSON the agent serves so that any
  /// provider's shape round-trips.
  config : Map[String, Json]?
  /// State the provider persisted; the agent sets it and rejects it on a write.
  state : Map[String, String]?
  /// Reconfigure even when the current CA cannot cross-sign, accepting that
  /// proxies may reject the new leaves until they see the new root.
  force_without_cross_signing : Bool
  create_index : UInt64
  modify_index : UInt64
}

///|
/// A CA configuration for `provider`, with no settings and cross-signing
/// required.
pub fn CAConfig::new(provider : String) -> CAConfig {
  {
    provider,
    config: None,
    state: None,
    force_without_cross_signing: false,
    create_index: 0UL,
    modify_index: 0UL,
  }
}

///|
/// The parameters of an authorization decision: the service a connection is
/// headed for, and the SPIFFE identity and serial the client presented.
pub(all) struct AgentAuthorizeParams {
  /// The destination service name.
  target : String
  /// The client certificate's SPIFFE URI.
  client_cert_uri : String
  /// The client certificate's serial number.
  client_cert_serial : String
}

///|
/// The answer to an authorization request, with the agent's reason.
pub(all) struct AgentAuthorize {
  authorized : Bool
  reason : String
}

///|
/// A `CARoot` from its JSON object.
fn caroot_of(j : Json) -> CARoot {
  let m = json_map(j)
  let intermediates : Array[String] = []
  for item in jarray(m, "IntermediateCerts") {
    if item is String(s) {
      intermediates.push(s)
    }
  }
  {
    id: jstr(m, "ID"),
    name: jstr(m, "Name"),
    serial_number: ju64(m, "SerialNumber"),
    signing_key_id: jstr(m, "SigningKeyID"),
    external_trust_domain: jstr(m, "ExternalTrustDomain"),
    not_before: jstr_opt(m, "NotBefore"),
    not_after: jstr_opt(m, "NotAfter"),
    root_cert_pem: jstr(m, "RootCert"),
    intermediate_cert_pems: intermediates,
    active: jbool(m, "Active"),
    private_key_type: jstr_opt(m, "PrivateKeyType"),
    private_key_bits: ji32_opt(m, "PrivateKeyBits"),
    create_index: ju64(m, "CreateIndex"),
    modify_index: ju64(m, "ModifyIndex"),
  }
}

///|
/// A `CARoots` from its JSON object.
fn caroots_of(j : Json) -> CARoots {
  let m = json_map(j)
  let roots : Array[CARoot] = []
  for item in jarray(m, "Roots") {
    roots.push(caroot_of(item))
  }
  {
    active_root_id: jstr(m, "ActiveRootID"),
    trust_domain: jstr(m, "TrustDomain"),
    roots,
  }
}

///|
/// A `LeafCert` from its JSON object.
fn leaf_cert_of(j : Json) -> LeafCert {
  let m = json_map(j)
  {
    serial_number: jstr(m, "SerialNumber"),
    cert_pem: jstr(m, "CertPEM"),
    private_key_pem: jstr(m, "PrivateKeyPEM"),
    service: jstr(m, "Service"),
    service_uri: jstr(m, "ServiceURI"),
    valid_after: jstr_opt(m, "ValidAfter"),
    valid_before: jstr_opt(m, "ValidBefore"),
    create_index: ju64(m, "CreateIndex"),
    modify_index: ju64(m, "ModifyIndex"),
  }
}

///|
/// A `CAConfig` from its JSON object.
fn ca_config_of(j : Json) -> CAConfig {
  let m = json_map(j)
  {
    provider: jstr(m, "Provider"),
    config: jobj_opt(m, "Config"),
    state: jmap_opt(m, "State"),
    force_without_cross_signing: jbool(m, "ForceWithoutCrossSigning"),
    create_index: ju64(m, "CreateIndex"),
    modify_index: ju64(m, "ModifyIndex"),
  }
}

///|
/// A `CAConfig` as its write body. `state` is left out: the agent writes it and
/// rejects a configuration that carries one.
fn ca_config_to_json(c : CAConfig) -> Json {
  let m = jobj()
  put_str(m, "Provider", Some(c.provider))
  m["Config"] = Json::object(
    match c.config {
      Some(cf) => cf
      None => Map([])
    },
  )
  put_bool(m, "ForceWithoutCrossSigning", Some(c.force_without_cross_signing))
  Json::object(m)
}

///|
/// An `AgentAuthorizeParams` as its request body.
fn agent_authorize_params_to_json(p : AgentAuthorizeParams) -> Json {
  let m = jobj()
  put_str(m, "Target", Some(p.target))
  put_str(m, "ClientCertURI", Some(p.client_cert_uri))
  put_str(m, "ClientCertSerial", Some(p.client_cert_serial))
  Json::object(m)
}

///|
/// An `AgentAuthorize` from its JSON object.
fn agent_authorize_of(j : Json) -> AgentAuthorize {
  let m = json_map(j)
  { authorized: jbool(m, "Authorized"), reason: jstr(m, "Reason"), }
}
