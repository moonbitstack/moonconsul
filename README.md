# moonconsul

A complete Consul client for MoonBit, mirroring the surface of HashiCorp's Go
`consul/api` package: Agent, Catalog, Health, KV (with CAS, locks and
semaphores), Session, Event, ACL, Status, Coordinate, Prepared Query and Config
Entries, with blocking queries and watch monitors, consistency modes, and
datacenter/namespace/token routing.

The authoritative specification this package implements is HashiCorp's
[`consul/api`](https://github.com/hashicorp/consul/tree/main/api) (the Go
client). MoonBit types and snake_case method names follow the organisation's
conventions; the wire format, endpoints and semantics follow that package.

## Status

All API groups are implemented against the transport: Agent, Catalog, Health,
KV (with CAS, acquire/release and txn), Session, Event, ACL (tokens, policies,
roles, auth methods, binding rules), Status, Coordinate, Prepared Query, Config
Entries, plus `Lock` and `Semaphore`. The shared HTTP/JSON layer builds URLs and
query options, attaches the token header, maps statuses (`404` to `NotFound`),
lifts `QueryMeta` from the `X-Consul-*` headers, and base64-decodes KV/event
payloads.

White-box tests run the request shaping and response parsing against an
in-memory fake transport, so the wire format is exercised without a socket. The
existing `greet` smoke test is unchanged.

Note: `Lock` and `Semaphore` are non-blocking try-acquire in this synchronous
client (`acquire` returns `false` when held/full); callers poll. A production
HTTP transport implementing `Transport` is the caller's to supply.

## Quick start

```moonbit
// `transport` is any value implementing `Transport` (see Transport below).
let client = @moonconsul.Client::with_address("127.0.0.1:8500", transport)

let kv = client.kv()            // KV handle
let agent = client.agent()      // Agent handle
let health = client.health()    // Health handle
// ... one handle per API group, all sharing `client`.
```

`Client::new(config, transport)` takes a full `Config`; `Client::with_address`
and `config_with_address` cover the common case of just an address. The
`default_config` targets `http://127.0.0.1:8500` with verification-on TLS and
no token.

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

The key/value store. Reads and writes are paired with blocking queries; CAS,
acquire and release are the primitives that locks and semaphores build on.

| Method | Intent |
|:--|:--|
| `get(key, options~)` | Read one key (`None` when absent) |
| `list(prefix, options~)` | Every entry under a prefix |
| `keys(prefix, options~)` | Only the keys under a prefix |
| `put(pair, options~)` | Write a pair |
| `delete(key, options~)` | Delete a key |
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
| `renew_periodic(ttl, id, entry, options~)` | Renew in the background; `stop` ends it |
| `info(id, options~)` | Read one session by id |
| `node(node, options~)` | Sessions active on a node |
| `list(options~)` | Every session in the datacenter |

`SessionRenewal::stop(self)` ends a background renewal started by
`renew_periodic`.

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
`auth_method_list`, `auth_method_delete`.
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
| `list(kind~, options~)` | List entries, optionally of one `kind` |
| `set(entry, options~)` | Write a config entry |
| `delete(kind, name, options~)` | Delete a config entry |

### Distributed primitives

`Lock` and `Semaphore` build on KV + Session. Construct with `Lock::new` /
`Semaphore::new`, then `acquire` / `release`.

| Type | Method | Intent |
|:--|:--|:--|
| `Lock` | `acquire(options~)` | Acquire the lock; `true` when held |
| `Lock` | `release(options~)` | Release the lock |
| `Semaphore` | `acquire(options~)` | Acquire a slot; `true` when admitted |
| `Semaphore` | `release(options~)` | Release a held slot |

### Blocking queries and watches

Reads take `QueryOptions`; set `wait_index` and `wait_time` to make a blocking
query, and feed the returned `QueryMeta.last_index` into the next call's
`wait_index`. `client.watch(plan, handler, options~)` runs one blocking query
for a `WatchPlan` (a `key`, `keyprefix`, `service`, `checks`, `state`, `nodes`,
`services`, `connect` or `agent/self`) and calls `handler(index, data)` when the
index advances, returning a `Watcher` whose `plan.index` is the new index; loop
on it to keep watching (the client is synchronous, so the caller drives the
loop and can stop between iterations).

## Options and metadata

* `QueryOptions` — `datacenter`, `ns`, `token`, `wait_index`, `wait_time`,
  `consistency`, `near`, `filter`, `node_meta`. `default_query_options` is a
  non-blocking default-consistency read.
* `WriteOptions` — `datacenter`, `ns`, `token`. `default_write_options` has no
  overrides.
* `ConsistencyMode` — `Default`, `Consistent`, `Stale`.
* `QueryMeta` — `last_index`, `last_contact`, `known_leader`, `request_time`.
* `WriteMeta` — `request_time`.

## Errors

Every API method reports through `Refused` (a `suberror`), never `Result[_, _]`:

| Variant | Meaning |
|:--|:--|
| `Transport(String)` | The HTTP medium could not carry the request |
| `Status(Int32, String)` | Non-2xx agent response and its body |
| `Json(String)` | A response body was not the JSON expected |
| `Timeout` | A blocking query timed out with no change |
| `Conflict(String)` | CAS / lock / session lost to a concurrent writer |
| `NotFound` | The key, session or entry does not exist |
| `Param(String)` | A bad argument before the call left the client |
| `Unimplemented(String)` | Interface present, body not wired up yet |

## Transport

The client is decoupled from any HTTP implementation through
`pub(open) trait Transport`:

```moonbit
pub(open) trait Transport {
  fn send(self : Self, Request) -> Response raise Refused
}
```

`Request` and `Response` carry verb, URL, headers, body (bytes) and status.
Production plugs the `moonfetch`-backed transport in here; tests plug an
in-memory fake that returns canned bytes, so request shaping and JSON parsing
run against a real agent's wire format without a network.

## What is not here

* The service-discovery adapter back into `moonzero` is owned by the
  organisation, not this library.
* Consul Connect service-mesh configuration beyond the config-entry types
  already present.

## The gate

Every commit passes this, with each exit code seen to be zero:

```bash
moon clean && moon fmt && moon check --target all --deny-warn \
  && moon build --target all && moon test --target all
```

Before a release, `moon info --target all && git diff --exit-code` as well: the
generated interface (`src/pkg.generated.mbti`) is checked in, and a difference
means the interface moved without anyone saying so.

## Releasing

Push a signed tag `v<version>`. `release.yml` runs the tests first and publishes
only if they pass and the organisation variable `MOONCAKES_PUBLISH` is `true`.
The major version stays at 0.

## Licence

Apache-2.0.
