///|
/// A handle to the ACL API: tokens (the credentials calls carry), policies
/// (rule sets), roles (policy groupings), auth methods and binding rules.
pub struct ACL {
  client : Client
}

///|
/// A link from a token to a policy, by id or name.
pub(all) struct ACLTokenPolicyLink {
  id : String?
  name : String?
}

///|
/// A link from a token to a role, by id or name.
pub(all) struct ACLTokenRoleLink {
  id : String?
  name : String?
}

///|
/// A token: its `accessor_id` (for reference) and `secret_id` (for calls), the
/// `policies` and `roles` it binds, whether it is `is_local` to one datacenter,
/// and its `description` and `hash`.
pub(all) struct ACLToken {
  id : String?
  accessor_id : String?
  secret_id : String?
  description : String?
  policies : Array[ACLTokenPolicyLink]?
  roles : Array[ACLTokenRoleLink]?
  is_local : Bool?
  ns : String?
  partition : String?
  hash : String?
  expiration_time : String?
}

///|
/// A policy: a `name` and its `rules` (HCL or JSON) plus its `description`.
pub(all) struct ACLPolicy {
  id : String?
  name : String?
  description : String?
  rules : String?
  datacenter : String?
  ns : String?
  partition : String?
  hash : String?
}

///|
/// A link from a role to a policy, by id or name.
pub(all) struct ACLRolePolicyLink {
  id : String?
  name : String?
}

///|
/// A role: a `name` grouping `policies`, plus its `description` and `hash`.
pub(all) struct ACLRole {
  id : String?
  name : String?
  description : String?
  policies : Array[ACLRolePolicyLink]?
  ns : String?
  partition : String?
  hash : String?
}

///|
/// An auth method: a `name` and `kind` (e.g. `jwt`, `kubernetes`), its
/// `config`, and its `description`. The configuration is held as JSON because
/// a provider's settings mix strings, numbers, booleans and lists (a JWT
/// method's `JWTValidationPubkeys` is a list of PEM keys).
pub(all) struct ACLAuthMethod {
  name : String?
  kind : String?
  description : String?
  config : Map[String, Json]?
  ns : String?
  partition : String?
}

///|
/// A binding rule: selects identities from an auth method and maps them to a
/// `bind_type`/`bind_name` via `selector`.
pub(all) struct ACLBindingRule {
  id : String?
  description : String?
  auth_method : String?
  selector : String?
  bind_type : String?
  bind_name : String?
  ns : String?
  partition : String?
}

///|
/// Parameters for `token_login`.
pub(all) struct ACLLoginParams {
  auth_method : String?
  bearer_token : String?
  token_metadata : Map[String, String]?
}

///|
/// A token's id for path building: its accessor id, else its id.
fn token_id(t : ACLToken) -> String {
  match t.accessor_id {
    Some(a) => a
    None =>
      match t.id {
        Some(i) => i
        None => ""
      }
  }
}

///|
/// Token policy links as a JSON array.
fn token_policy_links_to_json(links : Array[ACLTokenPolicyLink]) -> Json {
  let arr : Array[Json] = []
  for l in links {
    let m = jobj()
    put_str(m, "ID", l.id)
    put_str(m, "Name", l.name)
    arr.push(@json.to_json(m))
  }
  @json.to_json(arr)
}

///|
/// Token role links as a JSON array.
fn token_role_links_to_json(links : Array[ACLTokenRoleLink]) -> Json {
  let arr : Array[Json] = []
  for l in links {
    let m = jobj()
    put_str(m, "ID", l.id)
    put_str(m, "Name", l.name)
    arr.push(@json.to_json(m))
  }
  @json.to_json(arr)
}

///|
/// An `ACLToken` as its write body.
fn acl_token_to_json(t : ACLToken) -> Json {
  let m = jobj()
  put_str(m, "ID", t.id)
  put_str(m, "AccessorID", t.accessor_id)
  put_str(m, "SecretID", t.secret_id)
  put_str(m, "Description", t.description)
  match t.policies {
    Some(ps) => m["Policies"] = token_policy_links_to_json(ps)
    None => ()
  }
  match t.roles {
    Some(rs) => m["Roles"] = token_role_links_to_json(rs)
    None => ()
  }
  put_bool(m, "Local", t.is_local)
  put_str(m, "Namespace", t.ns)
  put_str(m, "Partition", t.partition)
  put_str(m, "ExpirationTime", t.expiration_time)
  @json.to_json(m)
}

