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
/// The `Kind` string for a config entry.
fn config_entry_kind(entry : ConfigEntry) -> String {
  match entry {
    ServiceDefault(_) => "service-defaults"
    ServiceRouter(_) => "service-router"
    ServiceSplitter(_) => "service-splitter"
    ServiceResolver(_) => "service-resolver"
    Mesh(_) => "mesh"
  }
}

///|
/// A `ServiceMeshGateway` as a JSON object.
fn mesh_gateway_to_json(g : ServiceMeshGateway) -> Json {
  let m = jobj()
  put_str(m, "Mode", g.mode)
  @json.to_json(m)
}

///|
/// A `ServiceMeshGateway` from a JSON object.
fn mesh_gateway_of(j : Json) -> ServiceMeshGateway {
  { mode: jstr_opt(json_map(j), "Mode"), }
}

///|
/// A `ServiceRouteHTTPMatch` as a JSON object.
fn route_http_match_to_json(h : ServiceRouteHTTPMatch) -> Json {
  let m = jobj()
  put_str(m, "PathExact", h.path)
  put_str(m, "PathPrefix", h.prefix)
  put_str(m, "PathRegex", h.regex)
  @json.to_json(m)
}

///|
/// A `ServiceRouteHTTPMatch` from a JSON object.
fn route_http_match_of(j : Json) -> ServiceRouteHTTPMatch {
  let m = json_map(j)
  {
    path: jstr_opt(m, "PathExact"),
    prefix: jstr_opt(m, "PathPrefix"),
    regex: jstr_opt(m, "PathRegex"),
  }
}

///|
/// A `ServiceRouteDestination` as a JSON object.
fn route_destination_to_json(d : ServiceRouteDestination) -> Json {
  let m = jobj()
  put_str(m, "Service", d.service)
  put_str(m, "Namespace", d.ns)
  @json.to_json(m)
}

///|
/// A `ServiceRouteDestination` from a JSON object.
fn route_destination_of(j : Json) -> ServiceRouteDestination {
  let m = json_map(j)
  { service: jstr_opt(m, "Service"), ns: jstr_opt(m, "Namespace"), }
}

