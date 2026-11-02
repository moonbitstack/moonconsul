// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Sessions without a lock delay, and a short pause for those that have one.
let quick : @concurrency.LockOptions = {
  ..@concurrency.default_lock_options,
  entry: { ..@concurrency.default_lock_options.entry, lock_delay: Some(0), },
  retry: 100,
}

///|
let quick_seats : @concurrency.SemaphoreOptions = {
  ..@concurrency.default_semaphore_options,
  entry: {
    ..@concurrency.default_semaphore_options.entry,
    lock_delay: Some(0),
  },
}

///|
/// Wait until `done`, for up to five seconds.
async fn until(done : () -> Bool) -> Unit {
  for _ in 0..<100 {
    if done() {
      return
    }
    @async.sleep(50)
  }
  fail("it did not happen")
}

///|
async fn session_of(c : @moonconsul.Client, delay : Int64) -> String {
  let (made, _) = c
    .session()
    .create(entry={
      ..@moonconsul.default_session_entry,
      lock_delay: Some(delay),
      behavior: Some(Delete),
    })
  made.id.unwrap()
}

///|
async test "a lock excludes a second holder until it is released" {
  guard live() is Some(c) else { return }
  let key = stamped("lock")
  let a = @concurrency.Lock::new(c, key, options=quick)
  let b = @concurrency.Lock::new(c, key, options=quick)
  assert_true(a.try_acquire())
  assert_false(b.try_acquire())
  assert_true(c.kv().get(key).0.unwrap().flags == @concurrency.lock_flag)
  a.release()
  assert_true(b.try_acquire())
  b.release()
  b.destroy()
  assert_true(c.kv().get(key).0 is None)
}

///|
async test "acquire waits for the holder to let go" {
  guard live() is Some(c) else { return }
  let key = stamped("waited")
  let a = @concurrency.Lock::new(c, key, options=quick)
  let b = @concurrency.Lock::new(c, key, options=quick)
  a.acquire()
  let order : Array[String] = []
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      b.acquire()
      order.push("b")
    })
    @async.sleep(300)
    order.push("a")
    a.release()
  })
  assert_eq(order, ["a", "b"])
  b.release()
  b.destroy()
}

///|
async test "acquire waits out a lock delay" {
  guard live() is Some(c) else { return }
  let key = stamped("delayed")
  let id = session_of(c, 1_000_000_000)
  let a = @concurrency.Lock::new(c, key, options={ ..quick, session: Some(id), })
  a.acquire()
  // A session that dies leaves the delay behind; a release would not.
  ignore(c.session().destroy(id))
  let b = @concurrency.Lock::new(c, key, options=quick)
  assert_false(b.try_acquire())
  b.acquire()
  b.release()
  b.destroy()
}

///|
async test "a timeout gives up the wait and leaves no session behind" {
  guard live() is Some(c) else { return }
  let key = stamped("given-up")
  let a = @concurrency.Lock::new(c, key, options=quick)
  a.acquire()
  let name = stamped("session")
  let b = @concurrency.Lock::new(c, key, options={
    ..quick,
    entry: { ..quick.entry, name: Some(name), },
  })
  assert_true(@async.with_timeout_opt(300, () => b.acquire()) is None)
  assert_false(c.session().list().0.iter().any(s => s.name == Some(name)))
  a.release()
  a.destroy()
}

///|
async test "a key that is not a lock refuses" {
  guard live() is Some(c) else { return }
  let key = stamped("plain")
  ignore(c.kv().put(pair_of(key, b"data")))
  let lock = @concurrency.Lock::new(c, key, options=quick)
  let refused = try {
    ignore(lock.try_acquire())
    false
  } catch {
    @moonconsul.Conflict(_) => true
    _ => false
  }
  assert_true(refused)
  ignore(c.kv().delete(key))
}

///|
async test "hold gives the lock back after the body" {
  guard live() is Some(c) else { return }
  let key = stamped("held")
  let lock = @concurrency.Lock::new(c, key, options=quick)
  let holder = lock.hold(() => c.kv().get(key).0.unwrap().session)
  assert_true(holder is Some(_))
  assert_true(c.kv().get(key).0.unwrap().session is None)
  lock.destroy()
}

///|
async test "losing the lock cancels the body and raises" {
  guard live() is Some(c) else { return }
  let key = stamped("lost")
  let id = session_of(c, 0)
  let lock = @concurrency.Lock::new(c, key, options={
    ..quick,
    session: Some(id),
  })
  let reached = Ref(false)
  let lost = try {
    lock.hold(() => {
      ignore(c.session().destroy(id))
      @async.sleep(5000)
      reached.val = true
    })
    false
  } catch {
    @moonconsul.Conflict(_) => true
    _ => false
  }
  assert_true(lost)
  assert_false(reached.val)
}

