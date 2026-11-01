///|
/// A blocking-query watcher. A `WatchPlan` describes one kind of query (a key,
/// a service's health, the nodes, ...) and the `index`/`wait_time` that drive
/// it; `watch` loops, performing the query with the last seen index, and calls
/// `handler` with the new index and the parsed result whenever it changes.
pub struct Watcher {
  plan : WatchPlan
}

///|
/// What to watch and how: `kind` selects the query (`key`, `service`, `checks`,
/// `nodes`, `services`, `health`, `connect`, `agent/self`, ...); `index` and
/// `wait_time` carry the blocking state between iterations.
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
/// Watch `plan`, invoking `handler(index, data)` on every change. `data` is the
/// parsed JSON of the response.
pub fn watch(
  plan : WatchPlan,
  handler : (Int64, Json) -> Unit raise Refused,
  options~ : QueryOptions = default_query_options,
) -> Watcher raise Refused {
  let _ = (plan, handler, options)
  let _handle = Watcher::{ plan, }
  raise Refused::Unimplemented("watch")
}

///|
/// Stop a running watch started by `watch`.
pub fn Watcher::stop(self : Watcher) -> Unit {
  let _ = self
  abort("not implemented: watcher.stop")
}