///|
/// A `ServiceRoute` as a JSON object.
fn route_to_json(r : ServiceRoute) -> Json {
  let m = jobj()
  match r.matcher {
    Some(mt) => {
      let mm = jobj()
      match mt.http {
        Some(h) => mm["HTTP"] = route_http_match_to_json(h)
        None => ()
      }
      m["Match"] = @json.to_json(mm)
    }
    None => ()
  }
  match r.destination {
    Some(d) => m["Destination"] = route_destination_to_json(d)
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `ServiceRoute` from a JSON object.
fn route_of(j : Json) -> ServiceRoute {
  let m = json_map(j)
  let matcher = match m.get("Match") {
    Some(mt) =>
      if mt is Object(mm) {
        Some({
          http: match mm.get("HTTP") {
            Some(h) =>
              if h is Object(_) {
                Some(route_http_match_of(h))
              } else {
                None
              }
            None => None
          },
        })
      } else {
        None
      }
    None => None
  }
  let destination = match m.get("Destination") {
    Some(d) => if d is Object(_) { Some(route_destination_of(d)) } else { None }
    None => None
  }
  { matcher, destination, }
}

///|
/// A `ServiceDefaultConfigEntry` as a JSON object.
fn default_entry_to_json(e : ServiceDefaultConfigEntry) -> Json {
  let m = jobj()
  m["Kind"] = @json.to_json("service-defaults")
  put_str(m, "Name", Some(e.name))
  put_str(m, "Namespace", e.ns)
  put_str(m, "Partition", e.partition)
  put_str(m, "Protocol", e.protocol)
  match e.mesh_gateway {
    Some(g) => m["MeshGateway"] = mesh_gateway_to_json(g)
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `ServiceDefaultConfigEntry` from a JSON object.
fn default_entry_of(m : Map[String, Json]) -> ServiceDefaultConfigEntry {
  {
    name: jstr(m, "Name"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    protocol: jstr_opt(m, "Protocol"),
    mesh_gateway: match m.get("MeshGateway") {
      Some(g) => if g is Object(_) { Some(mesh_gateway_of(g)) } else { None }
      None => None
    },
  }
}

///|
/// A `ServiceRouterConfigEntry` as a JSON object.
fn router_entry_to_json(e : ServiceRouterConfigEntry) -> Json {
  let m = jobj()
  m["Kind"] = @json.to_json("service-router")
  put_str(m, "Name", Some(e.name))
  put_str(m, "Namespace", e.ns)
  put_str(m, "Partition", e.partition)
  match e.routes {
    Some(rs) => {
      let arr : Array[Json] = []
      for r in rs {
        arr.push(route_to_json(r))
      }
      m["Routes"] = @json.to_json(arr)
    }
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `ServiceRouterConfigEntry` from a JSON object.
fn router_entry_of(m : Map[String, Json]) -> ServiceRouterConfigEntry {
  let routes : Array[ServiceRoute] = []
  for item in jarray(m, "Routes") {
    routes.push(route_of(item))
  }
  {
    name: jstr(m, "Name"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    routes: if routes.length() == 0 {
      None
    } else {
      Some(routes)
    },
  }
}

///|
/// A `ServiceSplitterConfigEntry` as a JSON object.
fn splitter_entry_to_json(e : ServiceSplitterConfigEntry) -> Json {
  let m = jobj()
  m["Kind"] = @json.to_json("service-splitter")
  put_str(m, "Name", Some(e.name))
  put_str(m, "Namespace", e.ns)
  put_str(m, "Partition", e.partition)
  match e.splits {
    Some(sp) => {
      let arr : Array[Json] = []
      for s in sp {
        let sm = jobj()
        sm["Weight"] = @json.to_json(s.weight)
        put_str(sm, "Service", s.service)
        put_str(sm, "Namespace", s.ns)
        arr.push(@json.to_json(sm))
      }
      m["Splits"] = @json.to_json(arr)
    }
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `ServiceSplitterConfigEntry` from a JSON object.
fn splitter_entry_of(m : Map[String, Json]) -> ServiceSplitterConfigEntry {
  let splits : Array[ServiceSplit] = []
  for item in jarray(m, "Splits") {
    let sm = json_map(item)
    splits.push({
      weight: match jdouble_opt(sm, "Weight") {
        Some(d) => d
        None => 0.0
      },
      service: jstr_opt(sm, "Service"),
      ns: jstr_opt(sm, "Namespace"),
    })
  }
  {
    name: jstr(m, "Name"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    splits: if splits.length() == 0 {
      None
    } else {
      Some(splits)
    },
  }
}

///|
/// A `ServiceResolverConfigEntry` as a JSON object.
fn resolver_entry_to_json(e : ServiceResolverConfigEntry) -> Json {
  let m = jobj()
  m["Kind"] = @json.to_json("service-resolver")
  put_str(m, "Name", Some(e.name))
  put_str(m, "Namespace", e.ns)
  put_str(m, "Partition", e.partition)
  put_str(m, "Datacenter", e.datacenter)
  put_str(m, "Service", e.service)
  put_str(m, "Redirect", e.redirect)
  match e.failover {
    Some(f) => m["Failover"] = query_datacenter_options_to_json(f)
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `ServiceResolverConfigEntry` from a JSON object.
fn resolver_entry_of(m : Map[String, Json]) -> ServiceResolverConfigEntry {
  {
    name: jstr(m, "Name"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    datacenter: jstr_opt(m, "Datacenter"),
    service: jstr_opt(m, "Service"),
    failover: match m.get("Failover") {
      Some(f) =>
        if f is Object(_) {
          Some(query_datacenter_options_of(f))
        } else {
          None
        }
      None => None
    },
    redirect: jstr_opt(m, "Redirect"),
  }
}

///|
/// A `MeshConfigEntry` as a JSON object.
fn mesh_entry_to_json(e : MeshConfigEntry) -> Json {
  let m = jobj()
  m["Kind"] = @json.to_json("mesh")
  put_str(m, "Name", Some(e.name))
  put_str(m, "Partition", e.partition)
  match e.transparent_proxy {
    Some(t) => {
      let tm = jobj()
      put_str(tm, "Mode", t.mode)
      m["TransparentProxy"] = @json.to_json(tm)
    }
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `MeshConfigEntry` from a JSON object.
fn mesh_entry_of(m : Map[String, Json]) -> MeshConfigEntry {
  {
    name: jstr(m, "Name"),
    partition: jstr_opt(m, "Partition"),
    transparent_proxy: match m.get("TransparentProxy") {
      Some(t) =>
        if t is Object(tm) {
          Some({ mode: jstr_opt(tm, "Mode"), })
        } else {
          None
        }
      None => None
    },
  }
}

///|
/// A `ConfigEntry` as its write body (with its `Kind`).
fn config_entry_to_json(entry : ConfigEntry) -> Json {
  match entry {
    ServiceDefault(e) => default_entry_to_json(e)
    ServiceRouter(e) => router_entry_to_json(e)
    ServiceSplitter(e) => splitter_entry_to_json(e)
    ServiceResolver(e) => resolver_entry_to_json(e)
    Mesh(e) => mesh_entry_to_json(e)
  }
}

///|
/// A `ConfigEntry` from its JSON object, dispatched on `Kind`.
fn config_entry_of(j : Json) -> ConfigEntry {
  let m = json_map(j)
  match jstr(m, "Kind") {
    "service-router" => ServiceRouter(router_entry_of(m))
    "service-splitter" => ServiceSplitter(splitter_entry_of(m))
    "service-resolver" => ServiceResolver(resolver_entry_of(m))
    "mesh" => Mesh(mesh_entry_of(m))
    _ => ServiceDefault(default_entry_of(m))
  }
}

///|
/// Read one config entry by `kind` and `name`.
pub async fn ConfigEntries::get(
  self : ConfigEntries,
  kind : String,
  name : String,
  options~ : QueryOptions = default_query_options,
) -> (ConfigEntry, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get(
    "/v1/config/" + kind + "/" + name,
    options,
    [],
  )
  (config_entry_of(json), meta)
}

///|
/// List the config entries of `kind`.
pub async fn ConfigEntries::list(
  self : ConfigEntries,
  kind : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[ConfigEntry], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/config/" + kind, options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ConfigEntry] = []
  for item in json_array(json) {
    out.push(config_entry_of(item))
  }
  (out, meta)
}

///|
/// Write `entry`; the wrapped entry carries its own kind and name.
pub async fn ConfigEntries::set(
  self : ConfigEntries,
  entry : ConfigEntry,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = config_entry_kind(entry)
  let body = @utf8.encode(config_entry_to_json(entry).stringify())
  let (_, meta) = self.client.do_put("/v1/config", body, options, [])
  meta
}

///|
/// Delete the config entry of `kind` and `name`.
pub async fn ConfigEntries::delete(
  self : ConfigEntries,
  kind : String,
  name : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete(
    "/v1/config/" + kind + "/" + name,
    options,
    [],
  )
  meta
}
