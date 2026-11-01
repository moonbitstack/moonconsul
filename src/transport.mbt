///|
/// A single HTTP request to a Consul agent: the verb, the full URL (scheme,
/// address, path and query already joined), the request headers, and the body
/// for writes. The transport owns the socket and the TLS configuration.
pub(all) struct Request {
  verb : String
  url : String
  headers : Map[String, String]
  body : Bytes
}

///|
/// A request with no headers and an empty body.
pub fn Request::new(verb : String, url : String) -> Request {
  { verb, url, headers: Map([]), body: b"", }
}

///|
/// A Consul agent's HTTP response: the status code and the raw body bytes.
pub(all) struct Response {
  status : Int32
  body : Bytes
}

///|
/// A response carrying `status` and `body`.
pub fn Response::new(status : Int32, body : Bytes) -> Response {
  { status, body, }
}

///|
/// The HTTP medium a `Client` drives. It performs one request and returns the
/// response, or raises `Refused` on a transport failure. The production client
/// plugs the `moonfetch`-backed transport in here; tests plug an in-memory fake
/// that returns canned responses, so the request shaping and JSON parsing run
/// against a real agent's wire format without a network.
pub(open) trait Transport {
  fn send(self : Self, Request) -> Response raise Refused
}
