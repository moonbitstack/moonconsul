// An in-memory transport for tests: it records the requests it receives and
// replays a queue of canned responses, so request shaping and JSON parsing are
// exercised against a real agent's wire format without a socket. White-box
// test support, so it stays out of the published API.

///|
/// A transport that returns queued responses and records the requests.
pub(all) struct FakeTransport {
  responses : Array[Response]
  requests : Array[Request]
}

///|
/// A fake preloaded with `responses`.
pub fn FakeTransport::new(responses : Array[Response]) -> FakeTransport {
  { responses, requests: [], }
}

///|
/// A fake with one canned response.
pub fn FakeTransport::one(response : Response) -> FakeTransport {
  { responses: [response], requests: [], }
}

///|
/// The requests the fake has seen, in order.
pub fn FakeTransport::seen(self : FakeTransport) -> Array[Request] {
  self.requests
}

///|
/// The last request the fake has seen, if any.
pub fn FakeTransport::last(self : FakeTransport) -> Request? {
  self.requests.get(self.requests.length() - 1)
}

///|
/// Record each request and replay the next queued response.
pub impl Transport for FakeTransport with fn send(self, request) {
  self.requests.push(request)
  match self.responses.get(0) {
    Some(response) => {
      let _ = self.responses.remove(0)
      response
    }
    None => raise Refused::Transport("fake: no queued response")
  }
}

///|
/// Keep the impl methods from being implicitly promoted onto `FakeTransport`.
pub extend FakeTransport with Transport::{send}

///|
/// A JSON 200 response with a blocking index, as a Consul read would return.
pub fn json_response(body : String) -> Response {
  json_response_at(body, 1UL)
}

///|
/// A JSON 200 response carrying a specific blocking index.
pub fn json_response_at(body : String, index : UInt64) -> Response {
  Response::new_full(
    200,
    Map([
      ("X-Consul-Index", index.to_string()),
      ("X-Consul-Knownleader", "true"),
    ]),
    @utf8.encode(body),
  )
}

///|
/// A `true` response, as Consul returns for a successful write.
pub fn ok_response() -> Response {
  Response::new_full(200, Map([]), @utf8.encode("true"))
}

///|
/// A `false` response, as Consul returns when a CAS or lock loses.
pub fn false_response() -> Response {
  Response::new_full(200, Map([]), @utf8.encode("false"))
}