///|
/// An `ACLToken` from its JSON object.
fn acl_token_of(j : Json) -> ACLToken {
  let m = json_map(j)
  let policies : Array[ACLTokenPolicyLink] = []
  for item in jarray(m, "Policies") {
    let pm = json_map(item)
    policies.push({ id: jstr_opt(pm, "ID"), name: jstr_opt(pm, "Name"), })
  }
  let roles : Array[ACLTokenRoleLink] = []
  for item in jarray(m, "Roles") {
    let rm = json_map(item)
    roles.push({ id: jstr_opt(rm, "ID"), name: jstr_opt(rm, "Name"), })
  }
  {
    id: jstr_opt(m, "ID"),
    accessor_id: jstr_opt(m, "AccessorID"),
    secret_id: jstr_opt(m, "SecretID"),
    description: jstr_opt(m, "Description"),
    policies: if policies.length() == 0 {
      None
    } else {
      Some(policies)
    },
    roles: if roles.length() == 0 {
      None
    } else {
      Some(roles)
    },
    is_local: jbool_opt(m, "Local"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    hash: jstr_opt(m, "Hash"),
    expiration_time: jstr_opt(m, "ExpirationTime"),
  }
}

///|
/// An `ACLPolicy` as its write body.
fn acl_policy_to_json(p : ACLPolicy) -> Json {
  let m = jobj()
  put_str(m, "ID", p.id)
  put_str(m, "Name", p.name)
  put_str(m, "Description", p.description)
  put_str(m, "Rules", p.rules)
  put_str(m, "Datacenter", p.datacenter)
  put_str(m, "Namespace", p.ns)
  put_str(m, "Partition", p.partition)
  @json.to_json(m)
}

///|
/// An `ACLPolicy` from its JSON object.
fn acl_policy_of(j : Json) -> ACLPolicy {
  let m = json_map(j)
  {
    id: jstr_opt(m, "ID"),
    name: jstr_opt(m, "Name"),
    description: jstr_opt(m, "Description"),
    rules: jstr_opt(m, "Rules"),
    datacenter: jstr_opt(m, "Datacenter"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    hash: jstr_opt(m, "Hash"),
  }
}

///|
/// An `ACLRole` as its write body.
fn acl_role_to_json(r : ACLRole) -> Json {
  let m = jobj()
  put_str(m, "ID", r.id)
  put_str(m, "Name", r.name)
  put_str(m, "Description", r.description)
  match r.policies {
    Some(ps) => {
      let arr : Array[Json] = []
      for l in ps {
        let lm = jobj()
        put_str(lm, "ID", l.id)
        put_str(lm, "Name", l.name)
        arr.push(@json.to_json(lm))
      }
      m["Policies"] = @json.to_json(arr)
    }
    None => ()
  }
  put_str(m, "Namespace", r.ns)
  put_str(m, "Partition", r.partition)
  @json.to_json(m)
}

///|
/// An `ACLRole` from its JSON object.
fn acl_role_of(j : Json) -> ACLRole {
  let m = json_map(j)
  let policies : Array[ACLRolePolicyLink] = []
  for item in jarray(m, "Policies") {
    let pm = json_map(item)
    policies.push({ id: jstr_opt(pm, "ID"), name: jstr_opt(pm, "Name"), })
  }
  {
    id: jstr_opt(m, "ID"),
    name: jstr_opt(m, "Name"),
    description: jstr_opt(m, "Description"),
    policies: if policies.length() == 0 {
      None
    } else {
      Some(policies)
    },
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
    hash: jstr_opt(m, "Hash"),
  }
}

///|
/// An `ACLAuthMethod` as its write body (the kind is carried as `Type`).
fn acl_auth_method_to_json(a : ACLAuthMethod) -> Json {
  let m = jobj()
  put_str(m, "Name", a.name)
  put_str(m, "Type", a.kind)
  put_str(m, "Description", a.description)
  match a.config {
    Some(cf) => m["Config"] = Json::object(cf)
    None => ()
  }
  put_str(m, "Namespace", a.ns)
  put_str(m, "Partition", a.partition)
  @json.to_json(m)
}

///|
/// An `ACLAuthMethod` from its JSON object.
fn acl_auth_method_of(j : Json) -> ACLAuthMethod {
  let m = json_map(j)
  {
    name: jstr_opt(m, "Name"),
    kind: jstr_opt(m, "Type"),
    description: jstr_opt(m, "Description"),
    config: jobj_opt(m, "Config"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
  }
}

///|
/// An `ACLBindingRule` as its write body.
fn acl_binding_rule_to_json(r : ACLBindingRule) -> Json {
  let m = jobj()
  put_str(m, "ID", r.id)
  put_str(m, "Description", r.description)
  put_str(m, "AuthMethod", r.auth_method)
  put_str(m, "Selector", r.selector)
  put_str(m, "BindType", r.bind_type)
  put_str(m, "BindName", r.bind_name)
  put_str(m, "Namespace", r.ns)
  put_str(m, "Partition", r.partition)
  @json.to_json(m)
}

///|
/// An `ACLBindingRule` from its JSON object.
fn acl_binding_rule_of(j : Json) -> ACLBindingRule {
  let m = json_map(j)
  {
    id: jstr_opt(m, "ID"),
    description: jstr_opt(m, "Description"),
    auth_method: jstr_opt(m, "AuthMethod"),
    selector: jstr_opt(m, "Selector"),
    bind_type: jstr_opt(m, "BindType"),
    bind_name: jstr_opt(m, "BindName"),
    ns: jstr_opt(m, "Namespace"),
    partition: jstr_opt(m, "Partition"),
  }
}

///|
/// An `ACLLoginParams` as its write body.
fn acl_login_params_to_json(p : ACLLoginParams) -> Json {
  let m = jobj()
  put_str(m, "AuthMethod", p.auth_method)
  put_str(m, "BearerToken", p.bearer_token)
  match p.token_metadata {
    Some(md) => m["Meta"] = map_to_json(md)
    None => ()
  }
  @json.to_json(m)
}

///|
/// Create a token.
pub async fn ACL::token_create(
  self : ACL,
  token : ACLToken,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_token_to_json(token).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/token", body, options, [])
  (acl_token_of(json), meta)
}

///|
/// Update a token.
pub async fn ACL::token_update(
  self : ACL,
  token : ACLToken,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_token_to_json(token).stringify())
  let (json, meta) = self.client.do_put(
    "/v1/acl/token/" + token_id(token),
    body,
    options,
    [],
  )
  (acl_token_of(json), meta)
}

///|
/// Read a token by id or accessor id.
pub async fn ACL::token_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLToken, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/token/" + id, options, [])
  (acl_token_of(json), meta)
}

///|
/// Read the token the client is authenticated with.
pub async fn ACL::token_read_self(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (ACLToken, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/token/self", options, [])
  (acl_token_of(json), meta)
}

///|
/// List tokens.
pub async fn ACL::token_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLToken], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/tokens", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ACLToken] = []
  for item in json_array(json) {
    out.push(acl_token_of(item))
  }
  (out, meta)
}

