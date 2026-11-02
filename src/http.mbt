// The HTTP layer every API group goes through. It joins the configured
// scheme/address with a path and query pairs, attaches the ACL token header,
// drives the `Transport`, maps a non-2xx status to `Refused`, and lifts the
// blocking-query metadata out of the response headers.

///|
/// Join `scheme://address` with `path` and the URL-encoded `query` pairs.
fn Client::build_url(
  self : Client,
  path : String,
  query : Array[(String, String)],
) -> String {
  let mut url = self.config.scheme + "://" + self.config.address + path
  let mut first = true
  for pair in query {
    let (k, v) = pair
    let sep = if first { "?" } else { "&" }
    url = url + sep + url_encode(k) + "=" + url_encode(v)
    first = false
  }
  url
}

///|
/// The request headers: the ACL token, when one is configured or passed.
fn Client::auth_headers(self : Client, token : String?) -> Map[String, String] {
  let h : Map[String, String] = Map([])
  let t = match token {
    Some(s) => if s == "" { self.config.token } else { Some(s) }
    None => self.config.token
  }
  match t {
    Some(tok) => h["X-Consul-Token"] = tok
    None => ()
  }
  h
}

///|
/// The effective ACL token: the call's own, else the client's.
fn Client::resolve_token(self : Client, token : String?) -> String? {
  match token {
    Some(s) => if s == "" { self.config.token } else { Some(s) }
    None => self.config.token
  }
}

///|
/// Push `(key, value)` only when `value` is `Some` and non-empty.
fn push_q(out : Array[(String, String)], key : String, value : String?) -> Unit {
  match value {
    Some(s) => if s != "" { out.push((key, s)) }
    None => ()
  }
}

///|
/// The query pairs a read carries: datacenter, namespace, consistency,
/// blocking index/wait, `near`, `filter`, `node-meta`, then any extras.
fn Client::read_query(
  self : Client,
  opt : QueryOptions,
  extra : Array[(String, String)],
) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  push_q(
    out,
    "dc",
    match opt.datacenter {
      Some(s) => Some(s)
      None => self.config.datacenter
    },
  )
  push_q(
    out,
    "ns",
    match opt.ns {
      Some(s) => Some(s)
      None => self.config.ns
    },
  )
  match opt.consistency {
    Consistent => out.push(("consistent", ""))
    Stale => out.push(("stale", ""))
    Default => ()
  }
  match opt.wait_index {
    Some(i) => out.push(("index", i.to_string()))
    None => ()
  }
  push_q(out, "hash", opt.wait_hash)
  match opt.wait_time {
    Some(w) => out.push(("wait", w.to_string() + "ns"))
    None => ()
  }
  push_q(out, "near", opt.near)
  push_q(out, "filter", opt.filter)
  match opt.node_meta {
    Some(mm) =>
      for k, v in mm {
        out.push(("node-meta", k + ":" + v))
      }
    None => ()
  }
  for p in extra {
    out.push(p)
  }
  out
}

///|
/// The query pairs a write carries: datacenter, namespace, then any extras.
fn Client::write_query(
  self : Client,
  opt : WriteOptions,
  extra : Array[(String, String)],
) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  push_q(
    out,
    "dc",
    match opt.datacenter {
      Some(s) => Some(s)
      None => self.config.datacenter
    },
  )
  push_q(
    out,
    "ns",
    match opt.ns {
      Some(s) => Some(s)
      None => self.config.ns
    },
  )
  for p in extra {
    out.push(p)
  }
  out
}

///|
/// Send one request and parse its body as JSON (a `Null` for an empty body).
async fn Client::do_request(
  self : Client,
  verb : String,
  path : String,
  query : Array[(String, String)],
  body : Bytes,
  token : String?,
) -> (Response, Json) raise Refused {
  let url = self.build_url(path, query)
  let headers = self.auth_headers(token)
  let resp = self.transport.send(Request::new_full(verb, url, headers, body))
  let ok = resp.status >= 200 && resp.status < 300
  let json = if !ok || resp.body.length() == 0 {
    json_null()
  } else {
    let text = @utf8.decode_lossy(resp.body[:])
    @json.parse(text) catch {
      e => raise Refused::Json(e.to_string())
    }
  }
  (resp, json)
}

