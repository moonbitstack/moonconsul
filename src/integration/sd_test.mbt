// The `moonsd` adapter against a live agent.

///|
fn endpoint(port : Int32) -> @moonsd.Endpoint {
  @moonsd.Endpoint::new("10.1.0.3", port)
}

///|
async test "a registry meets the discovery contract" {
  guard live() is Some(client) else { return }
  let registry = @sd.Registry::new(client, wait=2_000_000_000)
  @conformance.check(registry, registry, service=stamped("sd"), settle=10000)
}

///|
async test "many tasks share a registry" {
  guard live() is Some(client) else { return }
  let registry = @sd.Registry::new(client)
  let service = stamped("sd-share")
  let lease = @moonsd.Registrar::register(registry, service, endpoint(1), 30000)
  @async.with_task_group(g => {
    for _ in 0..<8 {
      g.spawn_bg(() => {
        for _ in 0..<20 {
          let got = @moonsd.Discovery::resolve(registry, service)
          assert_eq(got.length(), 1)
        }
      })
    }
  })
  @moonsd.Registrar::deregister(registry, lease)
}
