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
/// A request with `headers` and `body`.
pub fn Request::new_full(
  verb : String,
  url : String,
  headers : Map[String, String],
  body : Bytes,
) -> Request {
  { verb, url, headers, body, }
}

///|
/// A Consul agent's HTTP response: the status code, the response headers (the
/// blocking-query metadata rides on `X-Consul-Index` and its siblings), and the
/// raw body bytes.
pub(all) struct Response {
  status : Int32
  headers : Map[String, String]
  body : Bytes
}

///|
/// A response carrying `status` and `body`, with no headers.
pub fn Response::new(status : Int32, body : Bytes) -> Response {
  { status, headers: Map([]), body, }
}

///|
/// A response carrying `status`, `headers` and `body`.
pub fn Response::new_full(
  status : Int32,
  headers : Map[String, String],
  body : Bytes,
) -> Response {
  { status, headers, body, }
}

///|
/// A response header by name, case-insensitively (HTTP header names are not
/// case-sensitive; Consul spells them `X-Consul-Index` and friends).
pub fn Response::header(self : Response, name : String) -> String? {
  match self.headers.get(name) {
    Some(v) => Some(v)
    None => {
      let lower = name.to_lower()
      let mut found : String? = None
      for k, v in self.headers {
        if k.to_lower() == lower {
          found = Some(v)
          break
        }
      }
      found
    }
  }
}

///|
/// The HTTP medium a `Client` drives. It performs one request and returns the
/// response, or raises `Refused` on a transport failure. The production client
/// plugs an HTTP-backed transport in here; tests plug an in-memory fake that
/// returns canned responses, so the request shaping and JSON parsing run
/// against a real agent's wire format without a network.
pub(open) trait Transport {
  async fn send(self : Self, Request) -> Response raise Refused
}
