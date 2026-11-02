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
/// A `QueryDatacenterOptions` from its JSON object.
fn query_datacenter_options_of(j : Json) -> QueryDatacenterOptions {
  let m = json_map(j)
  {
    nearest: jbool_opt(m, "Nearest"),
    datacenters: jstr_array_opt(m, "Datacenters"),
  }
}

///|
/// A `QueryDatacenterOptions` as a JSON object.
fn query_datacenter_options_to_json(o : QueryDatacenterOptions) -> Json {
  let m = jobj()
  put_bool(m, "Nearest", o.nearest)
  put_str_array(m, "Datacenters", o.datacenters)
  @json.to_json(m)
}

///|
/// A `ServiceQuery` from its JSON object.
fn service_query_of(j : Json) -> ServiceQuery {
  let m = json_map(j)
  {
    service: jstr(m, "Service"),
    ns: jstr_opt(m, "Namespace"),
    tags_any: jstr_array_opt(m, "Tags"),
    only_passing: jbool_opt(m, "OnlyPassing"),
    node_type: jstr_opt(m, "NodeType"),
    failover: match m.get("Failover") {
      Some(f) =>
        if f is Object(_) {
          Some(query_datacenter_options_of(f))
        } else {
          None
        }
      None => None
    },
  }
}

///|
/// A `ServiceQuery` as a JSON object.
fn service_query_to_json(q : ServiceQuery) -> Json {
  let m = jobj()
  put_str(m, "Service", Some(q.service))
  put_str(m, "Namespace", q.ns)
  put_str_array(m, "Tags", q.tags_any)
  put_bool(m, "OnlyPassing", q.only_passing)
  put_str(m, "NodeType", q.node_type)
  match q.failover {
    Some(f) => m["Failover"] = query_datacenter_options_to_json(f)
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `DNSQuery` from its JSON object.
fn dns_query_of(j : Json) -> DNSQuery {
  let m = json_map(j)
  { ttl: jstr_opt(m, "TTL"), }
}

///|
/// A `DNSQuery` as a JSON object.
fn dns_query_to_json(d : DNSQuery) -> Json {
  let m = jobj()
  put_str(m, "TTL", d.ttl)
  @json.to_json(m)
}

///|
/// A `PreparedQueryDefinition` from its JSON object.
fn prepared_query_definition_of(j : Json) -> PreparedQueryDefinition {
  let m = json_map(j)
  {
    id: jstr_opt(m, "ID"),
    name: jstr_opt(m, "Name"),
    token: jstr_opt(m, "Token"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    service: match m.get("Service") {
      Some(s) => if s is Object(_) { Some(service_query_of(s)) } else { None }
      None => None
    },
    dns: match m.get("DNS") {
      Some(d) => if d is Object(_) { Some(dns_query_of(d)) } else { None }
      None => None
    },
  }
}

///|
/// A `PreparedQueryDefinition` as its write body.
fn prepared_query_definition_to_json(d : PreparedQueryDefinition) -> Json {
  let m = jobj()
  put_str(m, "ID", d.id)
  put_str(m, "Name", d.name)
  put_str(m, "Token", d.token)
  put_str(m, "Namespace", d.ns)
  put_str(m, "Partition", d.partition)
  match d.service {
    Some(s) => m["Service"] = service_query_to_json(s)
    None => ()
  }
  match d.dns {
    Some(x) => m["DNS"] = dns_query_to_json(x)
    None => ()
  }
  @json.to_json(m)
}

///|
/// A `PreparedQueryExecuteResponse` from its JSON object.
fn prepared_query_execute_response_of(j : Json) -> PreparedQueryExecuteResponse {
  let m = json_map(j)
  let nodes : Array[ServiceEntry] = []
  for item in jarray(m, "Nodes") {
    nodes.push(service_entry_of(item))
  }
  {
    service: jstr_opt(m, "Service"),
    datacenter: jstr_opt(m, "Datacenter"),
    nodes: if nodes.length() == 0 {
      None
    } else {
      Some(nodes)
    },
  }
}

///|
/// Create a query, returning its assigned id.
pub async fn PreparedQuery::create(
  self : PreparedQuery,
  def : PreparedQueryDefinition,
  options~ : WriteOptions = default_write_options,
) -> (String, WriteMeta) raise Refused {
  let body = @utf8.encode(prepared_query_definition_to_json(def).stringify())
  let (json, meta) = self.client.do_post("/v1/query", body, options, [])
  (jstr(json_map(json), "ID"), meta)
}

///|
/// Update an existing query.
pub async fn PreparedQuery::update(
  self : PreparedQuery,
  def : PreparedQueryDefinition,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(prepared_query_definition_to_json(def).stringify())
  guard def.id is Some(id) else {
    raise Refused::Param("prepared query: updating needs an id")
  }
  let (_, meta) = self.client.do_put("/v1/query/" + id, body, options, [])
  meta
}

///|
/// Read the query `id` (returns it wrapped in an array, matching the API).
pub async fn PreparedQuery::get(
  self : PreparedQuery,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (Array[PreparedQueryDefinition], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/query/" + id, options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[PreparedQueryDefinition] = []
  for item in json_array(json) {
    out.push(prepared_query_definition_of(item))
  }
  (out, meta)
}

///|
/// Delete the query `id`.
pub async fn PreparedQuery::delete(
  self : PreparedQuery,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/query/" + id, options, [])
  meta
}

///|
/// Execute the query named or identified by `id_or_name`.
pub async fn PreparedQuery::execute(
  self : PreparedQuery,
  id_or_name : String,
  params~ : PreparedQueryExecuteParams = default_prepared_query_execute_params,
  options~ : QueryOptions = default_query_options,
) -> (PreparedQueryExecuteResponse, QueryMeta) raise Refused {
  let extra : Array[(String, String)] = []
  match params.ns {
    Some(v) => extra.push(("ns", v))
    None => ()
  }
  match params.near {
    Some(v) => extra.push(("near", v))
    None => ()
  }
  match params.limit {
    Some(v) => extra.push(("limit", v.to_string()))
    None => ()
  }
  let (json, meta) = self.client.do_get(
    "/v1/query/" + id_or_name + "/execute",
    options,
    extra,
  )
  (prepared_query_execute_response_of(json), meta)
}

///|
/// List every query in the datacenter.
pub async fn PreparedQuery::list(
  self : PreparedQuery,
  options~ : QueryOptions = default_query_options,
) -> (Array[PreparedQueryDefinition], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/query", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[PreparedQueryDefinition] = []
  for item in json_array(json) {
    out.push(prepared_query_definition_of(item))
  }
  (out, meta)
}