///|
/// Clone a token, returning a new one with the same policies and roles.
pub async fn ACL::token_clone(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let (json, meta) = self.client.do_put(
    "/v1/acl/token/" + id + "/clone",
    b"",
    options,
    [],
  )
  (acl_token_of(json), meta)
}

///|
/// Delete a token by id or accessor id.
pub async fn ACL::token_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/acl/token/" + id, options, [])
  meta
}

///|
/// Exchange an auth-method `bearer_token` for a Consul token.
pub async fn ACL::token_login(
  self : ACL,
  params : ACLLoginParams,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_login_params_to_json(params).stringify())
  let (json, meta) = self.client.do_post("/v1/acl/login", body, options, [])
  (acl_token_of(json), meta)
}

///|
/// Drop the token the client is authenticated with.
pub async fn ACL::token_logout(
  self : ACL,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_post("/v1/acl/logout", b"", options, [])
  meta
}

///|
/// Create a policy.
pub async fn ACL::policy_create(
  self : ACL,
  policy : ACLPolicy,
  options~ : WriteOptions = default_write_options,
) -> (ACLPolicy, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_policy_to_json(policy).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/policy", body, options, [])
  (acl_policy_of(json), meta)
}

///|
/// Update a policy.
pub async fn ACL::policy_update(
  self : ACL,
  policy : ACLPolicy,
  options~ : WriteOptions = default_write_options,
) -> (ACLPolicy, WriteMeta) raise Refused {
  let id = match policy.id {
    Some(i) => i
    None => raise Refused::Param("acl.policy_update: policy.id is required")
  }
  let body = @utf8.encode(acl_policy_to_json(policy).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/policy/" + id, body, options, [])
  (acl_policy_of(json), meta)
}

///|
/// Read a policy by id or name.
pub async fn ACL::policy_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLPolicy, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/policy/" + id, options, [])
  (acl_policy_of(json), meta)
}

///|
/// List policies.
pub async fn ACL::policy_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLPolicy], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/policies", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ACLPolicy] = []
  for item in json_array(json) {
    out.push(acl_policy_of(item))
  }
  (out, meta)
}

///|
/// Delete a policy by id or name.
pub async fn ACL::policy_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/acl/policy/" + id, options, [])
  meta
}

///|
/// Create a role.
pub async fn ACL::role_create(
  self : ACL,
  role : ACLRole,
  options~ : WriteOptions = default_write_options,
) -> (ACLRole, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_role_to_json(role).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/role", body, options, [])
  (acl_role_of(json), meta)
}

