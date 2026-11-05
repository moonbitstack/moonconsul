// Intentions: the allow/deny rules of the Connect service graph. An intention
// names a source and a destination service (either may be the wildcard `*`) and
// the action to take; the agent picks the most specific match, so each carries
// a read-only `precedence` the match reply is ordered by.

///|
/// What an intention does with a connection it matches.
pub(all) enum IntentionAction {
  /// Let the connection through.
  Allow
  /// Refuse the connection.
  Deny
}

///|
/// The wire value of an action: `allow` or `deny`.
pub fn IntentionAction::code(self : IntentionAction) -> String {
  match self {
    Allow => "allow"
    Deny => "deny"
  }
}

///|
/// An action from its wire value, or `None` for anything else.
pub fn IntentionAction::of(text : StringView) -> IntentionAction? {
  match text {
    "allow" => Some(Allow)
    "deny" => Some(Deny)
    _ => None
  }
}

///|
/// Which half of an intention a match or a check looks up by.
pub(all) enum IntentionMatchBy {
  /// Look up the intentions whose source is the name given.
  Source
  /// Look up the intentions whose destination is the name given.
  Destination
}

///|
/// The wire value of a match target: `source` or `destination`.
pub fn IntentionMatchBy::code(self : IntentionMatchBy) -> String {
  match self {
    Source => "source"
    Destination => "destination"
  }
}

///|
/// One intention of the service graph. `source` and `destination` name a
/// service, `ns` and `partition` where it lives (either may be the wildcard
/// `*`), and `*` as the whole name matches any service. `precedence` is the
/// agent's: the higher it is, the earlier the intention is considered, and an
/// exact pair outranks a wildcard.
pub(all) struct Intention {
  /// The agent's id for the intention, absent on agents that name intentions by
  /// their service pair instead.
  id : String?
  description : String?
  source_ns : String?
  source_name : String
  source_partition : String?
  source_peer : String?
  destination_ns : String?
  destination_name : String
  destination_partition : String?
  /// How the source is named: `consul` for a catalog service.
  source_type : String?
  action : IntentionAction
  meta : Map[String, String]?
  /// Layer-7 permissions, carried as the JSON the agent serves so that a rule
  /// this library does not model survives a read and a write.
  permissions : Json?
  /// The agent's ordering weight; a read-only field.
  precedence : Int32
  created_at : String?
  updated_at : String?
  create_index : UInt64
  modify_index : UInt64
}

///|
/// An intention with only the two service names set, denying by default: the
/// starting point for one built field by field.
pub let default_intention : Intention = {
  id: None,
  description: None,
  source_ns: None,
  source_name: "",
  source_partition: None,
  source_peer: None,
  destination_ns: None,
  destination_name: "",
  destination_partition: None,
  source_type: None,
  action: Deny,
  meta: None,
  permissions: None,
  precedence: 0,
  created_at: None,
  updated_at: None,
  create_index: 0UL,
  modify_index: 0UL,
}

///|
/// An intention from `source` to `destination` with `action`, both names in the
/// default namespace.
pub fn Intention::new(
  source : String,
  destination : String,
  action : IntentionAction,
) -> Intention {
  {
    ..default_intention,
    source_name: source,
    destination_name: destination,
    action,
  }
}

///|
/// An `Intention` as its write body.
fn intention_to_json(i : Intention) -> Json {
  let m = jobj()
  put_str(m, "Description", i.description)
  put_str(m, "SourceNS", i.source_ns)
  put_str(m, "SourceName", Some(i.source_name))
  put_str(m, "SourcePartition", i.source_partition)
  put_str(m, "SourcePeer", i.source_peer)
  put_str(m, "DestinationNS", i.destination_ns)
  put_str(m, "DestinationName", Some(i.destination_name))
  put_str(m, "DestinationPartition", i.destination_partition)
  put_str(m, "SourceType", i.source_type)
  put_str(m, "Action", Some(i.action.code()))
  match i.meta {
    Some(md) => m["Meta"] = map_to_json(md)
    None => ()
  }
  put_json(m, "Permissions", i.permissions)
  Json::object(m)
}

///|
/// An `Intention` from its JSON object.
fn intention_of(j : Json) -> Intention {
  let m = json_map(j)
  {
    id: jstr_opt(m, "ID"),
    description: jstr_opt(m, "Description"),
    source_ns: jstr_opt(m, "SourceNS"),
    source_name: jstr(m, "SourceName"),
    source_partition: jstr_opt(m, "SourcePartition"),
    source_peer: jstr_opt(m, "SourcePeer"),
    destination_ns: jstr_opt(m, "DestinationNS"),
    destination_name: jstr(m, "DestinationName"),
    destination_partition: jstr_opt(m, "DestinationPartition"),
    source_type: jstr_opt(m, "SourceType"),
    action: match m.get("Action") {
      Some(String(s)) => IntentionAction::of(s[:]).unwrap_or(Deny)
      _ => Deny
    },
    meta: jmap_opt(m, "Meta"),
    permissions: m.get("Permissions"),
    precedence: ji32(m, "Precedence"),
    created_at: jstr_opt(m, "CreatedAt"),
    updated_at: jstr_opt(m, "UpdatedAt"),
    create_index: ju64(m, "CreateIndex"),
    modify_index: ju64(m, "ModifyIndex"),
  }
}

