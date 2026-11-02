// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The `Transport` a program talks to a real agent through, over moonfetch.

///|
/// HTTP to a Consul agent. It sets no timeout of its own: a blocking query is meant to wait for
/// as long as the agent says.
pub struct Fetch {
  http : @moonfetch.Client
}

///|
pub fn Fetch::new() -> Fetch raise @moonconsul.Refused {
  let http = @moonfetch.Client::new(timeout=None, redirects=0) catch {
    e => raise @moonconsul.Transport("\{e}")
  }
  { http, }
}

///|
pub extend Fetch with @moonconsul.Transport::{send}

///|
pub impl @moonconsul.Transport for Fetch with fn send(self, request) {
  let headers = request.headers.to_array()
  let body = @moonfetch.Bytes(request.body)
  let answer = try {
    match request.verb {
      "GET" => self.http.get(request.url, headers~)
      "PUT" => self.http.put(request.url, headers~, body~)
      "POST" => self.http.post(request.url, headers~, body~)
      "DELETE" => self.http.delete(request.url, headers~)
      other => fail("no such verb: " + other)
    }
  } catch {
    e => raise @moonconsul.Transport("\{e}")
  }
  @moonconsul.Response::new_full(
    answer.status,
    Map::from_array(answer.headers),
    answer.body,
  )
}

///|
/// A client that talks to the agent `config` names.
pub fn connect(
  config~ : @moonconsul.Config = @moonconsul.default_config,
) -> @moonconsul.Client raise @moonconsul.Refused {
  @moonconsul.Client::new(config, Fetch::new())
}
