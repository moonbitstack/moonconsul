// A lock and a semaphore. `hold` waits, renews the session while the body runs, and gives the
// lock back. Try it next to `consul lock demo/lock sleep 10`: they exclude each other.
//
//     consul agent -dev
//     moon run src/examples/03-lock --target native

///|
async fn main {
  let client = @fetch.connect()
  let lock = @concurrency.Lock::new(client, "demo/lock/.lock")
  lock.hold(() => println("only one of these at a time"))
  lock.destroy()

  let seats = @concurrency.Semaphore::new(client, "demo/seats", 2)
  @async.with_task_group(group => {
    for name in ["a", "b", "c"] {
      group.spawn_bg(() => {
        let seat = @concurrency.Semaphore::new(client, "demo/seats", 2)
        seat.hold(() => {
          println("\{name} has a seat")
          @async.sleep(200)
        })
      })
    }
  })
  seats.destroy()
}
