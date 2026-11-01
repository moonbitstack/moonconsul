///|
/// A handle to the Coordinate API: network coordinates (Vivaldi-embedded
/// positions) for latency-aware routing and nearest-node selection.
pub struct Coordinate {
  client : Client
}

///|
/// A single node's network coordinate: a `vec` in the embedded space plus an
/// `error`, `adjustment` and `height`.
pub(all) struct CoordinateValue {
  vec : Array[Double]
  error : Double
  adjustment : Double
  height : Double
}

///|
/// One node's coordinate in a segment.
pub(all) struct CoordinateEntry {
  node : String
  segment : String?
  coord : CoordinateValue?
}

///|
/// A node and the coordinates it holds for each datacenter segment.
pub(all) struct CoordinateNode {
  node : String
  coordinates : Array[CoordinateEntry]
}

///|
/// The coordinates of every datacenter, as seen from this node.
pub fn Coordinate::datacenters(
  self : Coordinate,
  options~ : QueryOptions = default_query_options,
) -> (Array[CoordinateNode], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("coordinate.datacenters")
}

///|
/// The coordinates of the nodes in this datacenter.
pub fn Coordinate::nodes(
  self : Coordinate,
  options~ : QueryOptions = default_query_options,
) -> (Array[CoordinateEntry], QueryMeta) raise Refused {
  let _ = (self, options)
  raise Refused::Unimplemented("coordinate.nodes")
}

///|
/// Publish this node's own `coord`.
pub fn Coordinate::update(
  self : Coordinate,
  coord : CoordinateValue,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let _ = (self, coord, options)
  raise Refused::Unimplemented("coordinate.update")
}
