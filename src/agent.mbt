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
/// `output` without sending a fresh TTL.
pub(all) struct AgentCheckUpdate {
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
/// Register `reg` with this agent. A service with an inline TTL check starts
/// `critical`; follow with `check_pass` to make it healthy.
pub fn Agent::service_register(
  self : Agent,
  reg : AgentServiceRegistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, reg, options)
  raise Refused::Unimplemented("agent.service.register")
}

///|
/// Deregister the service instance `id` from this agent.
pub fn Agent::service_deregister(
  self : Agent,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("agent.service.deregister")
}

///|
/// Register `reg` (a check, optionally bound to a service) with this agent.
pub fn Agent::check_register(
  self : Agent,
  reg : AgentCheckRegistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, reg, options)
  raise Refused::Unimplemented("agent.check.register")
}

///|
/// Deregister the check `check_id` from this agent.
pub fn Agent::check_deregister(
  self : Agent,
  check_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, check_id, options)
  raise Refused::Unimplemented("agent.check.deregister")
}

///|
/// Mark the TTL/http/tcp/grpc check `check_id` passing; the keep-alive that
/// renews a service's lease.
pub fn Agent::check_pass(
  self : Agent,
  check_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, check_id, options)
  raise Refused::Unimplemented("agent.check.pass")
}

///|
/// Mark the check `check_id` failing.
pub fn Agent::check_fail(
  self : Agent,
  check_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, check_id, options)
  raise Refused::Unimplemented("agent.check.fail")
}

///|
/// Set a TTL check's `status` and `output` without resetting its TTL clock.
pub fn Agent::check_update(
  self : Agent,
  update : AgentCheckUpdate,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, update, options)
  raise Refused::Unimplemented("agent.check.update")
}

///|
/// The agent's own configuration, member record and runtime stats.
pub fn Agent::self(
  self : Agent,
  options~ : QueryOptions = default_query_options,
) -> (AgentSelf, QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("agent.self")
}

///|
/// The cluster members this agent gossips with. `options.filter` (a
/// go-compatible tag expression) narrows the returned set.
pub fn Agent::members(
  self : Agent,
  options~ : QueryOptions = default_query_options,
) -> (Array[AgentMember], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("agent.members")
}

///|
/// Like `members`, but `filter` is required rather than optional.
pub fn Agent::members_with_filter(
  self : Agent,
  filter : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[AgentMember], QueryMeta) raise Refused {
  let _ = (self, filter, options)
  raise Refused::Unimplemented("agent.members.with_filter")
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
  let _ = (self, address, wan, options)
  raise Refused::Unimplemented("agent.join")
}

///|
/// Ask this agent to leave the cluster gracefully.
pub fn Agent::leave(
  self : Agent,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("agent.leave")
}

///|
/// Force a `node` out of the cluster without its cooperation.
pub fn Agent::force_leave(
  self : Agent,
  node : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, node, options)
  raise Refused::Unimplemented("agent.force_leave")
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
  let _ = (self, service_id, reason, options)
  raise Refused::Unimplemented("agent.enable_service_maintenance")
}

///|
/// Take the service instance `service_id` out of maintenance mode.
pub fn Agent::disable_service_maintenance(
  self : Agent,
  service_id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, service_id, options)
  raise Refused::Unimplemented("agent.disable_service_maintenance")
}

///|
/// Put the whole node into maintenance mode.
pub fn Agent::enable_node_maintenance(
  self : Agent,
  reason~ : String = "",
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, reason, options)
  raise Refused::Unimplemented("agent.enable_node_maintenance")
}

///|
/// Take the node out of maintenance mode.
pub fn Agent::disable_node_maintenance(
  self : Agent,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("agent.disable_node_maintenance")
}

///|
/// Replace the agent's ACL token (used when the local token must change without
/// restarting the agent).
pub fn Agent::update_acl_token(
  self : Agent,
  token : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, token, options)
  raise Refused::Unimplemented("agent.update_acl_token")
}