///|
/// Require a 2xx status, mapping 404 to `NotFound` and anything else to
/// `Status(status, body)`.
fn unwrap_response(resp : Response, json : Json) -> Json raise Refused {
  if resp.status >= 200 && resp.status < 300 {
    json
  } else if resp.status == 404 {
    raise Refused::NotFound
  } else {
    raise Refused::Status(resp.status, @utf8.decode_lossy(resp.body[:]))
  }
}

///|
/// The blocking-query metadata carried by a response's headers.
fn meta_of(resp : Response) -> QueryMeta {
  let idx = match resp.header("X-Consul-Index") {
    Some(s) => parse_u64(s)
    None => 0UL
  }
  let contact = match resp.header("X-Consul-Lastcontact") {
    Some(s) => parse_i64(s)
    None => 0L
  }
  let known = match resp.header("X-Consul-Knownleader") {
    Some(s) => s.to_lower() == "true"
    None => false
  }
  {
    last_index: idx,
    last_hash: resp.header("X-Consul-Contenthash"),
    last_contact: contact,
    known_leader: known,
    request_time: 0L,
  }
}

///|
/// A GET with `opt` and extra query pairs, returning the parsed body and the
/// query metadata.
pub async fn Client::do_get(
  self : Client,
  path : String,
  opt : QueryOptions,
  extra : Array[(String, String)],
) -> (Json, QueryMeta) raise Refused {
  let query = self.read_query(opt, extra)
  let (resp, json) = self.do_request(
    "GET",
    path,
    query,
    b"",
    self.resolve_token(opt.token),
  )
  let j = unwrap_response(resp, json)
  (j, meta_of(resp))
}

///|
/// A GET that takes a 404 for an answer: `None`, with the index the agent gave
/// it, which is what a blocking read of something absent waits from.
pub async fn Client::do_get_found(
  self : Client,
  path : String,
  opt : QueryOptions,
  extra : Array[(String, String)],
) -> (Json?, QueryMeta) raise Refused {
  let query = self.read_query(opt, extra)
  let (resp, json) = self.do_request(
    "GET",
    path,
    query,
    b"",
    self.resolve_token(opt.token),
  )
  if resp.status == 404 {
    return (None, meta_of(resp))
  }
  let j = unwrap_response(resp, json)
  (Some(j), meta_of(resp))
}

///|
/// A PUT with `opt` and extra query pairs, returning the parsed body and a
/// fresh write metadata.
pub async fn Client::do_put(
  self : Client,
  path : String,
  body : Bytes,
  opt : WriteOptions,
  extra : Array[(String, String)],
) -> (Json, WriteMeta) raise Refused {
  let query = self.write_query(opt, extra)
  let (resp, json) = self.do_request(
    "PUT",
    path,
    query,
    body,
    self.resolve_token(opt.token),
  )
  let j = unwrap_response(resp, json)
  (j, { request_time: 0L, })
}

///|
/// A DELETE with `opt` and extra query pairs, returning the parsed body and a
/// fresh write metadata.
pub async fn Client::do_delete(
  self : Client,
  path : String,
  opt : WriteOptions,
  extra : Array[(String, String)],
) -> (Json, WriteMeta) raise Refused {
  let query = self.write_query(opt, extra)
  let (resp, json) = self.do_request(
    "DELETE",
    path,
    query,
    b"",
    self.resolve_token(opt.token),
  )
  let j = unwrap_response(resp, json)
  (j, { request_time: 0L, })
}

///|
/// A PUT over a query-style call (e.g. `txn`): returns the parsed body and the
/// blocking-query metadata instead of a `WriteMeta`.
pub async fn Client::do_put_q(
  self : Client,
  path : String,
  body : Bytes,
  opt : WriteOptions,
  extra : Array[(String, String)],
) -> (Json, QueryMeta) raise Refused {
  let query = self.write_query(opt, extra)
  let (resp, json) = self.do_request(
    "PUT",
    path,
    query,
    body,
    self.resolve_token(opt.token),
  )
  let j = unwrap_response(resp, json)
  (j, meta_of(resp))
}

///|
/// A POST with `opt` and extra query pairs (used by the ACL login/logout
/// endpoints), returning the parsed body and a fresh write metadata.
pub async fn Client::do_post(
  self : Client,
  path : String,
  body : Bytes,
  opt : WriteOptions,
  extra : Array[(String, String)],
) -> (Json, WriteMeta) raise Refused {
  let query = self.write_query(opt, extra)
  let (resp, json) = self.do_request(
    "POST",
    path,
    query,
    body,
    self.resolve_token(opt.token),
  )
  let j = unwrap_response(resp, json)
  (j, { request_time: 0L, })
}
