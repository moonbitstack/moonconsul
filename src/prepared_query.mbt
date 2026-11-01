///|
/// A handle to the Prepared Query API: named and templated service queries with
/// failover, used as a stable service-discovery entry point.
pub struct PreparedQuery {
  client : Client
}

///|
/// The service a query targets, with tag and health criteria and failover.
pub(all) struct ServiceQuery {
  service : String
  ns : String?
  tags_any : Array[String]?
  only_passing : Bool?
  node_type : String?
  failover : QueryDatacenterOptions?
}

///|
/// Failover policy: prefer the `nearest` datacenter, then fall back through
/// `datacenters`.
pub(all) struct QueryDatacenterOptions {
  nearest : Bool?
  datacenters : Array[String]?
}

///|
/// DNS tuning for a query.
pub(all) struct DNSQuery {
  ttl : String?
}

///|
/// A prepared query definition: its `id` (assigned by Consul), `name`,
/// `token`, and the `service` and `dns` blocks.
pub(all) struct PreparedQueryDefinition {
  id : String?
  name : String?
  token : String?
  ns : String?
  partition : String?
  service : ServiceQuery?
  dns : DNSQuery?
}

///|
/// The result of executing a query.
pub(all) struct PreparedQueryExecuteResponse {
  service : String?
  datacenter : String?
  nodes : Array[ServiceEntry]?
}

///|
/// Parameters for `execute`: the datacenter to run in, the `near` node to sort
/// by, and a `limit` on nodes returned.
pub(all) struct PreparedQueryExecuteParams {
  ns : String?
  near : String?
  limit : Int32?
}

///|
/// No execution parameters.
pub let default_prepared_query_execute_params : PreparedQueryExecuteParams = {
  ns: None,
  near: None,
  limit: None,
}

///|
/// Create a query, returning its assigned id.
pub fn PreparedQuery::create(
  self : PreparedQuery,
  def : PreparedQueryDefinition,
  options~ : WriteOptions = default_write_options,
) -> (String, WriteMeta) raise Refused {
  let _ = (self, def, options)
  raise Refused::Unimplemented("prepared_query.create")
}

///|
/// Update an existing query.
pub fn PreparedQuery::update(
  self : PreparedQuery,
  def : PreparedQueryDefinition,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, def, options)
  raise Refused::Unimplemented("prepared_query.update")
}

///|
/// Read the query `id` (returns it wrapped in an array, matching the API).
pub fn PreparedQuery::get(
  self : PreparedQuery,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[PreparedQueryDefinition], QueryMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("prepared_query.get")
}

///|
/// Delete the query `id`.
pub fn PreparedQuery::delete(
  self : PreparedQuery,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("prepared_query.delete")
}

///|
/// Execute the query named or identified by `id_or_name`.
pub fn PreparedQuery::execute(
  self : PreparedQuery,
  id_or_name : String,
  params~ : PreparedQueryExecuteParams = default_prepared_query_execute_params,
  options~ : QueryOptions = default_query_options,
) -> (PreparedQueryExecuteResponse, QueryMeta) raise Refused {
  let _ = (self, id_or_name, params, options)
  raise Refused::Unimplemented("prepared_query.execute")
}

///|
/// List every query in the datacenter.
pub fn PreparedQuery::list(
  self : PreparedQuery,
  options~ : QueryOptions = default_query_options,
) -> (Array[PreparedQueryDefinition], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("prepared_query.list")
}
