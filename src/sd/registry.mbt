// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Service discovery on Consul: an endpoint is a service instance with a TTL check, and a lease
// is that check being passed in time. Consul's own fields carry the endpoint, so other Consul
// clients see an ordinary service.

///|
/// How long a blocking query waits for a change, in nanoseconds, as `QueryOptions` takes it.
/// Consul's own default is five minutes; a closed watcher only notices between queries.
pub let wait : Int64 = 30_000_000_000

///|
/// How long a service whose check has failed stays registered; Consul's minimum. It is out of
/// `resolve` as soon as the check fails, so this is only how long the agent keeps the corpse.
pub let reap_after : String = "1m"

///|
/// Where the endpoint's own id travels, since Consul's service id has to be unique per agent.
let id_key : String = "moonsd_id"

///|
/// A registry over one Consul client. It is both a `Registrar` and a `Discovery`, and any number
/// of tasks may share it.
pub struct Registry {
  client : @moonconsul.Client
  wait : Int64
  reap_after : String
}

///|
pub fn Registry::new(
  client : @moonconsul.Client,
  wait~ : Int64 = wait,
  reap_after~ : String = reap_after,
) -> Registry {
  { client, wait, reap_after, }
}

///|
/// The id of a service's TTL check, which Consul derives from the service id.
fn check_id(token : String) -> String {
  "service:" + token
}

///|
pub extend Registry with @moonsd.Registrar::{register, renew, deregister}

///|
pub impl @moonsd.Registrar for Registry with fn register(
  self,
  service,
  endpoint,
  ttl,
) {
  let token = "\{service}:\{endpoint.id}"
  let meta = Map::from_iter(endpoint.metadata.iter())
  meta[id_key] = endpoint.id
  let registration : @moonconsul.AgentServiceRegistration = {
    ..@moonconsul.default_service_registration,
    id: Some(token),
    name: service,
    address: Some(endpoint.host),
    port: Some(endpoint.port),
    meta: Some(meta),
    weights: Some({ passing: Some(endpoint.weight), warning: Some(1), }),
    check: Some({
      ..@moonconsul.default_service_check,
      ttl: Some("\{ttl}ms"),
      status: Some("passing"),
      deregister_critical_service_after: Some(self.reap_after),
    }),
  }
  ignore(self.client.agent().service_register(registration))
  { service, endpoint, ttl, token, }
}

///|
pub impl @moonsd.Registrar for Registry with fn renew(self, lease) {
  // Consul has answered 500 for a check it does not know, before 1.11 and for a TTL check since.
  ignore(self.client.agent().check_pass(check_id(lease.token))) catch {
    @moonconsul.NotFound | @moonconsul.Status(500, _) =>
      raise @moonsd.Expired(lease)
    e => raise e
  }
}

///|
/// An instance that has already gone is what this call was after.
pub impl @moonsd.Registrar for Registry with fn deregister(self, lease) {
  ignore(self.client.agent().service_deregister(lease.token)) catch {
    @moonconsul.NotFound | @moonconsul.Status(500, _) => ()
    e => raise e
  }
}

///|
/// One instance as an endpoint, by the fields `register` wrote.
fn endpoint_of(entry : @moonconsul.ServiceEntry) -> @moonsd.Endpoint? {
  guard entry.service is Some(service) else { return None }
  let metadata : Map[String, String] = Map([])
  let mut id = service.id
  for key, value in service.meta.unwrap_or(Map([])) {
    if key == id_key {
      id = value
    } else {
      metadata[key] = value
    }
  }
  let weight = match service.weights {
    Some({ passing: Some(n), .. }) => n
    _ => @moonsd.weight
  }
  Some({
    id,
    host: service.address.unwrap_or(entry.node.address),
    port: service.port.unwrap_or(0),
    weight,
    metadata,
  })
}

///|
/// A service's healthy endpoints by id, and the index Consul read them at.
async fn Registry::look(
  self : Registry,
  service : String,
  options : @moonconsul.QueryOptions,
) -> (Array[@moonsd.Endpoint], UInt64) {
  let (entries, meta) = self.client
    .health()
    .service(service, passing=true, options~)
  let endpoints = entries.filter_map(endpoint_of)
  endpoints.sort_by_key(e => e.id)
  (endpoints, meta.last_index)
}

///|
pub extend Registry with @moonsd.Discovery::{resolve, watch}

///|
pub impl @moonsd.Discovery for Registry with fn resolve(self, service) {
  self.look(service, @moonconsul.default_query_options).0
}

///|
/// One service followed by blocking queries from the last index seen.
priv struct Follower {
  registry : Registry
  service : String
  mut index : UInt64?
  mut closed : Bool
}

///|
impl @moonsd.Watcher for Follower with fn next(self) {
  for ;; {
    if self.closed {
      fail("the watcher is closed")
    }
    let options = {
      ..@moonconsul.default_query_options,
      wait_index: self.index,
      wait_time: Some(self.registry.wait),
    }
    let (endpoints, index) = self.registry.look(self.service, options)
    // A query that waited out its time answers with the index it was given.
    if self.index != Some(index) {
      self.index = Some(index)
      return { endpoints, revision: index.reinterpret_as_int64(), }
    }
  }
}

///|
impl @moonsd.Watcher for Follower with fn close(self) {
  self.closed = true
}

///|
pub impl @moonsd.Discovery for Registry with fn watch(self, service) {
  let follower : &@moonsd.Watcher = Follower::{
    registry: self,
    service,
    index: None,
    closed: false,
  }
  follower
}
