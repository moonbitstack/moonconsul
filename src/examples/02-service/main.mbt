// A service with a TTL check: registered, passing, found through the health API, removed.
//
//     consul agent -dev
//     moon run src/examples/02-service --target native

///|
async fn main {
  let client = @fetch.connect()
  let agent = client.agent()
  ignore(
    agent.service_register({
      ..@moonconsul.default_service_registration,
      id: Some("web-1"),
      name: "web",
      address: Some("127.0.0.1"),
      port: Some(12000),
      check: Some({ ..@moonconsul.default_service_check, ttl: Some("30s"), }),
    }),
  )
  println("before the check passes: \{healthy(client)} instances")
  ignore(agent.check_pass("service:web-1"))
  println("after it passes: \{healthy(client)} instances")
  ignore(agent.service_deregister("web-1"))
}

///|
async fn healthy(client : @moonconsul.Client) -> Int32 {
  client.health().service("web", passing=true).0.length()
}