///|
/// The `source` or `destination` parameter of the exact-intention endpoints: a
/// bare name in the default namespace, otherwise the namespaces and partitions
/// in front of it, as the agent writes them.
fn intention_ref(partition : String?, ns : String?, name : String) -> String {
  match (partition, ns) {
    (None, None) => name
    (None, Some(n)) => n + "/" + name
    (Some(p), None) => p + "/default/" + name
    (Some(p), Some(n)) => p + "/" + n + "/" + name
  }
}

///|
/// The `source` parameter naming this intention's source.
pub fn Intention::source_ref(self : Intention) -> String {
  intention_ref(self.source_partition, self.source_ns, self.source_name)
}

///|
/// The `destination` parameter naming this intention's destination.
pub fn Intention::destination_ref(self : Intention) -> String {
  intention_ref(
    self.destination_partition,
    self.destination_ns,
    self.destination_name,
  )
}

///|
/// Order intentions the way the agent ranks them: the highest precedence first.
fn sort_by_precedence(list : Array[Intention]) -> Unit {
  list.sort_by((a, b) => b.precedence - a.precedence)
}

///|
/// Every intention in the datacenter, highest precedence first.
pub async fn Connect::intention_list(
  self : Connect,
  options~ : QueryOptions = default_query_options,
) -> (Array[Intention], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/connect/intentions", options, [])
  let out : Array[Intention] = []
  for item in json_array(json) {
    out.push(intention_of(item))
  }
  sort_by_precedence(out)
  (out, meta)
}

///|
/// One intention by the agent's id, or `None` when there is none.
pub async fn Connect::intention_get(
  self : Connect,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (Intention?, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get_found(
    "/v1/connect/intentions/" + url_encode(id),
    options,
    [],
  )
  (json.map(intention_of), meta)
}

///|
/// One intention by the pair of services it names, or `None` when there is
/// none. `source` and `destination` are names, `namespace/name` when the
/// service lives outside the default namespace.
pub async fn Connect::intention_get_exact(
  self : Connect,
  source : String,
  destination : String,
  options~ : QueryOptions = default_query_options,
) -> (Intention?, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get_found(
    "/v1/connect/intentions/exact",
    options,
    [("source", source), ("destination", destination)],
  )
  (json.map(intention_of), meta)
}

///|
/// Create the intention, or replace the one between the same two services.
/// Creating and updating are the same request: the pair of services names the
/// intention.
pub async fn Connect::intention_upsert(
  self : Connect,
  intention : Intention,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  if intention.source_name == "" || intention.destination_name == "" {
    raise Refused::Param(
      "intention_upsert: source_name and destination_name are required",
    )
  }
  let body = @utf8.encode(intention_to_json(intention).stringify())
  let (_, meta) = self.client.do_put(
    "/v1/connect/intentions/exact",
    body,
    options,
    [
      ("source", intention.source_ref()),
      ("destination", intention.destination_ref()),
    ],
  )
  meta
}

///|
/// Delete the intention with the agent's id.
pub async fn Connect::intention_delete(
  self : Connect,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete(
    "/v1/connect/intentions/" + url_encode(id),
    options,
    [],
  )
  meta
}

///|
/// Delete the intention between the two services named.
pub async fn Connect::intention_delete_exact(
  self : Connect,
  source : String,
  destination : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete(
    "/v1/connect/intentions/exact",
    options,
    [("source", source), ("destination", destination)],
  )
  meta
}

///|
/// The intentions that come into play for each name given, keyed by that name,
/// highest precedence first. Matching by source answers "what may reach this
/// service", matching by destination "what may this service reach".
pub async fn Connect::intention_match(
  self : Connect,
  by : IntentionMatchBy,
  names : Array[String],
  options~ : QueryOptions = default_query_options,
) -> (Map[String, Array[Intention]], QueryMeta) raise Refused {
  let extra : Array[(String, String)] = [("by", by.code())]
  for name in names {
    extra.push(("name", name))
  }
  let (json, meta) = self.client.do_get(
    "/v1/connect/intentions/match", options, extra,
  )
  let out : Map[String, Array[Intention]] = Map([])
  guard json is Object(entries) else {
    raise Refused::Json("intention match: expected an object")
  }
  for name, value in entries {
    let list : Array[Intention] = []
    for item in json_array(value) {
      list.push(intention_of(item))
    }
    sort_by_precedence(list)
    out[name] = list
  }
  (out, meta)
}

///|
/// Whether a connection from `source` to `destination` would be allowed, as the
/// agent decides it from the intentions in place.
pub async fn Connect::intention_check(
  self : Connect,
  source : String,
  destination : String,
  source_type~ : String = "",
  options~ : QueryOptions = default_query_options,
) -> (Bool, QueryMeta) raise Refused {
  let extra : Array[(String, String)] = [
    ("source", source),
    ("destination", destination),
  ]
  if source_type != "" {
    extra.push(("source-type", source_type))
  }
  let (json, meta) = self.client.do_get(
    "/v1/connect/intentions/check", options, extra,
  )
  (jbool(json_map(json), "Allowed"), meta)
}
