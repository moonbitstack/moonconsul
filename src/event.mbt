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
/// Fire `name` with `payload`, scoped by `options`, returning the accepted event.
pub fn Event::fire(
  self : Event,
  name : String,
  payload : Bytes,
  options~ : EventFireOptions = default_event_fire_options,
  write_options~ : WriteOptions = default_write_options,
) -> (UserEvent, WriteMeta) raise Refused {
  let _ = (self, name, payload, options, write_options)
  raise Refused::Unimplemented("event.fire")
}

///|
/// List events, optionally only those named `options.name`.
pub fn Event::list(
  self : Event,
  options~ : EventListOptions = default_event_list_options,
  query_options~ : QueryOptions = default_query_options,
) -> (Array[UserEvent], QueryMeta) raise Refused {
  let _ = (self, options, query_options)
  raise Refused::Unimplemented("event.list")
}
