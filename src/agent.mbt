///|
/// A handle to the Agent API: register and deregister services and checks on
/// this agent, keep TTL checks alive, read the agent's own state, and manage
/// cluster membership and maintenance mode.
pub struct Agent {
  client : Client
}

///|
/// A health check registered alongside a service or on its own. One of `ttl`,
/// `interval`+`script`/`http`/`tcp`/`grpc`, or `alias_*` selects the check
/// kind; `deregister_critical_service_after` lets a failing check auto-remove
/// its service.
pub(all) struct AgentServiceCheck {
  id : String?
  name : String?
  notes : String?
  service_id : String?
  status : String?
  ttl : String?
  interval : String?
  timeout : String?
  http : String?
  tls_skip_verify : Bool?
  http_method : String?
  tcp : String?
  grpc : String?
  grpc_use_tls : Bool?
  header : Map[String, Array[String]]?
  deregister_critical_service_after : String?
  alias_node : String?
  alias_service : String?
  success_before_passing : Int32?
  failures_before_critical : Int32?
}

///|
/// The primary and passing weights of a service, used by DNS and prepared
/// queries. `passing` defaults to 1 and `warning` to 1 when unset.
pub(all) struct AgentWeights {
  passing : Int32?
  warning : Int32?
}

///|
/// A service registered on this agent. `id` defaults to `name` when empty; `tags`
/// and `meta` are free-form; `address` and `port` are where the instance listens
/// (when unset, the agent's address is used).
pub(all) struct AgentService {
  id : String
  service : String
  tags : Array[String]
  address : String?
  port : Int32?
  meta : Map[String, String]?
  ns : String?
  weights : AgentWeights?
}

///|
/// The body of `PUT /v1/agent/service/register`: a service plus at most one
/// inline check (`check`) or several (`checks`); `enable_tag_override` lets the
/// agent's tags be overridden by the catalog.
pub(all) struct AgentServiceRegistration {
  id : String?
  name : String
  tags : Array[String]?
  address : String?
  port : Int32?
  meta : Map[String, String]?
  ns : String?
  check : AgentServiceCheck?
  checks : Array[AgentServiceCheck]?
  enable_tag_override : Bool?
  weights : AgentWeights?
}

///|
/// The body of `PUT /v1/agent/check/register`: the identity fields plus the
/// check definition folded in as `definition`.
pub(all) struct AgentCheckRegistration {
  id : String?
  name : String
  notes : String?
  service_id : String?
  service_name : String?
  ns : String?
  status : String?
  definition : AgentServiceCheck
}

///|
/// A check as reported by `self` and the check endpoints: its id, name, current
/// `status` (`passing`, `warning`, `critical`), `output`, and the service it
/// guards.
pub(all) struct AgentCheck {
  id : String
  name : String?
  status : String?
  notes : String?
  output : String?
  service_id : String?
  service_name : String?
  ns : String?
}

///|
/// The body of `PUT /v1/agent/check/update`: set a TTL check's `status` and
/// `output` without sending a fresh TTL. `check_id` names the check to update.
pub(all) struct AgentCheckUpdate {
  check_id : String
  status : String
  output : String?
}

///|
/// A cluster member as seen by the agent's gossip layer: its `name`, `addr`,
/// `port`, `status`, and the `tags` it gossips (including `role`, `dc`, `vsn`).
pub(all) struct AgentMember {
  name : String
  addr : String
  port : Int32
  tags : Map[String, String]?
  status : String?
}

///|
/// The agent's own state: its `config`, its `agent_member` record, and `stats`.
pub(all) struct AgentSelf {
  config : Json
  agent_member : AgentMember
  stats : Json
}

///|
/// An `AgentWeights` as a JSON object.
fn agent_weights_to_json(w : AgentWeights) -> Json {
  let m = jobj()
  put_i32(m, "Passing", w.passing)
  put_i32(m, "Warning", w.warning)
  @json.to_json(m)
}

///|
/// A `Map[String, Array[String]]` (check headers) as a JSON object.
fn headers_to_json(h : Map[String, Array[String]]) -> Json {
  let out : Map[String, Json] = Map([])
  for k, v in h {
    let arr : Array[Json] = []
    for s in v {
      arr.push(@json.to_json(s))
    }
    out[k] = @json.to_json(arr)
  }
  @json.to_json(out)
}

