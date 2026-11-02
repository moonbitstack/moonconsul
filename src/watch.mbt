///|
/// What a blocking read can follow, in the words of Consul's own watch types.
pub(all) enum WatchKind {
  /// One key.
  Key(String)
  /// Every key under a prefix.
  KeyPrefix(String)
  /// The services in the catalog.
  Services
  /// The nodes in the catalog.
  Nodes
  /// The instances of a service with their health.
  Service(String, passing~ : Bool)
  /// The checks of a service.
  Checks(String)
  /// The checks in a state: `any`, `passing`, `warning` or `critical`.
  State(String)
  /// The events of a name.
  Event(String)
  /// The certificate authority's roots.
  ConnectRoots
  /// The leaf certificate of a service.
  ConnectLeaf(String)
  /// A service on this agent, by id. It blocks on a hash, not an index.
  AgentService(String)
}

///|
fn watch_request(kind : WatchKind) -> (String, Array[(String, String)]) {
  match kind {
    Key(key) => ("/v1/kv/" + key, [])
    KeyPrefix(prefix) => ("/v1/kv/" + prefix, [("recurse", "")])
    Services => ("/v1/catalog/services", [])
    Nodes => ("/v1/catalog/nodes", [])
    Service(name, passing~) =>
      (
        "/v1/health/service/" + name,
        if passing {
          [("passing", "")]
        } else {
          []
        },
      )
    Checks(name) => ("/v1/health/checks/" + name, [])
    State(state) => ("/v1/health/state/" + state, [])
    Event(name) => ("/v1/event/list", [("name", name)])
    ConnectRoots => ("/v1/agent/connect/ca/roots", [])
    ConnectLeaf(name) => ("/v1/agent/connect/ca/leaf/" + name, [])
    AgentService(id) => ("/v1/agent/service/" + id, [])
  }
}

///|
/// One read of `kind`, as raw JSON, blocking as `options` says. `None` is a 404,
/// which is what a key answers until it exists. `@concurrency.watch` is the loop
/// around this.
pub async fn Client::poll(
  self : Client,
  kind : WatchKind,
  options~ : QueryOptions = default_query_options,
) -> (Json?, QueryMeta) raise Refused {
  let (path, extra) = watch_request(kind)
  self.do_get_found(path, options, extra)
}
