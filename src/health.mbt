///|
/// A handle to the Health API: checks and the healthy instances of a service,
/// including blocking queries that watch a service for membership changes.
pub struct Health {
  client : Client
}

///|
/// A check as reported by the health endpoints: its `check_id`, `name`, current
/// `status`, and `output`.
pub(all) struct HealthCheck {
  node : String
  check_id : String
  name : String?
  status : String?
  notes : String?
  output : String?
  service_id : String?
  service_name : String?
  ns : String?
}

///|
/// One instance of a service as returned by `service` and `connect_service`,
/// paired with the node it runs on and its live checks.
pub(all) struct HealthService {
  id : String
  service : String
  address : String?
  tags : Array[String]
  meta : Map[String, String]?
  ns : String?
  partition : String?
  port : Int32?
  weights : AgentWeights?
}

///|
/// A healthy service instance: the `node` it runs on, the `service` instance,
/// and its `checks`.
pub(all) struct ServiceEntry {
  node : Node
  service : HealthService?
  checks : Array[HealthCheck]
}

///|
/// The checks on `node`.
pub fn Health::node(
  self : Health,
  node : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let _ = (self, node, options)
  raise Refused::Unimplemented("health.node")
}

///|
/// The checks belonging to `service`.
pub fn Health::checks(
  self : Health,
  service : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let _ = (self, service, options)
  raise Refused::Unimplemented("health.checks")
}

///|
/// The checks in `state` (`passing`, `warning` or `critical`).
pub fn Health::checks_in_state(
  self : Health,
  state : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let _ = (self, state, options)
  raise Refused::Unimplemented("health.checks_in_state")
}

///|
/// The healthy instances of `service`; `passing` filters to passing instances
/// only. A blocking query (`QueryOptions.wait_index`) watches the set change.
pub fn Health::service(
  self : Health,
  service : String,
  passing~ : Bool = false,
  options~ : QueryOptions = default_query_options,
) -> (Array[ServiceEntry], QueryMeta) raise Refused {
  let _ = (self, service, passing, options)
  raise Refused::Unimplemented("health.service")
}

///|
/// The checks in `state` (any of the three states).
pub fn Health::state(
  self : Health,
  state : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let _ = (self, state, options)
  raise Refused::Unimplemented("health.state")
}

///|
/// Like `service`, but only instances reachable over the connect mesh.
pub fn Health::connect_service(
  self : Health,
  service : String,
  passing~ : Bool = false,
  options~ : QueryOptions = default_query_options,
) -> (Array[ServiceEntry], QueryMeta) raise Refused {
  let _ = (self, service, passing, options)
  raise Refused::Unimplemented("health.connect_service")
}
