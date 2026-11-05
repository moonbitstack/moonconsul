# moonconsul

A Consul client for MoonBit, with the surface of HashiCorp's Go
[`consul/api`](https://github.com/hashicorp/consul/tree/main/api): Agent,
Catalog, Health, KV, Session, Event, ACL, Status, Coordinate, Prepared Query,
Config Entries and Connect, plus locks, semaphores and watches. MoonBit types and
`snake_case` names follow the organisation's conventions; the wire format,
endpoints and semantics follow that package, and the tests run against real
agents.

## Quick start

```moonbit
async fn main {
  let client = @fetch.connect()
  ignore(client.kv().put(pair))
  let lock = @concurrency.Lock::new(client, "jobs/nightly")
  lock.hold(() => run_the_job())
}
```

`moonconsul` needs nothing but a `Transport`, so it runs on every backend.
`moonconsul/fetch` is the transport over moonfetch; `connect(config~)` gives a
client for the agent `config` names, and `default_config` is
`http://127.0.0.1:8500` with no token.

| Package | Holds |
|:--|:--|
| `moonbitstack/moonconsul` | The API groups, `Transport`, `Client::poll` |
| `moonbitstack/moonconsul/fetch` | `Fetch`, `connect` |
| `moonbitstack/moonconsul/concurrency` | `Lock`, `Semaphore`, `keep_alive`, `watch`: what waits |
| `moonbitstack/moonconsul/sd` | `Registry`, moonsd's `Registrar` and `Discovery` on Consul |

Examples are in `src/examples/`, each run with `moon run src/examples/<name>
--target native` against `consul agent -dev`.

## API surface

Each group is a `pub struct` returned by a `Client` accessor. Reads take
`QueryOptions` and return `(Result, QueryMeta)`; writes take `WriteOptions` and
return `WriteMeta`; every call raises `Refused` (see Errors).

### Agent — `client.agent()`

Service and check lifecycle on this agent, plus cluster membership and
maintenance mode.

| Method | Intent |
|:--|:--|
| `service_register(reg, options~)` | Register a service (with inline checks) on this agent |
| `service_deregister(id, options~)` | Deregister a service instance |
| `check_register(reg, options~)` | Register a check (optionally bound to a service) |
| `check_deregister(check_id, options~)` | Deregister a check |
| `check_pass(check_id, options~)` | Mark a TTL/HTTP/TCP/gRPC check passing |
| `check_fail(check_id, options~)` | Mark a check failing |
| `check_update(update, options~)` | Set a TTL check's status/output without resetting its clock |
| `self(options~)` | This agent's config, member record and stats |
| `members(options~)` | Cluster members this agent gossips with |
| `members_with_filter(filter, options~)` | Members, requiring a tag filter |
| `join(address, wan~, options~)` | Ask an agent to join the cluster (LAN or WAN) |
| `leave(options~)` | Leave the cluster gracefully |
| `force_leave(node, options~)` | Force a node out without its cooperation |
| `enable_service_maintenance(service_id, reason~, options~)` | Put a service instance in maintenance mode |
| `disable_service_maintenance(service_id, options~)` | Take a service instance out of maintenance mode |
| `enable_node_maintenance(reason~, options~)` | Put the whole node in maintenance mode |
| `disable_node_maintenance(options~)` | Take the node out of maintenance mode |
| `update_acl_token(token, options~)` | Replace the agent's local ACL token |
| `connect_roots(options~)` | The Connect CA roots this agent trusts (blocking) |
| `connect_leaf(service_id, options~)` | Issue a leaf certificate for a service |
| `connect_authorize(params, options~)` | Whether a client certificate may reach a service |

### Catalog — `client.catalog()`

Datacenter-wide registration and read-only listing of nodes and services.

| Method | Intent |
|:--|:--|
| `register(reg, options~)` | Register a node/service/check against the catalog |
| `deregister(dereg, options~)` | Remove a node, service or check from the catalog |
| `datacenters(options~)` | Datacenters in the WAN federation |
| `nodes(options~)` | Nodes in this datacenter |
| `node(node, options~)` | One node and every service on it |
| `services(options~)` | Service names, each with its tag set |
| `service(service, options~)` | Instances of a service in this datacenter |

### Health — `client.health()`

Checks and the healthy instances of a service, including blocking queries that
watch a service for membership changes.

| Method | Intent |
|:--|:--|
| `node(node, options~)` | Checks on a node |
| `checks(service, options~)` | Checks belonging to a service |
| `checks_in_state(state, options~)` | Checks in a given state |
| `service(service, passing~, options~)` | Healthy instances of a service (blocking) |
| `state(state, options~)` | Checks in any of the three states |
| `connect_service(service, passing~, options~)` | Only connect-mesh-reachable instances |

### KV — `client.kv()`

The key/value store. `flags` and the indexes are `UInt64`, as Consul has them.

| Method | Intent |
|:--|:--|
| `get(key, options~)` | Read one key (`None` when absent) |
| `list(prefix, options~)` | Every entry under a prefix |
| `keys(prefix, options~)` | Only the keys under a prefix |
| `put(pair, options~)` | Write a pair |
| `delete(key, options~)` | Delete a key |
| `delete_cas(pair, options~)` | Delete a key if its index still matches; `true` on success |
| `delete_tree(prefix, options~)` | Delete every entry under a prefix |
| `cas(pair, options~)` | Compare-and-swap; `true` on success |
| `acquire(pair, options~)` | Acquire the lock on a key for a session |
| `release(pair, options~)` | Release the lock held by a session |
| `txn(ops, options~)` | Atomic batch of read and write operations |

### Session — `client.session()`

Ephemeral leases bound to a set of checks; they back locks and semaphores. When
a session's checks fail or its TTL lapses, its held keys are released.

| Method | Intent |
|:--|:--|
| `create(entry~, options~)` | Create a session; the result carries the assigned id |
| `destroy(id, options~)` | Destroy a session, releasing everything it holds |
| `renew(id, options~)` | Renew a session; `None` if it expired |
| `info(id, options~)` | Read one session by id |
| `node(node, options~)` | Sessions active on a node |
| `list(options~)` | Every session in the datacenter |

`lock_delay` is in nanoseconds, and Consul reads a value under 1000 as seconds.
`@concurrency.keep_alive` renews a session until its task is cancelled.

### Event — `client.event()`

User events fanned out across the datacenter, optionally scoped to nodes,
services or tags.

| Method | Intent |
|:--|:--|
| `fire(name, payload, options~, write_options~)` | Fire an event, returning the accepted event |
| `list(options~, query_options~)` | List events, optionally by name |

### ACL — `client.acl()`

Tokens, policies, roles, auth methods and binding rules.

*Tokens*: `token_create`, `token_update`, `token_read`, `token_read_self`,
`token_list`, `token_clone`, `token_delete`, `token_login`, `token_logout`.
*Policies*: `policy_create`, `policy_update`, `policy_read`, `policy_list`,
`policy_delete`.
*Roles*: `role_create`, `role_update`, `role_read`, `role_read_by_name`,
`role_list`, `role_delete`.
*Auth methods*: `auth_method_create`, `auth_method_update`, `auth_method_read`,
`auth_method_list`, `auth_method_delete`. An auth method's `config` is JSON
(`Map[String, Json]`): a provider's settings mix strings, numbers and lists, as
a JWT method's `JWTValidationPubkeys` does. `token_login` trades a bearer token
for a Consul token through such a method, and `token_logout` ends it.
*Binding rules*: `binding_rule_create`, `binding_rule_update`,
`binding_rule_read`, `binding_rule_list`, `binding_rule_delete`.

### Status — `client.status()`

| Method | Intent |
|:--|:--|
| `leader(options~)` | Address of the Raft leader (empty if none) |
| `peers(options~)` | Raft peer addresses of the cluster |

### Coordinate — `client.coordinate()`

Network coordinates (Vivaldi-embedded positions) for latency-aware routing.

| Method | Intent |
|:--|:--|
| `datacenters(options~)` | Coordinates of every datacenter |
| `nodes(options~)` | Coordinates of the nodes in this datacenter |
| `update(coord, options~)` | Publish this node's own coordinate |

### Prepared Query — `client.prepared_query()`

Named and templated service queries with failover.

| Method | Intent |
|:--|:--|
| `create(def, options~)` | Create a query; result carries the assigned id |
| `update(def, options~)` | Update an existing query |
| `get(id, options~)` | Read a query by id |
| `delete(id, options~)` | Delete a query |
| `execute(id_or_name, params~, options~)` | Run a query by id or name |
| `list(options~)` | List every query in the datacenter |

### Config Entries — `client.config_entries()`

Typed, centrally-stored configuration objects (service defaults, routers,
splitters, resolvers, mesh-wide settings). A read returns the `ConfigEntry`
variant for the stored `kind`; a write carries the variant to store.

| Method | Intent |
|:--|:--|
| `get(kind, name, options~)` | Read one config entry |
| `list(kind, options~)` | List the entries of one `kind` |
| `set(entry, options~)` | Write a config entry |
| `delete(kind, name, options~)` | Delete a config entry |

### Connect — `client.connect()`

The certificate authority and the intentions of the service mesh. An agent
issues the leaves (see `Agent`), so the cluster-wide reads go through here.

| Method | Intent |
|:--|:--|
| `ca_roots(options~)` | The roots every service trusts, with the trust domain |
| `ca_config(options~)` | The cluster's CA provider and its settings |
| `ca_set_config(config, options~)` | Replace the CA configuration |
| `intention_list(options~)` | Every intention, highest precedence first |
| `intention_get(id, options~)` | One intention by the agent's id (`None` if absent) |
| `intention_get_exact(source, destination, options~)` | One intention by its pair of services |
| `intention_upsert(intention, options~)` | Create the pair's intention, or replace it |
| `intention_delete(id, options~)` | Delete an intention by id |
| `intention_delete_exact(source, destination, options~)` | Delete the pair's intention |
| `intention_match(by, names, options~)` | The intentions that bear on each name, highest precedence first |
| `intention_check(source, destination, options~)` | Whether the pair would be allowed |

A leaf's identity is its SPIFFE URI, `spiffe://<trust domain>/ns/<namespace>/dc/
<datacenter>/svc/<service>`, and the certificate carries it. `LeafCert` hands
back the certificate, its key, the serial number and that URI:

```moonbit
let (leaf, _) = client.agent().connect_leaf("web")
let (decision, _) = client
  .agent()
  .connect_authorize({
    target: "db",
    client_cert_uri: leaf.service_uri,
    client_cert_serial: leaf.serial_number,
  })
println("\{leaf.service_uri}: \{decision.authorized} (\{decision.reason})")
```

`Intention` covers both directions of a rule: `source_name` and
`destination_name` (either may be the wildcard `*`), `source_ns` and
`destination_ns`, `action`, `meta`, and the layer-7 `permissions` carried as the
JSON the agent serves. `precedence` is the agent's ranking — an exact pair
outranks a wildcard — and every list this API returns is ordered by it.

```moonbit
let rule = {
  ..@moonconsul.Intention::new("web", "db", Allow),
  description: Some("the web tier writes to the database"),
}
ignore(client.connect().intention_upsert(rule))

let allowed = client.connect().intention_check("web", "db").0
let (matched, _) = client.connect().intention_match(Source, ["web"])
let rules = matched.get("web").unwrap_or([])
println("\{allowed}, with \{rules.length()} intentions to consider")
```

### Locks and semaphores

`@concurrency.Lock` and `@concurrency.Semaphore` run the protocol of Go's
`api.Lock` and `api.Semaphore`, which is what `consul lock` runs, so a lock here
and one held by that command exclude each other. A test checks this against the
command.

```moonbit
let lock = @concurrency.Lock::new(client, "jobs/nightly")
lock.hold(() => run_the_job())

let seats = @concurrency.Semaphore::new(client, "jobs/workers", 4)
seats.hold(() => run_a_worker())
```

| Method | Does |
|:--|:--|
| `hold(body)` | Wait for it, run `body` with the session renewed, give it back. If it is lost, `body` is cancelled and this raises `Conflict` |
| `acquire()` | Wait for it. The session is renewed only during the wait, so a holder runs `keep_alive` itself |
| `try_acquire()` | Take it if it is free now |
| `release()` | Give it back, and destroy a session this value created |
| `destroy()` | Delete the keys of one nobody holds |

Cancelling the task gives up a wait, so `@async.with_timeout` bounds one.
`LockOptions` and `SemaphoreOptions` default to Go's values; pass `session` to
run on a session of your own, which then stays yours to renew and destroy.

### Blocking queries and watches

Reads take `QueryOptions`: set `wait_index` and `wait_time` to make a blocking
query, and feed the returned `QueryMeta.last_index` into the next call.

`@concurrency.watch(client, kind, handler)` is that loop, and runs until its task
is cancelled. `kind` is a `WatchKind`, one per watch type of Consul's: `Key`,
`KeyPrefix`, `Services`, `Nodes`, `Service`, `Checks`, `State`, `Event`,
`ConnectRoots`, `ConnectLeaf`, `AgentService`.

```moonbit
@concurrency.watch(client, Service("web", passing=true), (index, value) => {
  println("\{index}: \{value.stringify()}")
})
```

`handler` is called when the value changes, not each time the index moves. A
failed query is tried again after `retry` milliseconds, then 4, 9, 16... times
that, up to `limit`, as in Go's `watch.Plan`. `Client::poll` is one round of it.

## Options and metadata

* `QueryOptions` — `datacenter`, `ns`, `token`, `wait_index`, `wait_hash`,
  `wait_time`, `consistency`, `near`, `filter`, `node_meta`.
  `default_query_options` is a non-blocking default-consistency read.
* `WriteOptions` — `datacenter`, `ns`, `token`. `default_write_options` has no
  overrides.
* `ConsistencyMode` — `Default`, `Consistent`, `Stale`.
* `QueryMeta` — `last_index`, `last_hash`, `last_contact`, `known_leader`,
  `request_time`.
* `WriteMeta` — `request_time`.

## Errors

Every API method reports through `Refused` (a `suberror`), never `Result[_, _]`:

| Variant | Meaning |
|:--|:--|
| `Transport(String)` | The HTTP medium could not carry the request |
| `Status(Int32, String)` | Non-2xx agent response and its body |
| `Json(String)` | A response body was not the JSON expected |
| `Conflict(String)` | A lock or semaphore is held, in use, lost, or not one |
| `NotFound` | The key, session or entry does not exist |
| `Param(String)` | A bad argument before the call left the client |

## Transport

The client reaches an agent through a trait, and `moonconsul/fetch` is the one a
program uses:

```moonbit
pub(open) trait Transport {
  async fn send(Self, Request) -> Response raise Refused
}
```

`Request` and `Response` carry the verb, URL, headers, body and status. Implement
the trait to send through something else; the white-box tests use one that
returns canned bytes.

## The gate

Every commit passes this, with each exit code seen to be zero:

```bash
moon clean && moon fmt && moon check --target all --deny-warn \
  && moon build --target all && moon test --target all
```

`src/integration` runs against real agents: `scripts/start_consul.sh` starts two
in Docker, one with ACLs on, and `MOONCONSUL_LIVE=1` makes a missing agent a
failure instead of a skip. `MOONCONSUL_CONTAINER` names the container whose
`consul` command the interoperability tests run.

## Releasing

Push a signed tag `v<version>`. `release.yml` runs the tests first and publishes
only if they pass and the organisation variable `MOONCAKES_PUBLISH` is `true`.
The major version stays at 0.

## License

Apache-2.0.
