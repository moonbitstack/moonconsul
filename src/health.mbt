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
/// A `HealthCheck` from its JSON object.
fn health_check_of(j : Json) -> HealthCheck {
  let m = json_map(j)
  {
    node: jstr(m, "Node"),
    check_id: jstr(m, "CheckID"),
    name: jstr_opt(m, "Name"),
    status: jstr_opt(m, "Status"),
    notes: jstr_opt(m, "Notes"),
    output: jstr_opt(m, "Output"),
    service_id: jstr_opt(m, "ServiceID"),
    service_name: jstr_opt(m, "ServiceName"),
    ns: jstr_opt(m, "Namespace"),
  }
}

///|
/// A `HealthService` from its JSON object.
fn health_service_of(j : Json) -> HealthService {
  let m = json_map(j)
  {
    id: jstr(m, "ID"),
    service: jstr(m, "Service"),
    address: jstr_opt(m, "Address"),
    tags: match jstr_array_opt(m, "Tags") {
      Some(t) => t
      None => []
    },
    meta: jmap_opt(m, "Meta"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    port: ji32_opt(m, "Port"),
    weights: weights_of(m, "Weights"),
  }
}

///|
/// An `AgentService` from its JSON object.
fn agent_service_of(j : Json) -> AgentService {
  let m = json_map(j)
  {
    id: jstr(m, "ID"),
    service: jstr(m, "Service"),
    tags: jstr_array_opt(m, "Tags").unwrap_or([]),
    address: jstr_opt(m, "Address"),
    port: ji32_opt(m, "Port"),
    meta: jmap_opt(m, "Meta"),
    ns: jstr_opt(m, "Namespace"),
    weights: weights_of(m, "Weights"),
  }
}

///|
/// A `ServiceEntry` from its JSON object.
fn service_entry_of(j : Json) -> ServiceEntry {
  let m = json_map(j)
  let node = node_of(
    match m.get("Node") {
      Some(n) => n
      None => @json.to_json(jobj())
    },
  )
  let service = match m.get("Service") {
    Some(s) => if s is Object(_) { Some(health_service_of(s)) } else { None }
    None => None
  }
  let checks : Array[HealthCheck] = []
  for c in jarray(m, "Checks") {
    checks.push(health_check_of(c))
  }
  { node, service, checks, }
}

///|
/// An array of `HealthCheck` from a JSON array body.
fn health_checks_of(j : Json) -> Array[HealthCheck] {
  let out : Array[HealthCheck] = []
  for item in json_array(j) {
    out.push(health_check_of(item))
  }
  out
}

///|
/// The checks on `node`.
pub async fn Health::node(
  self : Health,
  node : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/health/node/" + node, options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  (health_checks_of(json), meta)
}

///|
/// The checks belonging to `service`.
pub async fn Health::checks(
  self : Health,
  service : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get(
    "/v1/health/checks/" + service,
    options,
    [],
  ) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  (health_checks_of(json), meta)
}

///|
/// The checks in `state` (`passing`, `warning` or `critical`).
pub async fn Health::checks_in_state(
  self : Health,
  state : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/health/state/" + state, options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  (health_checks_of(json), meta)
}

///|
/// The healthy instances of `service`; `passing` filters to passing instances
/// only. A blocking query (`QueryOptions.wait_index`) watches the set change.
pub async fn Health::service(
  self : Health,
  service : String,
  passing~ : Bool = false,
  options~ : QueryOptions = default_query_options,
) -> (Array[ServiceEntry], QueryMeta) raise Refused {
  let extra : Array[(String, String)] = []
  if passing {
    extra.push(("passing", "true"))
  }
  let (json, meta) = self.client.do_get(
    "/v1/health/service/" + service,
    options,
    extra,
  ) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ServiceEntry] = []
  for item in json_array(json) {
    out.push(service_entry_of(item))
  }
  (out, meta)
}

///|
/// The checks in `state` (any of the three states).
pub async fn Health::state(
  self : Health,
  state : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[HealthCheck], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/health/state/" + state, options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  (health_checks_of(json), meta)
}

///|
/// Like `service`, but only instances reachable over the connect mesh.
pub async fn Health::connect_service(
  self : Health,
  service : String,
  passing~ : Bool = false,
  options~ : QueryOptions = default_query_options,
) -> (Array[ServiceEntry], QueryMeta) raise Refused {
  let extra : Array[(String, String)] = []
  if passing {
    extra.push(("passing", "true"))
  }
  let (json, meta) = self.client.do_get(
    "/v1/health/connect/" + service,
    options,
    extra,
  ) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ServiceEntry] = []
  for item in json_array(json) {
    out.push(service_entry_of(item))
  }
  (out, meta)
}
