// Connect on a dev agent: issue a leaf certificate for a service, write the
// intention that lets it reach a destination, and ask the agent whether the
// connection the certificate describes is allowed.
//
//     consul agent -dev
//     moon run src/examples/06-connect --target native

///|
async fn main {
  let client = @fetch.connect()
  let source = "example-web"
  let destination = "example-db"
  for name in [source, destination] {
    ignore(
      client
      .agent()
      .service_register({
        ..@moonconsul.default_service_registration,
        id: Some(name),
        name,
        port: Some(8080),
      }),
    )
  }
  let (roots, _) = client.agent().connect_roots()
  println("trust domain: \{roots.trust_domain}")
  let (leaf, _) = client.agent().connect_leaf(source)
  println("\{source} holds \{leaf.service_uri}")
  let allowed = async fn() -> Bool {
    let (decision, _) = client
      .agent()
      .connect_authorize({
        target: destination,
        client_cert_uri: leaf.service_uri,
        client_cert_serial: leaf.serial_number,
      })
    println("  \{source} -> \{destination}: \{decision.reason}")
    decision.authorized
  }
  let before = allowed()
  println("before any intention: \{before}")
  ignore(
    client
    .connect()
    .intention_upsert(@moonconsul.Intention::new(source, destination, Allow)),
  )
  let after = allowed()
  println("after an allow intention: \{after}")
  ignore(client.connect().intention_delete_exact(source, destination))
  for name in [source, destination] {
    ignore(client.agent().service_deregister(name))
  }
}
