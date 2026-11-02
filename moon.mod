name = "moonbitstack/moonconsul"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/moonbitstack/moonconsul"

license = "Apache-2.0"

keywords = [
  "consul",
  "discovery",
  "client",
  "moonbit",
  "kv",
  "acl",
  "session",
]

description = "A complete Consul client for MoonBit: agent, catalog, health, KV (with CAS, locks and semaphores), sessions, events, ACL, status, coordinate, prepared queries and config entries, with blocking queries and watch."

source = "src"

import {
  "moonbitlang/async@0.22.5",
  "moonbitstack/moonfetch@0.1.2",
  "moonbitstack/moonsd@0.1.0",
}