///|
async test "keep_alive carries a session past its TTL" {
  guard live() is Some(c) else { return }
  let session = c.session()
  let (made, _) = session.create(entry={
    ..@moonconsul.default_session_entry,
    ttl: Some("10s"),
    lock_delay: Some(0),
  })
  let id = made.id.unwrap()
  // The agent keeps a lapsed session for up to twice its TTL.
  ignore(
    @async.with_timeout_opt(21_000, () => {
      @concurrency.keep_alive(session, id, 10_000)
    }),
  )
  assert_true(session.info(id).0 is Some(_))
  ignore(session.destroy(id))
}

///|
async test "keep_alive raises for a session the agent has lost" {
  guard live() is Some(c) else { return }
  let session = c.session()
  let id = session_of(c, 0)
  ignore(session.destroy(id))
  let gone = try {
    @async.with_timeout(5000, () => @concurrency.keep_alive(session, id, 200))
    false
  } catch {
    @moonconsul.NotFound => true
    _ => false
  }
  assert_true(gone)
}

///|
async test "a semaphore seats up to its limit" {
  guard live() is Some(c) else { return }
  let prefix = stamped("semaphore")
  let open = () => {
    @concurrency.Semaphore::new(c, prefix, 2, options=quick_seats)
  }
  let a = open()
  let b = open()
  let d = open()
  assert_true(a.try_acquire())
  assert_true(b.try_acquire())
  assert_false(d.try_acquire())
  a.release()
  assert_true(d.try_acquire())
  b.release()
  d.release()
  // A release writes its seat back rather than leaving the next contender to clear it.
  let seats = c.kv().get(prefix + "/.lock").0.unwrap()
  assert_eq(@utf8.decode_lossy(seats.value[:]), "{\"Limit\":2,\"Holders\":{}}")
  d.destroy()
  assert_eq(c.kv().list(prefix).0.length(), 0)
}

///|
async test "a seat frees when its session dies" {
  guard live() is Some(c) else { return }
  let prefix = stamped("seat")
  let id = session_of(c, 0)
  let a = @concurrency.Semaphore::new(c, prefix, 1, options={
    ..quick_seats,
    session: Some(id),
  })
  a.acquire()
  let b = @concurrency.Semaphore::new(c, prefix, 1, options=quick_seats)
  assert_false(b.try_acquire())
  ignore(c.session().destroy(id))
  @async.with_timeout(5000, () => b.acquire())
  b.release()
  b.destroy()
}

///|
async test "every contender must agree on the limit" {
  guard live() is Some(c) else { return }
  let prefix = stamped("limit")
  let a = @concurrency.Semaphore::new(c, prefix, 2, options=quick_seats)
  assert_true(a.try_acquire())
  let b = @concurrency.Semaphore::new(c, prefix, 3, options=quick_seats)
  let refused = try {
    ignore(b.try_acquire())
    false
  } catch {
    @moonconsul.Conflict(_) => true
    _ => false
  }
  assert_true(refused)
  a.release()
  a.destroy()
}

///|
async test "hold gives the seat back, and losing it raises" {
  guard live() is Some(c) else { return }
  let prefix = stamped("hold")
  let a = @concurrency.Semaphore::new(c, prefix, 1, options=quick_seats)
  assert_eq(a.hold(() => 7), 7)
  assert_eq(
    c.kv().list(prefix).0.filter(pair => pair.session is Some(_)).length(),
    0,
  )
  let id = session_of(c, 0)
  let b = @concurrency.Semaphore::new(c, prefix, 1, options={
    ..quick_seats,
    session: Some(id),
  })
  let lost = try {
    b.hold(() => {
      ignore(c.session().destroy(id))
      @async.sleep(5000)
    })
    false
  } catch {
    @moonconsul.Conflict(_) => true
    _ => false
  }
  assert_true(lost)
  a.destroy()
}

///|
/// Run `body` while `@concurrency.watch` follows `kind`, then stop it.
async fn watching(
  c : @moonconsul.Client,
  kind : @moonconsul.WatchKind,
  seen : Array[Json],
  body : async () -> Unit,
  wait~ : Int64 = 10_000_000_000,
) -> Unit {
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      @concurrency.watch(c, kind, (_, value) => seen.push(value), options={
        ..@moonconsul.default_query_options,
        wait_time: Some(wait),
      })
    })
    body()
  })
}

