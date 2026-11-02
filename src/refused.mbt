///|
/// Errors raised by a Consul API call: a transport failure, a non-2xx agent
/// response, a JSON decode failure, a lock conflict, or a bad input.
pub(all) suberror Refused {
  /// The HTTP medium could not carry the request (DNS, TLS, connection, reset).
  Transport(String)
  /// The agent answered with a non-2xx status code and the body it returned.
  Status(Int32, String)
  /// A response body was not the JSON the call expected.
  Json(String)
  /// A lock or semaphore is held, in use, lost, or the key is not one.
  Conflict(String)
  /// The requested key, session, or entry does not exist.
  NotFound
  /// An argument was missing or malformed before the call left the client.
  Param(String)
}