///|
/// Update a role.
pub async fn ACL::role_update(
  self : ACL,
  role : ACLRole,
  options~ : WriteOptions = default_write_options,
) -> (ACLRole, WriteMeta) raise Refused {
  let id = match role.id {
    Some(i) => i
    None => raise Refused::Param("acl.role_update: role.id is required")
  }
  let body = @utf8.encode(acl_role_to_json(role).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/role/" + id, body, options, [])
  (acl_role_of(json), meta)
}

///|
/// Read a role by id or name.
pub async fn ACL::role_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLRole, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/role/" + id, options, [])
  (acl_role_of(json), meta)
}

///|
/// Read a role by name.
pub async fn ACL::role_read_by_name(
  self : ACL,
  name : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLRole, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/role/name/" + name, options, [])
  (acl_role_of(json), meta)
}

///|
/// List roles.
pub async fn ACL::role_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLRole], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/roles", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ACLRole] = []
  for item in json_array(json) {
    out.push(acl_role_of(item))
  }
  (out, meta)
}

///|
/// Delete a role by id or name.
pub async fn ACL::role_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/acl/role/" + id, options, [])
  meta
}

///|
/// Create an auth method.
pub async fn ACL::auth_method_create(
  self : ACL,
  entry : ACLAuthMethod,
  options~ : WriteOptions = default_write_options,
) -> (ACLAuthMethod, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_auth_method_to_json(entry).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/auth-method", body, options, [])
  (acl_auth_method_of(json), meta)
}

///|
/// Update an auth method.
pub async fn ACL::auth_method_update(
  self : ACL,
  entry : ACLAuthMethod,
  options~ : WriteOptions = default_write_options,
) -> (ACLAuthMethod, WriteMeta) raise Refused {
  let name = match entry.name {
    Some(n) => n
    None => raise Refused::Param("acl.auth_method_update: name is required")
  }
  let body = @utf8.encode(acl_auth_method_to_json(entry).stringify())
  let (json, meta) = self.client.do_put(
    "/v1/acl/auth-method/" + name,
    body,
    options,
    [],
  )
  (acl_auth_method_of(json), meta)
}

///|
/// Read an auth method by name.
pub async fn ACL::auth_method_read(
  self : ACL,
  name : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLAuthMethod, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get(
    "/v1/acl/auth-method/" + name,
    options,
    [],
  )
  (acl_auth_method_of(json), meta)
}

///|
/// List auth methods.
pub async fn ACL::auth_method_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLAuthMethod], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/auth-methods", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ACLAuthMethod] = []
  for item in json_array(json) {
    out.push(acl_auth_method_of(item))
  }
  (out, meta)
}

///|
/// Delete an auth method by name.
pub async fn ACL::auth_method_delete(
  self : ACL,
  name : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete(
    "/v1/acl/auth-method/" + name,
    options,
    [],
  )
  meta
}

///|
/// Create a binding rule.
pub async fn ACL::binding_rule_create(
  self : ACL,
  rule : ACLBindingRule,
  options~ : WriteOptions = default_write_options,
) -> (ACLBindingRule, WriteMeta) raise Refused {
  let body = @utf8.encode(acl_binding_rule_to_json(rule).stringify())
  let (json, meta) = self.client.do_put("/v1/acl/binding-rule", body, options, [])
  (acl_binding_rule_of(json), meta)
}

///|
/// Update a binding rule.
pub async fn ACL::binding_rule_update(
  self : ACL,
  rule : ACLBindingRule,
  options~ : WriteOptions = default_write_options,
) -> (ACLBindingRule, WriteMeta) raise Refused {
  let id = match rule.id {
    Some(i) => i
    None => raise Refused::Param("acl.binding_rule_update: id is required")
  }
  let body = @utf8.encode(acl_binding_rule_to_json(rule).stringify())
  let (json, meta) = self.client.do_put(
    "/v1/acl/binding-rule/" + id,
    body,
    options,
    [],
  )
  (acl_binding_rule_of(json), meta)
}

///|
/// Read a binding rule by id.
pub async fn ACL::binding_rule_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLBindingRule, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/binding-rule/" + id, options, [])
  (acl_binding_rule_of(json), meta)
}

///|
/// List binding rules.
pub async fn ACL::binding_rule_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLBindingRule], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/acl/binding-rules", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[ACLBindingRule] = []
  for item in json_array(json) {
    out.push(acl_binding_rule_of(item))
  }
  (out, meta)
}

///|
/// Delete a binding rule by id.
pub async fn ACL::binding_rule_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let (_, meta) = self.client.do_delete("/v1/acl/binding-rule/" + id, options, [])
  meta
}
