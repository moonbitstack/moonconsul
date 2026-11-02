// A watch follows a key by blocking queries, and stops when its task is cancelled.
//
//     consul agent -dev
//     moon run src/examples/04-watch --target native

///|
async fn main {
  let client = @fetch.connect()
  let key = "demo/watched"
  let pair : @moonconsul.KVPair = {
    key,
    create_index: 0UL,
    modify_index: 0UL,
    lock_index: 0UL,
    flags: 0UL,
    value: b"",
    session: None,
  }
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      @concurrency.watch(client, Key(key), (index, value) => {
        println("\{index}: \{value.stringify()}")
      })
    })
    for value in ["first", "second"] {
      @async.sleep(300)
      ignore(client.kv().put({ ..pair, value: @utf8.encode(value), }))
    }
    @async.sleep(300)
  })
  ignore(client.kv().delete(key))
}
