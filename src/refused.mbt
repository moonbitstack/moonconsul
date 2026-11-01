///|
/// Errors raised by a Consul API call: a transport failure, a non-2xx agent
/// response, a JSON decode failure, a blocking-query timeout, a CAS or lock
/// conflict, or a bad input. Every API method reports through `Result[_, Refused]`.
pub(all) suberror Refused {
  /// The HTTP medium could not carry the request (DNS, TLS, connection, reset).
  Transport(String)
  /// The agent answered with a non-2xx status code and the body it returned.
  Status(Int32, String)
  /// A response body was not the JSON the call expected.
  Json(String)
  /// A blocking query returned because its wait time elapsed with no change.
  Timeout
  /// A compare-and-swap, lock acquisition, or session check lost to a concurrent
  /// writer; the caller should retry.
  Conflict(String)
  /// The requested key, session, or entry does not exist.
  NotFound
  /// An argument was missing or malformed before the call left the client.
  Param(String)
  /// The method is part of the interface but its implementation is not wired up
  /// yet; it never appears once a release is built.
  Unimplemented(String)
}
