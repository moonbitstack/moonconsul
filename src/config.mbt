///|
/// TLS settings for an HTTPS agent. The three file paths point at a CA bundle,
/// a client certificate, and its key; `insecure_skip_verify` turns certificate
/// checking off and is for development against a self-signed agent only.
pub(all) struct TlsConfig {
  ca_file : String?
  cert_file : String?
  key_file : String?
  insecure_skip_verify : Bool
}

///|
/// The default TLS settings: no client certificates and verification on.
pub let default_tls : TlsConfig = {
  ca_file: None,
  cert_file: None,
  key_file: None,
  insecure_skip_verify: false,
}

///|
/// A Consul client configuration. `address` is `host:port`; `scheme` is `http`
/// or `https`. `datacenter`, `namespace` and `token` are the defaults applied to
/// every call unless a call's own options override them. `wait_time` bounds a
/// blocking query when `QueryOptions.wait_time` is unset. `transport` overrides
/// the default `moonfetch`-backed medium; tests pass an in-memory fake.
pub(all) struct Config {
  address : String
  scheme : String
  datacenter : String?
  ns : String?
  token : String?
  wait_time : Int64
  consistency : ConsistencyMode
  tls : TlsConfig
  transport : &Transport?
}

///|
/// The default configuration: `http://127.0.0.1:8500`, no datacenter,
/// namespace or token, a default-consistency read, and no transport override.
pub let default_config : Config = {
  address: "127.0.0.1:8500",
  scheme: "http",
  datacenter: None,
  ns: None,
  token: None,
  wait_time: 0,
  consistency: Default,
  tls: default_tls,
  transport: None,
}

///|
/// A configuration targeting `address`, with the remaining fields at their
/// defaults.
pub fn config_with_address(address : String) -> Config {
  { ..default_config, address, }
}

///|
/// A Consul client. It carries a `Config` and the `Transport` that performs the
/// HTTP calls, and hands out one handle per API group; each handle shares this
/// client, so a token or datacenter set on the client applies across groups.
pub struct Client {
  config : Config
  transport : &Transport
}

///|
/// A client over `config` and `transport`.
pub fn Client::new(config : Config, transport : &Transport) -> Client {
  { config, transport, }
}

///|
/// A client targeting `address` over `transport`, with the rest at defaults.
pub fn Client::with_address(address : String, transport : &Transport) -> Client {
  { config: config_with_address(address), transport, }
}

///|
/// The Agent API: service and check lifecycle on this agent.
pub fn Client::agent(self : Client) -> Agent {
  { client: self, }
}

///|
/// The Catalog API: datacenter-wide node and service registration.
pub fn Client::catalog(self : Client) -> Catalog {
  { client: self, }
}

///|
/// The Health API: checks and the healthy instances of a service.
pub fn Client::health(self : Client) -> Health {
  { client: self, }
}

///|
/// The KV API: the key/value store, with compare-and-swap, locks and
/// semaphores.
pub fn Client::kv(self : Client) -> KV {
  { client: self, }
}

///|
/// The Session API: sessions that back locks and semaphores.
pub fn Client::session(self : Client) -> Session {
  { client: self, }
}

///|
/// The Event API: user events fanned out across the datacenter.
pub fn Client::event(self : Client) -> Event {
  { client: self, }
}

///|
/// The ACL API: tokens, policies, roles, auth methods and binding rules.
pub fn Client::acl(self : Client) -> ACL {
  { client: self, }
}

///|
/// The Status API: leader and peer membership.
pub fn Client::status(self : Client) -> Status {
  { client: self, }
}

///|
/// The Coordinate API: network coordinates for latency-aware routing.
pub fn Client::coordinate(self : Client) -> Coordinate {
  { client: self, }
}

///|
/// The Prepared Query API: named and templated service queries.
pub fn Client::prepared_query(self : Client) -> PreparedQuery {
  { client: self, }
}

///|
/// The Config Entries API: centralized configuration objects.
pub fn Client::config_entries(self : Client) -> ConfigEntries {
  { client: self, }
}

///|
/// The Connect API: the certificate authority and the intentions that decide
/// which services may talk to which.
pub fn Client::connect(self : Client) -> Connect {
  { client: self, }
}
