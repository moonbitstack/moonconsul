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
/// An auth method: a `name` and `kind` (e.g. `kubernetes`, `oidc`), its
/// `config`, and its `description`.
pub(all) struct ACLAuthMethod {
  name : String?
  kind : String?
  description : String?
  config : Map[String, String]?
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
/// Create a token.
pub fn ACL::token_create(
  self : ACL,
  token : ACLToken,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let _ = (self, token, options)
  raise Refused::Unimplemented("acl.token.create")
}

///|
/// Update a token.
pub fn ACL::token_update(
  self : ACL,
  token : ACLToken,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let _ = (self, token, options)
  raise Refused::Unimplemented("acl.token.update")
}

///|
/// Read a token by id or accessor id.
pub fn ACL::token_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLToken, QueryMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.token.read")
}

///|
/// Read the token the client is authenticated with.
pub fn ACL::token_read_self(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (ACLToken, QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.token.read_self")
}

///|
/// List tokens.
pub fn ACL::token_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLToken], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.token.list")
}

///|
/// Clone a token, returning a new one with the same policies and roles.
pub fn ACL::token_clone(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.token.clone")
}

///|
/// Delete a token by id or accessor id.
pub fn ACL::token_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.token.delete")
}

///|
/// Exchange an auth-method `bearer_token` for a Consul token.
pub fn ACL::token_login(
  self : ACL,
  params : ACLLoginParams,
  options~ : WriteOptions = default_write_options,
) -> (ACLToken, WriteMeta) raise Refused {
  let _ = (self, params, options)
  raise Refused::Unimplemented("acl.token.login")
}

///|
/// Drop the token the client is authenticated with.
pub fn ACL::token_logout(
  self : ACL,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.token.logout")
}

///|
/// Create a policy.
pub fn ACL::policy_create(
  self : ACL,
  policy : ACLPolicy,
  options~ : WriteOptions = default_write_options,
) -> (ACLPolicy, WriteMeta) raise Refused {
  let _ = (self, policy, options)
  raise Refused::Unimplemented("acl.policy.create")
}

///|
/// Update a policy.
pub fn ACL::policy_update(
  self : ACL,
  policy : ACLPolicy,
  options~ : WriteOptions = default_write_options,
) -> (ACLPolicy, WriteMeta) raise Refused {
  let _ = (self, policy, options)
  raise Refused::Unimplemented("acl.policy.update")
}

///|
/// Read a policy by id or name.
pub fn ACL::policy_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLPolicy, QueryMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.policy.read")
}

///|
/// List policies.
pub fn ACL::policy_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLPolicy], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.policy.list")
}

///|
/// Delete a policy by id or name.
pub fn ACL::policy_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.policy.delete")
}

///|
/// Create a role.
pub fn ACL::role_create(
  self : ACL,
  role : ACLRole,
  options~ : WriteOptions = default_write_options,
) -> (ACLRole, WriteMeta) raise Refused {
  let _ = (self, role, options)
  raise Refused::Unimplemented("acl.role.create")
}

///|
/// Update a role.
pub fn ACL::role_update(
  self : ACL,
  role : ACLRole,
  options~ : WriteOptions = default_write_options,
) -> (ACLRole, WriteMeta) raise Refused {
  let _ = (self, role, options)
  raise Refused::Unimplemented("acl.role.update")
}

///|
/// Read a role by id or name.
pub fn ACL::role_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLRole, QueryMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.role.read")
}

///|
/// Read a role by name.
pub fn ACL::role_read_by_name(
  self : ACL,
  name : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLRole, QueryMeta) raise Refused {
  let _ = (self, name, options)
  raise Refused::Unimplemented("acl.role.read_by_name")
}

///|
/// List roles.
pub fn ACL::role_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLRole], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.role.list")
}

///|
/// Delete a role by id or name.
pub fn ACL::role_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.role.delete")
}

///|
/// Create an auth method.
pub fn ACL::auth_method_create(
  self : ACL,
  entry : ACLAuthMethod,
  options~ : WriteOptions = default_write_options,
) -> (ACLAuthMethod, WriteMeta) raise Refused {
  let _ = (self, entry, options)
  raise Refused::Unimplemented("acl.auth_method.create")
}

///|
/// Update an auth method.
pub fn ACL::auth_method_update(
  self : ACL,
  entry : ACLAuthMethod,
  options~ : WriteOptions = default_write_options,
) -> (ACLAuthMethod, WriteMeta) raise Refused {
  let _ = (self, entry, options)
  raise Refused::Unimplemented("acl.auth_method.update")
}

///|
/// Read an auth method by name.
pub fn ACL::auth_method_read(
  self : ACL,
  name : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLAuthMethod, QueryMeta) raise Refused {
  let _ = (self, name, options)
  raise Refused::Unimplemented("acl.auth_method.read")
}

///|
/// List auth methods.
pub fn ACL::auth_method_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLAuthMethod], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.auth_method.list")
}

///|
/// Delete an auth method by name.
pub fn ACL::auth_method_delete(
  self : ACL,
  name : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, name, options)
  raise Refused::Unimplemented("acl.auth_method.delete")
}

///|
/// Create a binding rule.
pub fn ACL::binding_rule_create(
  self : ACL,
  rule : ACLBindingRule,
  options~ : WriteOptions = default_write_options,
) -> (ACLBindingRule, WriteMeta) raise Refused {
  let _ = (self, rule, options)
  raise Refused::Unimplemented("acl.binding_rule.create")
}

///|
/// Update a binding rule.
pub fn ACL::binding_rule_update(
  self : ACL,
  rule : ACLBindingRule,
  options~ : WriteOptions = default_write_options,
) -> (ACLBindingRule, WriteMeta) raise Refused {
  let _ = (self, rule, options)
  raise Refused::Unimplemented("acl.binding_rule.update")
}

///|
/// Read a binding rule by id.
pub fn ACL::binding_rule_read(
  self : ACL,
  id : String,
  options~ : QueryOptions = default_query_options,
) -> (ACLBindingRule, QueryMeta) raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.binding_rule.read")
}

///|
/// List binding rules.
pub fn ACL::binding_rule_list(
  self : ACL,
  options~ : QueryOptions = default_query_options,
) -> (Array[ACLBindingRule], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("acl.binding_rule.list")
}

///|
/// Delete a binding rule by id.
pub fn ACL::binding_rule_delete(
  self : ACL,
  id : String,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, id, options)
  raise Refused::Unimplemented("acl.binding_rule.delete")
}
