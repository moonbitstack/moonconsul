// Every API group against a live agent on 127.0.0.1:8500. With no agent the tests return, so the
// unit suite passes on a machine without Consul; with `MOONCONSUL_LIVE` set, as in CI, a missing
// agent fails them.

///|
async fn live() -> @moonconsul.Client? {
  let client = @fetch.connect() catch { _ => return None }
  let up = try client.status().leader().0.length() > 0 catch {
    _ => false
  }
  if up {
    return Some(client)
  }
  if @env.get_env_var("MOONCONSUL_LIVE") is Some(_) {
    fail("no consul on 8500")
  }
  None
}

///|
fn stamped(name : String) -> String {
  "moonconsul-it-\{name}-\{@env.now()}"
}

///|
fn pair_of(key : String, value : Bytes) -> @moonconsul.KVPair {
  {
    key,
    create_index: 0UL,
    modify_index: 0UL,
    lock_index: 0UL,
    flags: 0UL,
    value,
    session: None,
  }
}

///|
async test "kv: put, get, list, delete and compare-and-swap" {
  guard live() is Some(c) else { return }
  let kv = c.kv()
  let root = stamped("kv")
  let key = root + "/a"
  ignore(kv.put(pair_of(key, b"one")))
  guard kv.get(key).0 is Some(pair) else { fail("the key is not there") }
  assert_eq(pair.value, b"one")
  ignore(kv.put(pair_of(root + "/b", b"two")))
  assert_eq(kv.list(root).0.length(), 2)
  assert_eq(kv.keys(root).0.length(), 2)
  // A CAS with a stale index loses, and one with the current index wins.
  let stale = {
    ..pair,
    value: b"stale",
    modify_index: pair.modify_index + 1000,
  }
  assert_false(kv.cas(stale).0)
  assert_true(kv.cas({ ..pair, value: b"fresh", }).0)
  assert_eq(kv.get(key).0.unwrap().value, b"fresh")
  ignore(kv.delete_tree(root))
  assert_true(kv.get(key).0 is None)
}

///|
async test "agent, catalog and health see a service come and go" {
  guard live() is Some(c) else { return }
  let name = stamped("svc")
  let registration = {
    ..@moonconsul.default_service_registration,
    id: Some(name),
    name,
    address: Some("10.1.0.9"),
    port: Some(9000),
    tags: Some(["blue"]),
    check: Some({
      ..@moonconsul.default_service_check,
      ttl: Some("30s"),
      status: Some("passing"),
    }),
  }
  ignore(c.agent().service_register(registration))
  assert_true(c.agent().services().0.contains(name))
  let (entries, _) = c.health().service(name, passing=true)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].service.unwrap().port, Some(9000))
  assert_eq(entries[0].service.unwrap().tags, ["blue"])
  assert_eq(c.catalog().service(name).0.length(), 1)
  assert_true(c.catalog().services().0.contains(name))
  assert_true(c.catalog().nodes().0.length() >= 1)
  // A check that fails takes the instance out of the passing list.
  ignore(c.agent().check_fail("service:" + name))
  assert_eq(c.health().service(name, passing=true).0.length(), 0)
  assert_eq(c.health().service(name).0.length(), 1)
  ignore(c.agent().check_pass("service:" + name))
  assert_eq(c.health().service(name, passing=true).0.length(), 1)
  ignore(c.agent().service_deregister(name))
  assert_eq(c.health().service(name).0.length(), 0)
}

///|
async test "status names a leader and peers" {
  guard live() is Some(c) else { return }
  assert_true(c.status().leader().0.contains(":"))
  assert_true(c.status().peers().0.length() >= 1)
  assert_true(c.agent().self().0.config is Object(_))
}

///|
async test "an event fires and lists" {
  guard live() is Some(c) else { return }
  let name = stamped("event")
  let (fired, _) = c.event().fire(name, b"hi")
  assert_true(fired.id.length() > 0)
  let (listed, _) = c.event().list(options={ name: Some(name), })
  assert_eq(listed.length(), 1)
  assert_eq(listed[0].payload, Some(b"hi"))
}

///|
async test "a prepared query finds a service" {
  guard live() is Some(c) else { return }
  let service = stamped("pq")
  ignore(
    c
    .agent()
    .service_register({
      ..@moonconsul.default_service_registration,
      id: Some(service),
      name: service,
      port: Some(9100),
    }),
  )
  let (id, _) = c
    .prepared_query()
    .create({
      id: None,
      name: Some(service),
      token: None,
      ns: None,
      partition: None,
      service: Some({
        service,
        ns: None,
        tags_any: None,
        only_passing: None,
        node_type: None,
        failover: None,
      }),
      dns: None,
    })
  let (answer, _) = c.prepared_query().execute(id)
  assert_eq(answer.nodes.unwrap_or([]).length(), 1)
  assert_eq(c.prepared_query().get(id).0.length(), 1)
  ignore(c.prepared_query().delete(id))
  ignore(c.agent().service_deregister(service))
}

///|
async test "coordinates answer" {
  guard live() is Some(c) else { return }
  assert_true(c.coordinate().datacenters().0.length() >= 1)
  ignore(c.coordinate().nodes())
}

///|
async test "a config entry is stored, read and deleted" {
  guard live() is Some(c) else { return }
  let name = stamped("defaults")
  let entry = @moonconsul.ServiceDefault({
    name,
    ns: None,
    partition: None,
    protocol: Some("http"),
    mesh_gateway: None,
  })
  ignore(c.config_entries().set(entry))
  assert_true(c.config_entries().list("service-defaults").0.length() >= 1)
  guard c.config_entries().get("service-defaults", name).0
    is ServiceDefault(read) else {
    fail("not the entry written")
  }
  assert_eq(read.protocol, Some("http"))
  ignore(c.config_entries().delete("service-defaults", name))
}

