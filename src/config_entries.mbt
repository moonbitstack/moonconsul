///|
/// A handle to the Config Entries API: typed, centrally-stored configuration
/// objects (service defaults, routers, splitters, resolvers, mesh-wide
/// settings) that Consul serves to the data plane.
pub struct ConfigEntries {
  client : Client
}

///|
/// A config entry. Each variant carries the typed entry for one `kind`; a read
/// returns the variant for the stored `kind`, and a write carries the variant
/// to store. `kind` and `name` are read from the wrapped entry.
pub(all) enum ConfigEntry {
  ServiceDefault(ServiceDefaultConfigEntry)
  ServiceRouter(ServiceRouterConfigEntry)
  ServiceSplitter(ServiceSplitterConfigEntry)
  ServiceResolver(ServiceResolverConfigEntry)
  Mesh(MeshConfigEntry)
}

///|
/// Default protocol, mesh and per-service settings.
pub(all) struct ServiceDefaultConfigEntry {
  name : String
  ns : String?
  partition : String?
  protocol : String?
  mesh_gateway : ServiceMeshGateway?
}

///|
/// A service's mesh-gateway mode.
pub(all) struct ServiceMeshGateway {
  mode : String?
}

///|
/// Layer-7 routing rules for a service.
pub(all) struct ServiceRouterConfigEntry {
  name : String
  ns : String?
  partition : String?
  routes : Array[ServiceRoute]?
}

///|
/// One routing match/rewrite rule.
pub(all) struct ServiceRoute {
  matcher : ServiceRouteMatch?
  destination : ServiceRouteDestination?
}

///|
/// The match half of a route.
pub(all) struct ServiceRouteMatch {
  http : ServiceRouteHTTPMatch?
}

///|
/// HTTP match fields.
pub(all) struct ServiceRouteHTTPMatch {
  path : String?
  prefix : String?
  regex : String?
}

///|
/// The destination half of a route.
pub(all) struct ServiceRouteDestination {
  service : String?
  ns : String?
}

///|
/// Weighted traffic split for a service.
pub(all) struct ServiceSplitterConfigEntry {
  name : String
  ns : String?
  partition : String?
  splits : Array[ServiceSplit]?
}

///|
/// One weighted destination in a split.
pub(all) struct ServiceSplit {
  weight : Double
  service : String?
  ns : String?
}

///|
/// How a service resolves to healthy instances, with failover.
pub(all) struct ServiceResolverConfigEntry {
  name : String
  ns : String?
  partition : String?
  datacenter : String?
  service : String?
  failover : QueryDatacenterOptions?
  redirect : String?
}

///|
/// Mesh-wide configuration.
pub(all) struct MeshConfigEntry {
  name : String
  partition : String?
  transparent_proxy : MeshTransparentProxy?
}

///|
/// Transparent-proxy settings for the mesh.
pub(all) struct MeshTransparentProxy {
  mode : String?
}

///|
/// Read one config entry by `kind` and `name`.
pub fn ConfigEntries::get(
  self : ConfigEntries,
  kind : String,
  name : String,
  options~ : QueryOptions = default_query_options,
) -> (ConfigEntry, QueryMeta) raise Refused {
  let _ = (self, kind, name, options)
  raise Refused::Unimplemented("config_entries.get")
}

///|
/// List every config entry, or only those of `kind` when set.
pub fn ConfigEntries::list(
  self : ConfigEntries,
  kind~ : String = "",
  options~ : QueryOptions = default_query_options,
) -> (Array[ConfigEntry], QueryMeta) raise Refused {
  let _ = (self, kind, options)
  raise Refused::Unimplemented("config_entries.list")
}

///|
/// Write `entry`; the wrapped entry carries its own kind and name.
pub fn ConfigEntries::set(
  self : ConfigEntries,
  entry : ConfigEntry,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, entry, options)
  raise Refused::Unimplemented("config_entries.set")
}

///|
/// Delete the config entry of `kind` and `name`.
pub fn ConfigEntries::delete(
  self : ConfigEntries,
  kind : String,
  name : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, kind, name, options)
  raise Refused::Unimplemented("config_entries.delete")
}
