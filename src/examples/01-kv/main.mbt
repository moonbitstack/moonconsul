// Keys against a local agent: write, read, compare-and-swap, list, delete.
//
//     consul agent -dev
//     moon run src/examples/01-kv --target native

///|
fn pair(key : String, value : String) -> @moonconsul.KVPair {
  {
    key,
    create_index: 0UL,
    modify_index: 0UL,
    lock_index: 0UL,
    flags: 0UL,
    value: @utf8.encode(value),
    session: None,
  }
}

///|
async fn main {
  let kv = @fetch.connect().kv()
  ignore(kv.put(pair("demo/colour", "red")))
  let (read, meta) = kv.get("demo/colour")
  let held = read.unwrap()
  println(
    "read \{@utf8.decode_lossy(held.value[:])} at index \{meta.last_index}",
  )

  let (swapped, _) = kv.cas({ ..held, value: @utf8.encode("green"), })
  println("compare-and-swap: \{swapped}")
  let (stale, _) = kv.cas({ ..held, value: @utf8.encode("blue"), })
  println("compare-and-swap with the old index: \{stale}")

  ignore(kv.put(pair("demo/size", "large")))
  println("keys: " + kv.keys("demo/").0.join(", "))
  ignore(kv.delete_tree("demo/"))
}
