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
  create_index : Int64?
  modify_index : Int64?
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
  create_index : Int64?
  modify_index : Int64?
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
/// Register `reg` against the catalog.
pub fn Catalog::register(
  self : Catalog,
  reg : CatalogRegistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, reg, options)
  raise Refused::Unimplemented("catalog.register")
}

///|
/// Deregister `dereg` from the catalog.
pub fn Catalog::deregister(
  self : Catalog,
  dereg : CatalogDeregistration,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, dereg, options)
  raise Refused::Unimplemented("catalog.deregister")
}

///|
/// The datacenters in the WAN federation.
pub fn Catalog::datacenters(
  self : Catalog,
  options~ : QueryOptions = default_query_options,
) -> (Array[String], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("catalog.datacenters")
}

///|
/// The nodes in this datacenter, narrowed by `options.filter`.
pub fn Catalog::nodes(
  self : Catalog,
  options~ : QueryOptions = default_query_options,
) -> (Array[Node], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("catalog.nodes")
}

///|
/// One node and every service registered on it.
pub fn Catalog::node(
  self : Catalog,
  node : String,
  options~ : QueryOptions = default_query_options,
) -> (CatalogNode, QueryMeta) raise Refused {
  let _ = (self, node, options)
  raise Refused::Unimplemented("catalog.node")
}

///|
/// The service names in this datacenter, each with its tag set.
pub fn Catalog::services(
  self : Catalog,
  options~ : QueryOptions = default_query_options,
) -> (Map[String, Array[String]], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("catalog.services")
}

///|
/// The instances of `service` in this datacenter.
pub fn Catalog::service(
  self : Catalog,
  service : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[CatalogService], QueryMeta) raise Refused {
  let _ = (self, service, options)
  raise Refused::Unimplemented("catalog.service")
}
