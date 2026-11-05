///|
/// A handle to the Connect API: the certificate authority's roots and
/// configuration, and the intentions that decide which services may talk to
/// which.
pub struct Connect {
  client : Client
}

///|
/// The roots this cluster's CA trusts, read cluster-wide rather than from the
/// local agent.
pub async fn Connect::ca_roots(
  self : Connect,
  options~ : QueryOptions = default_query_options,
) -> (CARoots, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/connect/ca/roots", options, [])
  (caroots_of(json), meta)
}

///|
/// The cluster-wide CA configuration.
pub async fn Connect::ca_config(
  self : Connect,
  options~ : QueryOptions = default_query_options,
) -> (CAConfig, QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get(
    "/v1/connect/ca/configuration",
    options,
    [],
  )
  (ca_config_of(json), meta)
}

///|
/// Replace the cluster-wide CA configuration. Changing the provider rotates
/// the CA; writing the configuration the cluster already has changes nothing.
pub async fn Connect::ca_set_config(
  self : Connect,
  config : CAConfig,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let body = @utf8.encode(ca_config_to_json(config).stringify())
  let (_, meta) = self.client.do_put(
    "/v1/connect/ca/configuration",
    body,
    options,
    [],
  )
  meta
}
