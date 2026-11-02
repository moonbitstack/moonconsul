///|
/// A handle to the Catalog API: datacenter-wide registration of nodes and
/// services, and read-only listing of nodes, services and their metadata.
pub struct Catalog {
  client : Client
}

///|
/// A Consul node: its `node` name, `address`, and free-form `meta`.
pub(all) struct Node {
  node : String
  address : String
  meta : Map[String, String]?
  ns : String?
  partition : String?
  tagged_addresses : Map[String, String]?
  create_index : UInt64?
  modify_index : UInt64?
  deregister_critical_service_after : String?
}

///|
/// The body of `PUT /v1/catalog/register`: a `node` and `address`, optional
/// `node_meta`, and at most one service and check (or several checks) to register
/// against that node.
pub(all) struct CatalogRegistration {
  node : String
  address : String
  node_meta : Map[String, String]?
  ns : String?
  partition : String?
  service : CatalogService?
  check : AgentCheck?
  checks : Array[AgentCheck]?
}

///|
/// The body of `PUT /v1/catalog/deregister`: identifies a node, service or check
/// to remove.
pub(all) struct CatalogDeregistration {
  node : String
  address : String?
  service_id : String?
  check_id : String?
  ns : String?
  partition : String?
}

///|
/// A service as listed by the catalog: its `id`, the `node` it runs on, and its
/// tags, `meta` and `port`.
pub(all) struct CatalogService {
  id : String
  node : String
  address : String
  service : String
  tags : Array[String]
  meta : Map[String, String]?
  ns : String?
  partition : String?
  port : Int32?
  weights : AgentWeights?
  create_index : UInt64?
  modify_index : UInt64?
}

///|
/// A single service bound to a node, as returned by `node`.
pub(all) struct CatalogNodeService {
  id : String
  service : String
  tags : Array[String]
  meta : Map[String, String]?
  ns : String?
  port : Int32?
  address : String?
  weights : AgentWeights?
}

///|
/// A node together with every service registered on it.
pub(all) struct CatalogNode {
  node : Node
  services : Map[String, CatalogNodeService]?
}