///|
/// An `AgentServiceCheck` as a JSON object.
fn agent_service_check_to_json(c : AgentServiceCheck) -> Json {
  let m = jobj()
  put_str(m, "CheckID", c.id)
  put_str(m, "Name", c.name)
  put_str(m, "Notes", c.notes)
  put_str(m, "ServiceID", c.service_id)
  put_str(m, "Status", c.status)
  put_str(m, "TTL", c.ttl)
  put_str(m, "Interval", c.interval)
  put_str(m, "Timeout", c.timeout)
  put_str(m, "HTTP", c.http)
  put_bool(m, "TLSSkipVerify", c.tls_skip_verify)
  put_str(m, "Method", c.http_method)
  put_str(m, "TCP", c.tcp)
  put_str(m, "GRPC", c.grpc)
  put_bool(m, "GRPCUseTLS", c.grpc_use_tls)
  match c.header {
    Some(h) => m["Header"] = headers_to_json(h)
    None => ()
  }
  put_str(
    m,
    "DeregisterCriticalServiceAfter",
    c.deregister_critical_service_after,
  )
  put_str(m, "AliasNode", c.alias_node)
  put_str(m, "AliasService", c.alias_service)
  put_i32(m, "SuccessBeforePassing", c.success_before_passing)
  put_i32(m, "FailuresBeforeCritical", c.failures_before_critical)
  @json.to_json(m)
}

///|
/// An `AgentServiceRegistration` as its write body.
fn agent_service_registration_to_json(r : AgentServiceRegistration) -> Json {
  let m = jobj()
  put_str(m, "ID", r.id)
  put_str(m, "Name", Some(r.name))
  put_str_array(m, "Tags", r.tags)
  put_str(m, "Address", r.address)
  put_i32(m, "Port", r.port)
  match r.meta {
    Some(mm) => m["Meta"] = map_to_json(mm)
    None => ()
  }
  put_str(m, "Namespace", r.ns)
  match r.check {
    Some(c) => m["Check"] = agent_service_check_to_json(c)
    None => ()
  }
  match r.checks {
    Some(cs) => {
      let arr : Array[Json] = []
      for c in cs {
        arr.push(agent_service_check_to_json(c))
      }
      m["Checks"] = @json.to_json(arr)
    }
    None => ()
  }
  put_bool(m, "EnableTagOverride", r.enable_tag_override)
  match r.weights {
    Some(w) => m["Weights"] = agent_weights_to_json(w)
    None => ()
  }
  @json.to_json(m)
}

///|
/// An `AgentCheckRegistration` as its write body (the definition folded in).
fn agent_check_registration_to_json(r : AgentCheckRegistration) -> Json {
  let m = json_map(agent_service_check_to_json(r.definition))
  put_str(m, "CheckID", r.id)
  put_str(m, "Name", Some(r.name))
  put_str(m, "Notes", r.notes)
  put_str(m, "ServiceID", r.service_id)
  put_str(m, "ServiceName", r.service_name)
  put_str(m, "Namespace", r.ns)
  put_str(m, "Status", r.status)
  @json.to_json(m)
}

///|
/// An `AgentMember` from its JSON object.
fn agent_member_of(j : Json) -> AgentMember {
  let m = json_map(j)
  {
    name: jstr(m, "Name"),
    addr: jstr(m, "Addr"),
    port: ji32(m, "Port"),
    tags: jmap_opt(m, "Tags"),
    status: jstr_opt(m, "Status"),
  }
}

///|
/// An `AgentSelf` from its JSON object.
fn agent_self_of(j : Json) -> AgentSelf {
  let m = json_map(j)
  let mem_rec = agent_member_of(
    match m.get("Member") {
      Some(x) => x
      None => @json.to_json(jobj())
    },
  )
  {
    config: match m.get("Config") {
      Some(c) => c
      None => @json.to_json(jobj())
    },
    agent_member: mem_rec,
    stats: match m.get("Stats") {
      Some(s) => s
      None => @json.to_json(jobj())
    },
  }
}

///|
/// Register `reg` with this agent. A service with an inline TTL check starts
/// `critical`; follow with `check_pass` to make it healthy.
pub fn Agent::service_register(
  self : Agent,
  reg : AgentServiceRegistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(agent_service_registration_to_json(reg).stringify())
  let (_, meta) = self.client.do_put(
    "/v1/agent/service/register",
    body,
    options,
    [],
  )
  meta
}

///|
/// Deregister the service instance `id` from this agent.
pub fn Agent::service_deregister(
  self : Agent,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/service/deregister/" + id,
    b"",
    options,
    [],
  )
  meta
}

///|
/// Register `reg` (a check, optionally bound to a service) with this agent.
pub fn Agent::check_register(
  self : Agent,
  reg : AgentCheckRegistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(agent_check_registration_to_json(reg).stringify())
  let (_, meta) = self.client.do_put(
    "/v1/agent/check/register",
    body,
    options,
    [],
  )
  meta
}

///|
/// Deregister the check `check_id` from this agent.
pub fn Agent::check_deregister(
  self : Agent,
  check_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/check/deregister/" + check_id,
    b"",
    options,
    [],
  )
  meta
}

