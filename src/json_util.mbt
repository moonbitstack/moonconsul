// JSON helpers shared by the API groups. The core `Json` enum is used
// directly (Object/Array/String/Number/True/False/Null) and each type has a
// plain `*_of(Json)` / `*_to_json` pair in its own file. Plain functions, not
// trait impls, keep the package warning-clean under `--deny-warn`; the codecs
// are still "core `Json`", which is what the organisation's convention asks
// for.

///|
/// The JSON `null`, built through `Unit`'s `ToJson` (the `Null` variant is
/// read-only and cannot be constructed directly).
pub fn json_null() -> Json {
  @json.to_json(())
}

///|
/// The object map behind a `Json`, or an empty map when it is not an object.
pub fn json_map(j : Json) -> Map[String, Json] {
  match j {
    Object(m) => m
    _ => Map([])
  }
}

///|
/// The array behind a `Json`, or an empty array when it is not an array.
pub fn json_array(j : Json) -> Array[Json] {
  match j {
    Array(a) => a
    _ => []
  }
}

///|
/// A `Json` as a bool: `true` only for `True`.
pub fn json_bool(j : Json) -> Bool {
  match j {
    True => true
    _ => false
  }
}

///|
/// The `key` value as a string, or `""` when absent or not a string.
pub fn jstr(m : Map[String, Json], key : String) -> String {
  match m.get(key) {
    Some(String(s)) => s
    _ => ""
  }
}

///|
/// The `key` value as a string, or `None`.
pub fn jstr_opt(m : Map[String, Json], key : String) -> String? {
  match m.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
/// The `key` value as an `Int32`, or `0` when absent or not a number.
pub fn ji32(m : Map[String, Json], key : String) -> Int32 {
  match m.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ => 0
  }
}

///|
/// The `key` value as an `Int32`, or `None`.
pub fn ji32_opt(m : Map[String, Json], key : String) -> Int32? {
  match m.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
/// The `key` value as an `Int64`, or `0L` when absent or not a number.
pub fn ji64(m : Map[String, Json], key : String) -> Int64 {
  match m.get(key) {
    Some(Number(n, ..)) => n.to_int64()
    _ => 0L
  }
}

///|
/// The `key` value as an `Int64`, or `None`.
pub fn ji64_opt(m : Map[String, Json], key : String) -> Int64? {
  match m.get(key) {
    Some(Number(n, ..)) => Some(n.to_int64())
    _ => None
  }
}

///|
/// The `key` value as a `Double`, or `None`.
pub fn jdouble_opt(m : Map[String, Json], key : String) -> Double? {
  match m.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
/// The `key` value as a bool, or `None`.
pub fn jbool_opt(m : Map[String, Json], key : String) -> Bool? {
  match m.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// The `key` value as an array, or `[]` when absent or not an array.
pub fn jarray(m : Map[String, Json], key : String) -> Array[Json] {
  match m.get(key) {
    Some(Array(a)) => a
    _ => []
  }
}

///|
/// The `key` value as a string array, or `None`.
pub fn jstr_array_opt(m : Map[String, Json], key : String) -> Array[String]? {
  match m.get(key) {
    Some(Array(a)) => {
      let out : Array[String] = []
      for item in a {
        if item is String(s) {
          out.push(s)
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// The `key` value as a `String` map, or `None`.
pub fn jmap_opt(m : Map[String, Json], key : String) -> Map[String, String]? {
  match m.get(key) {
    Some(Object(o)) => {
      let out : Map[String, String] = Map([])
      for k, v in o {
        if v is String(s) {
          out[k] = s
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// The `key` value as bytes, base64-decoded (Consul's encoding for binary
/// fields), or `None`.
pub fn jbytes_b64_opt(m : Map[String, Json], key : String) -> Bytes? {
  match m.get(key) {
    Some(String(s)) =>
      if s == "" {
        Some(b"")
      } else {
        Some(@base64.decode_lossy(s))
      }
    _ => None
  }
}

///|
/// An empty JSON object to fill with `put_*`.
pub fn jobj() -> Map[String, Json] {
  Map([])
}

///|
/// Set `m[key]` when `v` is `Some`, leaving it out when `None`.
pub fn put_str(m : Map[String, Json], key : String, v : String?) -> Unit {
  match v {
    Some(s) => m[key] = @json.to_json(s)
    None => ()
  }
}

///|
/// Set an `Int32` field when `Some`.
pub fn put_i32(m : Map[String, Json], key : String, v : Int32?) -> Unit {
  match v {
    Some(n) => m[key] = @json.to_json(n)
    None => ()
  }
}

///|
/// Set an `Int64` field when `Some`.
pub fn put_i64(m : Map[String, Json], key : String, v : Int64?) -> Unit {
  match v {
    Some(n) => m[key] = @json.to_json(n)
    None => ()
  }
}

///|
/// Set a bool field when `Some`.
pub fn put_bool(m : Map[String, Json], key : String, v : Bool?) -> Unit {
  match v {
    Some(b) => m[key] = @json.to_json(b)
    None => ()
  }
}

///|
/// Set a nested JSON value when `Some`.
pub fn put_json(m : Map[String, Json], key : String, v : Json?) -> Unit {
  match v {
    Some(j) => m[key] = j
    None => ()
  }
}

///|
/// Set a string-array field when `Some`.
pub fn put_str_array(
  m : Map[String, Json],
  key : String,
  v : Array[String]?,
) -> Unit {
  match v {
    Some(items) => {
      let arr : Array[Json] = []
      for item in items {
        arr.push(@json.to_json(item))
      }
      m[key] = @json.to_json(arr)
    }
    None => ()
  }
}

///|
/// Parse a decimal `Int64` from a string, returning `0L` on anything non-numeric.
pub fn parse_i64(s : StringView) -> Int64 {
  let text = s.to_owned()
  let mut n : Int64 = 0L
  let mut neg = false
  let mut started = false
  for ch in text {
    let code = ch.to_int()
    if !started && code == 45 {
      neg = true
      started = true
      continue
    }
    if code < 48 || code > 57 {
      break
    }
    started = true
    n = n * 10L + (code - 48).to_int64()
  }
  if neg {
    -n
  } else {
    n
  }
}

///|
/// Percent-encode a query component, keeping only the RFC 3986 unreserved set.
pub fn url_encode(s : String) -> String {
  let mut out = ""
  for ch in s {
    let code = ch.to_int()
    let ok = (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 45 ||
      code == 46 ||
      code == 95 ||
      code == 126
    if ok {
      out = out + ch.to_string()
    } else {
      out = out + "%" + hex_digit(code / 16) + hex_digit(code % 16)
    }
  }
  out
}

///|
/// A single uppercase hex digit for `n` in `0..=15`.
fn hex_digit(n : Int32) -> String {
  match n {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "A"
    11 => "B"
    12 => "C"
    13 => "D"
    14 => "E"
    15 => "F"
    _ => "0"
  }
}