///|
async test "a session that deletes takes its keys with it" {
  guard live() is Some(c) else { return }
  let key = stamped("session")
  let (session, _) = c
    .session()
    .create(entry={
      ..@moonconsul.default_session_entry,
      behavior: Some(Delete),
      lock_delay: Some(0),
    })
  let id = session.id.unwrap()
  assert_true(c.session().info(id).0 is Some(_))
  assert_true(c.session().list().0.iter().any(s => s.id == Some(id)))
  assert_true(c.kv().acquire({ ..pair_of(key, b"v"), session: Some(id), }).0)
  assert_true(c.session().renew(id).0 is Some(_))
  ignore(c.session().destroy(id))
  assert_true(c.kv().get(key).0 is None)
}

///|
async test "the catalog registers a node of its own" {
  guard live() is Some(c) else { return }
  let node = stamped("node")
  let (known, _) = c.catalog().datacenters()
  assert_true(known.length() >= 1)
  ignore(
    c
    .catalog()
    .register({
      node,
      address: "10.2.0.1",
      node_meta: None,
      ns: None,
      partition: None,
      service: None,
      check: None,
      checks: None,
    }),
  )
  assert_true(c.catalog().nodes().0.iter().any(n => n.node == node))
  assert_eq(c.catalog().node(node).0.node.address, "10.2.0.1")
  ignore(
    c
    .catalog()
    .deregister({
      node,
      address: None,
      service_id: None,
      check_id: None,
      ns: None,
      partition: None,
    }),
  )
  assert_false(c.catalog().nodes().0.iter().any(n => n.node == node))
}

///|
async test "the agent reports members and maintenance mode" {
  guard live() is Some(c) else { return }
  assert_true(c.agent().members().0.length() >= 1)
  let name = stamped("maintained")
  ignore(
    c
    .agent()
    .service_register({
      ..@moonconsul.default_service_registration,
      id: Some(name),
      name,
    }),
  )
  assert_eq(c.health().service(name, passing=true).0.length(), 1)
  ignore(c.agent().enable_service_maintenance(name, reason="tested"))
  assert_eq(c.health().service(name, passing=true).0.length(), 0)
  assert_true(c.agent().checks().0.length() >= 1)
  ignore(c.agent().disable_service_maintenance(name))
  assert_eq(c.health().service(name, passing=true).0.length(), 1)
  ignore(c.agent().service_deregister(name))
}

///|
/// The ACL agent `scripts/start_consul.sh` starts, with its management token.
async fn live_acl() -> @moonconsul.Client? {
  guard live() is Some(_) else { return None }
  let client = @fetch.connect(config={
    ..@moonconsul.default_config,
    address: "127.0.0.1:18500",
    token: Some("moonconsul-root"),
  })
  let up = try client.status().leader().0.length() > 0 catch {
    _ => false
  }
  guard up else { fail("no consul on 18500") }
  Some(client)
}

///|
async test "acl: policies, roles and tokens are created, read and deleted" {
  guard live_acl() is Some(c) else { return }
  let acl = c.acl()
  let name = stamped("policy")
  let (policy, _) = acl.policy_create({
    id: None,
    name: Some(name),
    description: None,
    rules: Some("key_prefix \"it/\" { policy = \"read\" }"),
    datacenter: None,
    ns: None,
    partition: None,
    hash: None,
  })
  let policy_id = policy.id.unwrap()
  assert_eq(acl.policy_read(policy_id).0.name, Some(name))
  assert_true(acl.policy_list().0.iter().any(p => p.id == Some(policy_id)))
  let (role, _) = acl.role_create({
    id: None,
    name: Some(stamped("role")),
    description: None,
    policies: Some([{ id: Some(policy_id), name: None, }]),
    ns: None,
    partition: None,
    hash: None,
  })
  let role_id = role.id.unwrap()
  assert_eq(acl.role_read(role_id).0.id, Some(role_id))
  let (token, _) = acl.token_create({
    id: None,
    accessor_id: None,
    secret_id: None,
    description: Some("moonconsul integration"),
    policies: Some([{ id: Some(policy_id), name: None, }]),
    roles: None,
    is_local: None,
    ns: None,
    partition: None,
    hash: None,
    expiration_time: None,
  })
  let accessor = token.accessor_id.unwrap()
  assert_eq(acl.token_read(accessor).0.accessor_id, Some(accessor))
  assert_true(
    acl.token_list().0.iter().any(t => t.accessor_id == Some(accessor)),
  )
  // The token reads what the policy allows and nothing else.
  let limited = @fetch.connect(config={
    ..@moonconsul.default_config,
    address: "127.0.0.1:18500",
    token: token.secret_id,
  })
  ignore(c.kv().put(pair_of("it/readable", b"v")))
  assert_true(limited.kv().get("it/readable").0 is Some(_))
  let denied = try {
    ignore(limited.kv().put(pair_of("it/readable", b"w")))
    false
  } catch {
    @moonconsul.Status(403, _) => true
    _ => false
  }
  assert_true(denied)
  ignore(acl.token_delete(accessor))
  ignore(acl.role_delete(role_id))
  ignore(acl.policy_delete(policy_id))
  ignore(c.kv().delete("it/readable"))
}
