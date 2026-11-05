// The JWT the login tests present. A JWT auth method is configured with the
// public half of a key, so the tests need a signed token: this signs one with
// Ed25519 over a fixed seed, which keeps the fixture in the source rather than
// in a file that expires.

///|
/// A seed for the test key, the same on every run so the public key a test
/// configures is the one this token verifies against.
let jwt_seed : String = "moonconsul jwt login test seed"

///|
/// The subject the token carries, which a binding rule selects on.
let jwt_subject : String = "moonconsul-jwt"

///|
/// The signing key.
fn jwt_key() -> @ed25519.PrivateKey {
  @ed25519.PrivateKey::of_secret(@utf8.encode(jwt_seed)[:])
}

///|
/// Base64url without padding, as a JWT segment is written.
fn jwt_base64url(bytes : Bytes) -> String {
  @base64.encode(bytes, padding=false)
  .replace_all(old="+", new="-")
  .replace_all(old="/", new="_")
}

///|
/// `text` wrapped at 64 columns between a PEM's two markers.
fn jwt_pem(label : String, der : Bytes) -> String {
  let body = @base64.encode(der)
  let mut wrapped = ""
  let mut column = 0
  for ch in body {
    if column == 64 {
      wrapped = wrapped + "\n"
      column = 0
    }
    wrapped = wrapped + ch.to_string()
    column += 1
  }
  "-----BEGIN " +
  label +
  "-----\n" +
  wrapped +
  "\n-----END " +
  label +
  "-----\n"
}

///|
/// The public key in the SubjectPublicKeyInfo PEM a JWT auth method's
/// `JWTValidationPubkeys` takes. RFC 8410 §4 fixes the prefix for Ed25519:
/// the key algorithm OID 1.3.101.112 inside an OCTET STRING.
fn jwt_public_pem() -> String {
  let prefix : Array[Byte] = [
    b'\x30', b'\x2a', b'\x30', b'\x05', b'\x06', b'\x03', b'\x2b', b'\x65', b'\x70',
    b'\x03', b'\x21', b'\x00',
  ]
  let der : Array[Byte] = []
  for byte in prefix {
    der.push(byte)
  }
  for byte in jwt_key().public().bytes() {
    der.push(byte)
  }
  jwt_pem("PUBLIC KEY", Bytes::from_array(der))
}

///|
/// A token signed with the test key: `sub` is the subject a binding rule
/// selects on, and the validity runs from now for an hour.
fn jwt_login_token() -> String {
  let header = jwt_base64url(
    @utf8.encode("{\"alg\":\"EdDSA\",\"typ\":\"JWT\"}"),
  )
  let now = (@env.now() / 1000UL).reinterpret_as_int64()
  let claims = Json::object(
    Map([
      ("sub", Json::string(jwt_subject)),
      ("iat", Json::number(now.to_double(), repr=now.to_string())),
      (
        "exp",
        Json::number((now + 3600L).to_double(), repr=(now + 3600L).to_string()),
      ),
    ]),
  )
  let payload = jwt_base64url(@utf8.encode(claims.stringify()))
  let signing_input = header + "." + payload
  let signature = jwt_key().sign(@utf8.encode(signing_input)[:])
  signing_input + "." + jwt_base64url(signature)
}