///|
/// Mark the TTL/http/tcp/grpc check `check_id` passing; the keep-alive that
/// renews a service's lease.
pub fn Agent::check_pass(
  self : Agent,
  check_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/check/pass/" + check_id,
    b"",
    options,
    [],
  )
  meta
}

///|
/// Mark the check `check_id` failing.
pub fn Agent::check_fail(
  self : Agent,
  check_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/check/fail/" + check_id,
    b"",
    options,
    [],
  )
  meta
}

///|
/// Set a TTL check's `status` and `output` without resetting its TTL clock.
pub fn Agent::check_update(
  self : Agent,
  update : AgentCheckUpdate,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let m = jobj()
  put_str(m, "Status", Some(update.status))
  put_str(m, "Output", update.output)
  let body = @utf8.encode(@json.to_json(m).stringify())
  let (_, meta) = self.client.do_put(
    "/v1/agent/check/update/" + update.check_id,
    body,
    options,
    [],
  )
  meta
}

///|
/// The agent's own configuration, member record and runtime stats.
pub fn Agent::self(
  self : Agent,
  options~ : QueryOptions = default_query_options,
) -> (AgentSelf, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/agent/self", options, [])
  (agent_self_of(json), meta)
}

///|
/// The cluster members this agent gossips with. `options.filter` (a
/// go-compatible tag expression) narrows the returned set.
pub fn Agent::members(
  self : Agent,
  options~ : QueryOptions = default_query_options,
) -> (Array[AgentMember], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/agent/members", options, [])
  let out : Array[AgentMember] = []
  for item in json_array(json) {
    out.push(agent_member_of(item))
  }
  (out, meta)
}

///|
/// Like `members`, but `filter` is required rather than optional.
pub fn Agent::members_with_filter(
  self : Agent,
  filter : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[AgentMember], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/agent/members", options, [
    ("filter", filter),
  ])
  let out : Array[AgentMember] = []
  for item in json_array(json) {
    out.push(agent_member_of(item))
  }
  (out, meta)
}

///|
/// Ask the agent at `address` to join the cluster; `wan` joins over the WAN
/// gossip pool rather than the LAN pool.
pub fn Agent::join(
  self : Agent,
  address : String,
  wan~ : Bool = false,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let extra : Array[(String, String)] = []
  if wan {
    extra.push(("wan", "1"))
  }
  let (_, meta) = self.client.do_put(
    "/v1/agent/join/" + address,
    b"",
    options,
    extra,
  )
  meta
}

///|
/// Ask this agent to leave the cluster gracefully.
pub fn Agent::leave(
  self : Agent,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put("/v1/agent/leave", b"", options, [])
  meta
}

///|
/// Force a `node` out of the cluster without its cooperation.
pub fn Agent::force_leave(
  self : Agent,
  node : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/force-leave/" + node,
    b"",
    options,
    [],
  )
  meta
}

///|
/// Put the service instance `service_id` into maintenance mode, marking its
/// checks `maintenance` with `reason`; the instance stays registered but looks
/// down to health checks.
pub fn Agent::enable_service_maintenance(
  self : Agent,
  service_id : String,
  reason~ : String = "",
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let extra : Array[(String, String)] = [("enable", "true")]
  if reason != "" {
    extra.push(("reason", reason))
  }
  let (_, meta) = self.client.do_put(
    "/v1/agent/service/maintenance/" + service_id,
    b"",
    options,
    extra,
  )
  meta
}

///|
/// Take the service instance `service_id` out of maintenance mode.
pub fn Agent::disable_service_maintenance(
  self : Agent,
  service_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/service/maintenance/" + service_id,
    b"",
    options,
    [("enable", "false")],
  )
  meta
}

///|
/// Put the whole node into maintenance mode.
pub fn Agent::enable_node_maintenance(
  self : Agent,
  reason~ : String = "",
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let extra : Array[(String, String)] = [("enable", "true")]
  if reason != "" {
    extra.push(("reason", reason))
  }
  let (_, meta) = self.client.do_put(
    "/v1/agent/node/maintenance", b"", options, extra,
  )
  meta
}

///|
/// Take the node out of maintenance mode.
pub fn Agent::disable_node_maintenance(
  self : Agent,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_put(
    "/v1/agent/node/maintenance",
    b"",
    options,
    [("enable", "false")],
  )
  meta
}

///|
/// Replace the agent's ACL token (used when the local token must change without
/// restarting the agent).
pub fn Agent::update_acl_token(
  self : Agent,
  token : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let m = jobj()
  put_str(m, "Token", Some(token))
  let body = @utf8.encode(@json.to_json(m).stringify())
  let (_, meta) = self.client.do_put(
    "/v1/agent/token/acl_token",
    body,
    options,
    [],
  )
  meta
}
