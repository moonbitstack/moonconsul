///|
/// A blocking-query watcher. A `WatchPlan` describes one kind of query (a key,
/// a service's health, the nodes, ...) and the `index`/`wait_time` that drive
/// it. Because this client is synchronous, `Client::watch` performs one
/// blocking query and returns a new `Watcher` carrying the advanced index; the
/// caller loops on it, so a watch can be stopped between iterations.
pub struct Watcher {
  plan : WatchPlan
}

///|
/// What to watch and how: `kind` selects the query (`key`, `keyprefix`,
/// `service`, `checks`, `state`, `nodes`, `services`, `connect`, `agent/self`);
/// `index` and `wait_time` carry the blocking state between iterations.
pub(all) struct WatchPlan {
  kind : String
  key : String?
  service : String?
  datacenter : String?
  token : String?
  index : Int64
  wait_time : Int64
  filter : String?
  near : String?
}

///|
/// A string, or `""` when unset.
fn or_empty(v : String?) -> String {
  match v {
    Some(s) => s
    None => ""
  }
}

///|
/// The request path a plan watches, or `Param` for an unknown kind.
fn watch_path(plan : WatchPlan) -> String raise Refused {
  match plan.kind {
    "key" => "/v1/kv/" + or_empty(plan.key)
    "keyprefix" => "/v1/kv/" + or_empty(plan.key)
    "service" => "/v1/health/service/" + or_empty(plan.service)
    "checks" => "/v1/health/checks/" + or_empty(plan.service)
    "state" => "/v1/health/state/" + or_empty(plan.service)
    "connect" => "/v1/health/connect/" + or_empty(plan.service)
    "nodes" => "/v1/catalog/nodes"
    "services" => "/v1/catalog/services"
    "agent/self" => "/v1/agent/self"
    _ => raise Refused::Param("watch: unknown kind " + plan.kind)
  }
}

///|
/// Run one blocking query for `plan` and, when the index advances past
/// `plan.index`, call `handler(index, data)` with the new index and the parsed
/// response. Returns a `Watcher` whose plan carries the advanced index; loop on
/// it (passing `w.plan`) to keep watching.
pub fn Client::watch(
  self : Client,
  plan : WatchPlan,
  handler : (Int64, Json) -> Unit raise Refused,
  options~ : QueryOptions = default_query_options,
) -> Watcher raise Refused {
  let path = watch_path(plan)
  let extra : Array[(String, String)] = []
  if plan.kind == "keyprefix" {
    extra.push(("recurse", ""))
  }
  let opt : QueryOptions = {
    ..options,
    datacenter: match plan.datacenter {
      Some(d) => Some(d)
      None => options.datacenter
    },
    token: match plan.token {
      Some(t) => Some(t)
      None => options.token
    },
    wait_index: Some(plan.index),
    wait_time: Some(plan.wait_time),
    filter: match plan.filter {
      Some(f) => Some(f)
      None => options.filter
    },
    near: match plan.near {
      Some(n) => Some(n)
      None => options.near
    },
  }
  let (json, meta) = self.do_get(path, opt, extra)
  if meta.last_index != plan.index {
    handler(meta.last_index, json)
  }
  Watcher::{ plan: { ..plan, index: meta.last_index, }, }
}

///|
/// End a watch. The synchronous watcher has no background resource, so this is
/// a no-op retained for the interface; simply stop iterating.
pub fn Watcher::stop(self : Watcher) -> Unit {
  let _ = self
}
