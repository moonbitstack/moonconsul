// moonsd on Consul: one task keeps an endpoint registered, and a watcher sees it arrive.
//
//     consul agent -dev
//     moon run src/examples/05-discovery --target native

///|
async fn main {
  let registry = @sd.Registry::new(@fetch.connect())
  let endpoint = @moonsd.Endpoint::new("127.0.0.1", 12000, id="web-1")
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      @moonsd.hold(registry, "web", endpoint, ttl=30_000)
    })
    let watcher = registry.watch("web")
    defer watcher.close()
    for ;; {
      let update = watcher.next()
      println("web has \{update.endpoints.length()} endpoints")
      if update.endpoints.length() > 0 {
        break
      }
    }
  })
}
