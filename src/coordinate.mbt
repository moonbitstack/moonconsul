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
/// A `CoordinateValue` from its JSON object.
fn coordinate_value_of(j : Json) -> CoordinateValue {
  let m = json_map(j)
  let vec : Array[Double] = []
  for item in jarray(m, "Vec") {
    if item is Number(n, ..) {
      vec.push(n)
    }
  }
  {
    vec,
    error: match jdouble_opt(m, "Error") {
      Some(d) => d
      None => 0.0
    },
    adjustment: match jdouble_opt(m, "Adjustment") {
      Some(d) => d
      None => 0.0
    },
    height: match jdouble_opt(m, "Height") {
      Some(d) => d
      None => 0.0
    },
  }
}

///|
/// A `CoordinateValue` as a JSON object.
fn coordinate_value_to_json(v : CoordinateValue) -> Json {
  let m = jobj()
  let vec : Array[Json] = []
  for d in v.vec {
    vec.push(@json.to_json(d))
  }
  m["Vec"] = @json.to_json(vec)
  m["Error"] = @json.to_json(v.error)
  m["Adjustment"] = @json.to_json(v.adjustment)
  m["Height"] = @json.to_json(v.height)
  @json.to_json(m)
}

///|
/// A `CoordinateEntry` from its JSON object.
fn coordinate_entry_of(j : Json) -> CoordinateEntry {
  let m = json_map(j)
  {
    node: jstr(m, "Node"),
    segment: jstr_opt(m, "Segment"),
    coord: match m.get("Coord") {
      Some(c) =>
        if c is Object(_) {
          Some(coordinate_value_of(c))
        } else {
          None
        }
      None => None
    },
  }
}

///|
/// A `CoordinateNode` from its JSON object.
fn coordinate_node_of(j : Json) -> CoordinateNode {
  let m = json_map(j)
  let coordinates : Array[CoordinateEntry] = []
  for item in jarray(m, "Coordinates") {
    coordinates.push(coordinate_entry_of(item))
  }
  { node: jstr(m, "Node"), coordinates, }
}

///|
/// The coordinates of every datacenter, as seen from this node.
pub async fn Coordinate::datacenters(
  self : Coordinate,
  options~ : QueryOptions = default_query_options,
) -> (Array[CoordinateNode], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/coordinate/datacenters", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[CoordinateNode] = []
  for item in json_array(json) {
    out.push(coordinate_node_of(item))
  }
  (out, meta)
}

///|
/// The coordinates of the nodes in this datacenter.
pub async fn Coordinate::nodes(
  self : Coordinate,
  options~ : QueryOptions = default_query_options,
) -> (Array[CoordinateEntry], QueryMeta) raise Refused {
  let (json, meta) = self.client.do_get("/v1/coordinate/nodes", options, []) catch {
    Refused::NotFound => return ([], empty_query_meta())
    e => raise e
  }
  let out : Array[CoordinateEntry] = []
  for item in json_array(json) {
    out.push(coordinate_entry_of(item))
  }
  (out, meta)
}

///|
/// Publish this node's own `coord`.
pub async fn Coordinate::update(
  self : Coordinate,
  coord : CoordinateValue,
  options~ : WriteOptions = default_write_options,
) -> WriteMeta raise Refused {
  let m = jobj()
  m["Coord"] = coordinate_value_to_json(coord)
  let body = @utf8.encode(@json.to_json(m).stringify())
  let (_, meta) = self.client.do_put("/v1/coordinate/update", body, options, [])
  meta
}