///|
/// A `Node` from its JSON object.
pub fn node_of(j : Json) -> Node {
  let m = json_map(j)
  {
    node: jstr(m, "Node"),
    address: jstr(m, "Address"),
    meta: jmap_opt(m, "Meta"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    tagged_addresses: jmap_opt(m, "TaggedAddresses"),
    create_index: ju64_opt(m, "CreateIndex"),
    modify_index: ju64_opt(m, "ModifyIndex"),
    deregister_critical_service_after: jstr_opt(
      m, "DeregisterCriticalServiceAfter",
    ),
  }
}

///|
/// `AgentWeights` from the `key` object in `m`, or `None`.
fn weights_of(m : Map[String, Json], key : String) -> AgentWeights? {
  match m.get(key) {
    Some(Object(o)) =>
      Some({ passing: ji32_opt(o, "Passing"), warning: ji32_opt(o, "Warning"), })
    _ => None
  }
}

///|
/// An `AgentCheck` as the JSON object a registration carries.
fn agent_check_to_json(c : AgentCheck) -> Json {
  let m = jobj()
  put_str(m, "CheckID", Some(c.id))
  put_str(m, "Name", c.name)
  put_str(m, "Status", c.status)
  put_str(m, "Notes", c.notes)
  put_str(m, "Output", c.output)
  put_str(m, "ServiceID", c.service_id)
  put_str(m, "ServiceName", c.service_name)
  put_str(m, "Namespace", c.ns)
  @json.to_json(m)
}

///|
/// A `CatalogService` as the JSON object a register body carries.
fn catalog_service_to_json(s : CatalogService) -> Json {
  let m = jobj()
  put_str(m, "ID", Some(s.id))
  put_str(m, "Service", Some(s.service))
  put_str_array(m, "Tags", Some(s.tags))
  put_str(m, "Address", Some(s.address))
  put_i32(m, "Port", s.port)
  match s.meta {
    Some(mm) => m["Meta"] = map_to_json(mm)
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `CatalogRegistration` as its write body.
fn catalog_registration_to_json(r : CatalogRegistration) -> Json {
  let m = jobj()
  put_str(m, "Node", Some(r.node))
  put_str(m, "Address", Some(r.address))
  match r.node_meta {
    Some(mm) => m["NodeMeta"] = map_to_json(mm)
    None => ()
  }
  put_str(m, "Namespace", r.ns)
  put_str(m, "Partition", r.partition)
  match r.service {
    Some(s) => m["Service"] = catalog_service_to_json(s)
    None => ()
  }
  match r.check {
    Some(c) => m["Check"] = agent_check_to_json(c)
    None => ()
  }
  match r.checks {
    Some(cs) => {
      let arr : Array[Json] = []
      for c in cs {
        arr.push(agent_check_to_json(c))
      }
      m["Checks"] = @json.to_json(arr)
    }
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `CatalogDeregistration` as its write body.
fn catalog_dereg_to_json(d : CatalogDeregistration) -> Json {
  let m = jobj()
  put_str(m, "Node", Some(d.node))
  put_str(m, "Address", d.address)
  put_str(m, "ServiceID", d.service_id)
  put_str(m, "CheckID", d.check_id)
  put_str(m, "Namespace", d.ns)
  put_str(m, "Partition", d.partition)
  @json.to_json(m)
}

///|
/// A `CatalogService` from its JSON object.
fn catalog_service_of(j : Json) -> CatalogService {
  let m = json_map(j)
  let id = if jstr(m, "ServiceID") != "" {
    jstr(m, "ServiceID")
  } else {
    jstr(m, "ID")
  }
  {
    id,
    node: jstr(m, "Node"),
    address: jstr(m, "ServiceAddress"),
    service: jstr(m, "ServiceName"),
    tags: match jstr_array_opt(m, "ServiceTags") {
      Some(t) => t
      None => []
    },
    meta: jmap_opt(m, "ServiceMeta"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    port: ji32_opt(m, "ServicePort"),
    weights: weights_of(m, "ServiceWeights"),
    create_index: ju64_opt(m, "CreateIndex"),
    modify_index: ju64_opt(m, "ModifyIndex"),
  }
}

///|
/// A `CatalogNodeService` from its JSON object.
fn catalog_node_service_of(j : Json) -> CatalogNodeService {
  let m = json_map(j)
  {
    id: jstr(m, "ID"),
    service: jstr(m, "Service"),
    tags: match jstr_array_opt(m, "Tags") {
      Some(t) => t
      None => []
    },
    meta: jmap_opt(m, "Meta"),
    ns: jstr_opt(m, "Namespace"),
    port: ji32_opt(m, "Port"),
    address: jstr_opt(m, "Address"),
    weights: weights_of(m, "Weights"),
  }
}

///|
/// A `CatalogNode` from its JSON object.
fn catalog_node_of(j : Json) -> CatalogNode {
  let m = json_map(j)
  let node = node_of(
    match m.get("Node") {
      Some(n) => n
      None => @json.to_json(jobj())
    },
  )
  let services = match m.get("Services") {
    Some(Object(o)) => {
      let out : Map[String, CatalogNodeService] = Map([])
      for k, v in o {
        out[k] = catalog_node_service_of(v)
      }
      Some(out)
    }
    _ => None
  }
  { node, services, }
}

///|
/// Register `reg` against the catalog.
pub async fn Catalog::register(
  self : Catalog,
  reg : CatalogRegistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(catalog_registration_to_json(reg).stringify())
  let (_, meta) = self.client.do_put("/v1/catalog/register", body, options, [])
  meta
}

///|
/// Deregister `dereg` from the catalog.
pub async fn Catalog::deregister(
  self : Catalog,
  dereg : CatalogDeregistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(catalog_dereg_to_json(dereg).stringify())
  let (_, meta) = self.client.do_put("/v1/catalog/deregister", body, options, [])
  meta
}

///|
/// The datacenters in the WAN federation.
pub async fn Catalog::datacenters(
  self : Catalog,
  options~ : QueryOptions = default_query_options,
) -> (Array[String], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/catalog/datacenters", options, [])
  let out : Array[String] = []
  for item in json_array(json) {
    if item is String(s) {
      out.push(s)
    }
  }
  (out, meta)
}

///|
/// The nodes in this datacenter, narrowed by `options.filter`.
pub async fn Catalog::nodes(
  self : Catalog,
  options~ : QueryOptions = default_query_options,
) -> (Array[Node], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/catalog/nodes", options, [])
  let out : Array[Node] = []
  for item in json_array(json) {
    out.push(node_of(item))
  }
  (out, meta)
}

///|
/// One node and every service registered on it.
pub async fn Catalog::node(
  self : Catalog,
  node : String,
  options~ : QueryOptions = default_query_options,
) -> (CatalogNode, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/catalog/node/" + node, options, []) catch {
    Refused::NotFound =>
      return (
        { node: node_of(@json.to_json(jobj())), services: None, },
        empty_query_meta(),
      )
    e => raise e
  }
  (catalog_node_of(json), meta)
}

///|
/// The service names in this datacenter, each with its tag set.
pub async fn Catalog::services(
  self : Catalog,
  options~ : QueryOptions = default_query_options,
) -> (Map[String, Array[String]], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/catalog/services", options, [])
  let out : Map[String, Array[String]] = Map([])
  for k, v in json_map(json) {
    let tags : Array[String] = []
    for item in json_array(v) {
      if item is String(s) {
        tags.push(s)
      }
    }
    out[k] = tags
  }
  (out, meta)
}

///|
/// The instances of `service` in this datacenter.
pub async fn Catalog::service(
  self : Catalog,
  service : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[CatalogService], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get(
    "/v1/catalog/service/" + service,
    options,
    [],
  ) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[CatalogService] = []
  for item in json_array(json) {
    out.push(catalog_service_of(item))
  }
  (out, meta)
}