///|
async test "watch follows a key from absent through each change" {
  guard live() is Some(c) else { return }
  let key = stamped("watched")
  let seen : Array[Json] = []
  watching(c, Key(key), seen, () => {
    until(() => seen.length() == 1)
    ignore(c.kv().put(pair_of(key, b"1")))
    until(() => seen.length() == 2)
    ignore(c.kv().put(pair_of(key, b"2")))
    until(() => seen.length() == 3)
  })
  assert_true(seen[0] is Null)
  assert_true(seen[2] is Array(_))
  ignore(c.kv().delete(key))
}

///|
async test "watch reports a value once, however many rounds it reads it in" {
  guard live() is Some(c) else { return }
  let key = stamped("quiet")
  ignore(c.kv().put(pair_of(key, b"1")))
  let seen : Array[Json] = []
  // Each query waits a tenth of a second, so several end with nothing changed.
  watching(c, Key(key), seen, () => @async.sleep(500), wait=100_000_000)
  assert_eq(seen.length(), 1)
  ignore(c.kv().delete(key))
}

///|
async test "watch follows events, whose index passes the signed range" {
  guard live() is Some(c) else { return }
  let name = stamped("deploy")
  let seen : Array[Json] = []
  watching(c, Event(name), seen, () => {
    until(() => seen.length() == 1)
    @async.sleep(200)
    ignore(c.event().fire(name, b""))
    until(() => seen.length() == 2)
    ignore(c.event().fire(name, b""))
    until(() => seen.length() == 3)
  })
  assert_true(seen[2] is Array(_))
}

///|
async test "watch follows a service on this agent by hash" {
  guard live() is Some(c) else { return }
  let id = stamped("agent-service")
  let agent = c.agent()
  let service = @moonconsul.default_service_registration
  ignore(
    agent.service_register({ ..service, id: Some(id), name: id, port: Some(1), }),
  )
  let seen : Array[Json] = []
  watching(c, AgentService(id), seen, () => {
    until(() => seen.length() == 1)
    ignore(
      agent.service_register({
        ..service,
        id: Some(id),
        name: id,
        port: Some(2),
      }),
    )
    until(() => seen.length() == 2)
  })
  ignore(agent.service_deregister(id))
}

///|
async test "watch reads the certificate authority's roots" {
  guard live() is Some(c) else { return }
  let seen : Array[Json] = []
  watching(c, ConnectRoots, seen, () => until(() => seen.length() == 1))
  assert_true(seen[0] is Object(_))
}

///|
/// The container of the agent, to run Consul's own command against our keys.
fn container() -> String? {
  @env.get_env_var("MOONCONSUL_CONTAINER")
}

///|
async fn consul(box : String, args : Array[String]) -> Int32 {
  @process.run("docker", ["exec", box, "consul", ..args])
}

///|
async fn consul_in_background(box : String, args : Array[String]) -> Unit {
  ignore(@process.run("docker", ["exec", "-d", box, "consul", ..args]))
}

///|
async test "a lock excludes the consul command, and the command excludes it" {
  guard live() is Some(c) else { return }
  guard container() is Some(box) else { return }
  let prefix = stamped("interop-lock")
  let key = prefix + "/.lock"
  consul_in_background(box, ["lock", prefix, "sleep 2"])
  for _ in 0..<100 {
    if c.kv().get(key).0 is Some({ session: Some(_), .. }) {
      break
    }
    @async.sleep(50)
  }
  let lock = @concurrency.Lock::new(c, key, options=quick)
  assert_false(lock.try_acquire())
  @async.with_timeout(10_000, () => lock.acquire())
  assert_true(consul(box, ["lock", "-try=1s", prefix, "true"]) != 0)
  lock.release()
  assert_eq(consul(box, ["lock", "-try=5s", prefix, "true"]), 0)
  ignore(c.kv().delete_tree(prefix))
}

///|
async test "a semaphore shares its seats with the consul command" {
  guard live() is Some(c) else { return }
  guard container() is Some(box) else { return }
  let prefix = stamped("interop-semaphore")
  let lock = prefix + "/.lock"
  consul_in_background(box, ["lock", "-n=2", prefix, "sleep 3"])
  for _ in 0..<100 {
    if c.kv().get(lock).0 is Some(_) {
      break
    }
    @async.sleep(50)
  }
  let ours = @concurrency.Semaphore::new(c, prefix, 2, options=quick_seats)
  let third = @concurrency.Semaphore::new(c, prefix, 2, options=quick_seats)
  assert_true(ours.try_acquire())
  assert_false(third.try_acquire())
  assert_true(consul(box, ["lock", "-n=2", "-try=1s", prefix, "true"]) != 0)
  ours.release()
  assert_eq(consul(box, ["lock", "-n=2", "-try=5s", prefix, "true"]), 0)
  ignore(c.kv().delete_tree(prefix))
}
