///|
/// A handle to the Event API: user events are fire-and-forget messages fanned
/// out across the datacenter, optionally scoped to nodes, services or tags.
pub struct Event {
  client : Client
}

///|
/// A user event as fired and as listed back.
pub(all) struct UserEvent {
  id : String
  name : String
  payload : Bytes?
  node_filter : String?
  service_filter : String?
  tag_filter : String?
  version : Int32?
  ltime : Int64?
}

///|
/// Scope filters for `fire`.
pub(all) struct EventFireOptions {
  node_filter : String?
  service_filter : String?
  tag_filter : String?
}

///|
/// No scope filter.
pub let default_event_fire_options : EventFireOptions = {
  node_filter: None,
  service_filter: None,
  tag_filter: None,
}

///|
/// List filters for `list`.
pub(all) struct EventListOptions {
  name : String?
}

///|
/// List every event.
pub let default_event_list_options : EventListOptions = { name: None, }

///|
/// A `UserEvent` from its JSON object.
fn user_event_of(j : Json) -> UserEvent {
  let m = json_map(j)
  {
    id: jstr(m, "ID"),
    name: jstr(m, "Name"),
    payload: jbytes_b64_opt(m, "Payload"),
    node_filter: jstr_opt(m, "NodeFilter"),
    service_filter: jstr_opt(m, "ServiceFilter"),
    tag_filter: jstr_opt(m, "TagFilter"),
    version: ji32_opt(m, "Version"),
    ltime: ji64_opt(m, "LTime"),
  }
}

///|
/// Fire `name` with `payload`, scoped by `options`, returning the accepted event.
pub async fn Event::fire(
  self : Event,
  name : String,
  payload : Bytes,
  options~ : EventFireOptions = default_event_fire_options,
  write_options~ : WriteOptions = default_write_options,
) -> (UserEvent, WriteMeta) raise Refused {
  let extra : Array[(String, String)] = []
  match options.node_filter {
    Some(v) => extra.push(("node", v))
    None => ()
  }
  match options.service_filter {
    Some(v) => extra.push(("service", v))
    None => ()
  }
  match options.tag_filter {
    Some(v) => extra.push(("tag", v))
    None => ()
  }
  let (json, meta) = self.client.do_put(
    "/v1/event/fire/" + name,
    payload,
    write_options,
    extra,
  )
  (user_event_of(json), meta)
}

///|
/// List events, optionally only those named `options.name`.
pub async fn Event::list(
  self : Event,
  options~ : EventListOptions = default_event_list_options,
  query_options~ : QueryOptions = default_query_options,
) -> (Array[UserEvent], QueryMeta) raise Refused {
  let extra : Array[(String, String)] = []
  match options.name {
    Some(n) => extra.push(("name", n))
    None => ()
  }
  let (json, meta) = self.client.do_get("/v1/event/list", query_options, extra)
  let out : Array[UserEvent] = []
  for item in json_array(json) {
    out.push(user_event_of(item))
  }
  (out, meta)
}
