# Nim-BLST
# Copyright (c) 2020 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

# https://tools.ietf.org/html/draft-irtf-cfrg-bls-signature-02
#
# Variant Minimal-pubkey-size:
#   public keys are points in G1, signatures are
#   points in G2.
#   Implementations using signature aggregation SHOULD use this
#   approach, since the size of (PK_1, ..., PK_n, signature) is
#   dominated by the public keys even for small n.

# We expose the same API as nim-blscurve

import
  # Status libraries
  stew/byteutils,
  # Internals
  ./blst_lowlevel

# TODO: Consider keeping the compressed keys/signatures in memory
#       to divide mem usage by 2
#       i.e. use the staging "pk2" variants like
#       - blst_sk_to_pk2_in_g1
#       - blst_sign_pk2_in_g1

type
  SecretKey* = object
    ## A secret key in the BLS (Boneh-Lynn-Shacham) signature scheme.
    ## This secret key SHOULD be protected against:
    ## - side-channel attacks:
    ##     implementation must perform exactly the same memory access
    ##     and execute the same step. In other words it should run in constant time.
    ##     Furthermore, retrieval of secret key data has been done by reading
    ##     voltage and power usage on embedded devices
    ## - memory dumps:
    ##     core dumps in case of program crash could leak the data
    ## - root attaching to process:
    ##     a root process like a debugger could attach and read the secret key
    ## - key remaining in memory:
    ##     if the key is not securely erased from memory, it could be accessed
    ##
    ## Long-term storage of this key also requires adequate protection.
    ##
    ## At the moment, the nim-blscurve library does not guarantee such protections
    scalar: blst_scalar

  PublicKey* = object
    ## A public key in the BLS (Boneh-Lynn-Shacham) signature scheme.
    point: blst_p1_affine

  # We split Signature and AggregateSignature?
  # This saves 1/3 of size as well as signature
  # can be affine (2 coordinates) while aggregate has to be jacobian/projective (3 coordinates)
  Signature* = object
    ## A digital signature of a message using the BLS (Boneh-Lynn-Shacham) signature scheme.
    point: blst_p2_affine

  AggregateSignature = object
    ## An aggregated Signature (private type for now)
    point: blst_p2

  ProofOfPossession* = object
    ## A separate public key in the Proof-of-Possession BLS signature variant scheme
    point: blst_p2_affine

func `==`*(a, b: SecretKey): bool {.error: "Comparing secret keys is not allowed".}
  ## Disallow comparing secret keys. It would require constant-time comparison,
  ## and it doesn't make sense anyway.

func `==`*(a, b: PublicKey or Signature or ProofOfPossession): bool {.inline.} =
  ## Check if 2 BLS signature scheme objects are equal
  when a.point is blst_p1:
    result = bool(
      blst_p1_affine_is_equal(
        a.point, b.point
      )
    )
  else:
    result = bool(
      blst_p2_affine_is_equal(
        a.point, b.point
      )
    )

# IO
# ----------------------------------------------------------------------
# Serialization / Deserialization

func fromBytes*(
       obj: var (Signature|ProofOfPossession),
       raw: array[96, byte]
      ): bool {.inline.} =
  ## Initialize a BLS signature scheme object from
  ## its raw bytes representation.
  ## Returns true on success and false otherwise
  # TODO: consider using affine coordinates everywhere beside
  result = obj.point.blst_p2_uncompress(raw) == BLST_SUCCESS

func fromBytes*(
       obj: var PublicKey,
       raw: array[48, byte]
      ): bool {.inline.} =
  ## Initialize a BLS signature scheme object from
  ## its raw bytes representation.
  ## Returns true on success and false otherwise
  result = obj.point.blst_p1_uncompress(raw) == BLST_SUCCESS

func fromBytes*(
       obj: var SecretKey,
       raw: array[32, byte]
      ): bool {.inline.} =
  ## Initialize a BLS signature scheme object from
  ## its raw bytes representation.
  ## Returns true on success and false otherwise
  obj.scalar.blst_scalar_from_bendian(raw)
  return true

func fromHex*(
       obj: var (SecretKey|PublicKey|Signature|ProofOfPossession),
       hexStr: string
     ): bool {.inline.} =
  ## Initialize a BLS signature scheme object from
  ## its hex raw bytes representation.
  ## Returns true on a success and false otherwise
  when obj is SecretKey:
    const size = 32
  elif obj is PublicKey:
    const size = 48
  elif obj is (Signature or ProofOfPossession):
    const size = 96

  var bytes{.noInit.}: array[size, byte]
  try: # TODO: Conversion without exceptions
    hexStr.hexToByteArray(bytes)
  except:
    return false
  result = obj.fromBytes(bytes)

func toHex*(
       obj: SecretKey|PublicKey|Signature|ProofOfPossession|AggregateSignature,
     ): string =
  ## Return the hex representation of a BLS signature scheme object
  ## They are serialized in compressed form
  when obj is SecretKey:
    const size = 32
    var bytes{.noInit.}: array[size, byte]
    bytes.blst_bendian_from_scalar(obj.scalar)
  elif obj is PublicKey:
    const size = 48
    var bytes{.noInit.}: array[size, byte]
    bytes.blst_p1_affine_compress(obj.point)
  elif obj is (Signature or ProofOfPossession):
    const size = 96
    var bytes{.noInit.}: array[size, byte]
    bytes.blst_p2_affine_compress(obj.point)
  elif obj is AggregateSignature:
    const size = 96
    var bytes{.noInit.}: array[size, byte]
    bytes.blst_p2_compress(obj.point)

  result = bytes.toHex()

# Primitives
# ----------------------------------------------------------------------

func privToPub*(secretKey: SecretKey): PublicKey {.inline.} =
  ## Generates a public key from a secret key
  var pk {.noInit.}: blst_p1
  pk.blst_sk_to_pk_in_g1(secretKey.scalar)
  result.point.blst_p1_to_affine(pk)

# Aggregate
# ----------------------------------------------------------------------

func aggregate(agg: var AggregateSignature, sig: Signature) {.inline.} =
  ## Aggregates signature ``sig`` into ``agg``
  agg.point.blst_p2_add_or_double_affine(
    agg.point,
    sig.point
  )

proc aggregate(agg: var AggregateSignature, sigs: openarray[Signature]) =
  ## Aggregates an array of signatures `sigs` into a signature `sig`
  for s in sigs:
    agg.point.blst_p2_add_or_double_affine(
      agg.point,
      s.point
    )

proc aggregate*(sigs: openarray[Signature]): Signature =
  ## Aggregates array of signatures ``sigs``
  ## and return aggregated signature.
  ##
  ## Array ``sigs`` must not be empty!
  # TODO: what is the correct empty signature to return?
  #       for now we assume that empty aggregation is handled at the client level
  doAssert(len(sigs) > 0)
  var agg{.noInit.}: AggregateSignature
  agg.point.blst_p2_from_affine(sigs[0].point)
  agg.aggregate(sigs.toOpenArray(1, sigs.high))

  result.point.blst_p2_to_affine(agg.point)

# Core operations
# ----------------------------------------------------------------------
# Note: unlike the IETF standard, we stay in the curve domain
#       instead of serializing/deserializing public keys and signatures
#       from octet strings/byte arrays to/from G1 or G2 point repeatedly
# Note: functions have the additional DomainSeparationTag defined
#       in https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09
#
# For coreAggregateVerify, we introduce an internal streaming API that
# can handle both
# - publicKeys: openarray[PublicKey], messages: openarray[openarray[T]]
# - pairs: openarray[tuple[publicKeys: seq[PublicKey], message: seq[byte or string]]]
# efficiently for the high-level API
#
# This also allows efficient interleaving of Proof-Of-Possession checks in the high-level API

func coreSign[T: byte|char](
       signature: var (Signature or ProofOfPossession),
       secretKey: SecretKey,
       message: openarray[T],
       domainSepTag: static string) =
  ## Computes a signature or proof-of-possession
  ## from a secret key and a message
  # Spec
  # 1. Q = hash_to_point(message)
  # 2. R = SK * Q
  # 3. signature = point_to_signature(R)
  # 4. return signature
  var sig{.noInit.}: blst_p2
  sig.blst_hash_to_g2(
    message,
    domainSepTag,
    aug = ""
  )
  sig.blst_sign_pk_in_g1(sig, secretKey.scalar)
  signature.point.blst_p2_to_affine(sig)

func coreVerify[T: byte|char](
       publicKey: PublicKey,
       message: openarray[T],
       sig_or_proof: Signature or ProofOfPossession,
       domainSepTag: static string): bool {.inline.} =
  ## Check that a signature (or proof-of-possession) is valid
  ## for a message (or serialized publickey) under the provided public key
  result = BLST_SUCCESS == blst_core_verify_pk_in_g1(
    publicKey.point,
    sig_or_proof.point,
    hash_or_encode = kHash,
    message,
    domainSepTag,
    aug = ""
  )

type
  ContextCoreAggregateVerify = object
    # Streaming API for Aggregate verification to handle both SoA and AoS data layout
    # Spec
    # 1. R = signature_to_point(signature)
    # 2. If R is INVALID, return INVALID
    # 3. If signature_subgroup_check(R) is INVALID, return INVALID
    # 4. C1 = 1 (the identity element in GT)
    # 5. for i in 1, ..., n:
    # 6.     xP = pubkey_to_point(PK_i)
    # 7.     Q = hash_to_point(message_i)
    # 8.     C1 = C1 * pairing(Q, xP)
    # 9. C2 = pairing(R, P)
    # 10. If C1 == C2, return VALID, else return INVALID
    c: blst_pairing

func init(ctx: var ContextCoreAggregateVerify) {.inline.} =
  ## initialize an aggregate verification context
  ctx.c.blst_pairing_init()                           # C1 = 1 (identity element)

func update[T: char|byte](
       ctx: var ContextCoreAggregateVerify,
       publicKey: PublicKey,
       message: openarray[T],
       domainSepTag: static string): bool {.inline.} =
  result = BLST_SUCCESS == ctx.c.blst_pairing_aggregate_pk_in_g1(
    PK = publicKey.point.unsafeAddr,
    signature = nil,
    hash_or_encode = kHash,
    message,
    domainSepTag,
    ""
  )

func finish(ctx: var ContextCoreAggregateVerify, signature: Signature or AggregateSignature): bool =
  # Implementation strategy
  # -----------------------
  # We are checking that
  # e(pubkey1, msg1) e(pubkey2, msg2) ... e(pubkeyN, msgN) == e(P1, sig)
  # with P1 the generator point for G1
  # For x' = (q^12 - 1)/r
  # - q the BLS12-381 field modulus: 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
  # - r the BLS12-381 subgroup size: 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
  #
  # constructed from x = -0xd201000000010000
  # - q = (x - 1)² ((x⁴ - x² + 1) / 3) + x
  # - r = (x⁴ - x² + 1)
  #
  # we have the following equivalence by removing the final exponentiation
  # in the optimal ate pairing, and denoting e'(_, _) the pairing without final exponentiation
  # (e'(pubkey1, msg1) e'(pubkey2, msg2) ... e'(pubkeyN, msgN))^x == e'(P1, sig)^x
  #
  # We multiply by the inverse in group GT (e(G1, G2) -> GT)
  # to get the equivalent check that is more efficient to implement
  # (e'(pubkey1, msg1) e'(pubkey2, msg2) ... e'(pubkeyN, msgN) e'(-P1, sig))^x == 1
  # The generator P1 is on G1 which is cheaper to negate than the signature

  # We add the signature to the pairing context
  # via `blst_pairing_aggregate_pk_in_g1`
  # instead of via `blst_aggregated_in_g2` + `blst_pairing_finalverify`
  # to save one Miller loop
  # as both `blst_pairing_commit` and `blst_pairing_finalverify(non-nil)`
  # use a Miller loop internally and Miller loops are **very** costly.

  when signature is Signature:
    result = BLST_SUCCESS == ctx.c.blst_pairing_aggregate_pk_in_g1(
      PK = nil,
      signature = signature.point.unsafeAddr,
      hash_or_encode = kHash,
      msg = "",
      domainSepTag = "",
      aug = ""
    )
  elif signature is AggregateSignature:
    block:
      var sig{.noInit.}: blst_p2_affine
      sig.blst_p2_to_affine(signature.point)
      result = BLST_SUCCESS == ctx.c.blst_pairing_aggregate_pk_in_g1(
        PK = nil,
        signature = sig,
        hash_or_encode = kHash,
        msg = "",
        domainSepTag = "",
        aug = ""
      )
  else:
    {.error: "Unreachable".}

  if not result: return

  ctx.c.blst_pairing_commit()
  result = bool ctx.c.blst_pairing_finalverify(nil)


# Public API
# ----------------------------------------------------------------------
#
# There are 3 BLS schemes that differ in handling rogue key attacks
# - basic: requires message signed by an aggregate signature to be distinct
# - message augmentation: signatures are generated over the concatenation of public key and the message
#                         enforcing message signed by different public key to be distinct
# - proof of possession: a separate public key called proof-of-possession is used to allow signing
#                        on the same message while defending against rogue key attacks
# with respective ID / domain separation tag:
# - BLS_SIG_BLS12381G2-SHA256-SSWU-RO-_NUL_
# - BLS_SIG_BLS12381G2-SHA256-SSWU-RO-_AUG_
# - BLS_SIG_BLS12381G2-SHA256-SSWU-RO-_POP_
#   - POP tag: BLS_POP_BLS12381G2-SHA256-SSWU-RO-_POP_
#
# We implement the proof-of-possession scheme
# Compared to the spec API are modified
# to enforce usage of the proof-of-posession (as recommended)

const DST = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_"
const DST_POP = "BLS_POP_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_"

func popProve*(secretKey: SecretKey, publicKey: PublicKey): ProofOfPossession =
  ## Generate a proof of possession for the public/secret keypair
  # 1. xP = SK * P
  # 2. PK = point_to_pubkey(xP)
  # 3. Q = hash_pubkey_to_point(PK)
  # 4. R = SK * Q
  # 5. proof = point_to_signature(R)
  # 6. return proof
  var pk{.noInit.}: array[48, byte]
  pk.blst_p1_affine_compress(publicKey.point)    # 2. Convert to raw bytes compressed form
  result.coreSign(secretKey, pk, DST_POP) # 3-4. hash_to_curve and multiply by secret key

func popProve*(secretKey: SecretKey): ProofOfPossession =
  ## Generate a proof of possession for the public key associated with the input secret key
  ## Note: this internally recomputes the public key, an overload that doesn't is available.
  # 1. xP = SK * P
  # 2. PK = point_to_pubkey(xP)
  # 3. Q = hash_pubkey_to_point(PK)
  # 4. R = SK * Q
  # 5. proof = point_to_signature(R)
  # 6. return proof
  let pubkey = privToPub(secretKey)
  result = popProve(secretKey, pubkey)

func popVerify*(publicKey: PublicKey, proof: ProofOfPossession): bool =
  ## Verify if the proof-of-possession is valid for the public key
  ## returns true if valid or false if invalid
  # 1. R = signature_to_point(proof)
  # 2. If R is INVALID, return INVALID
  # 3. If signature_subgroup_check(R) is INVALID, return INVALID
  # 4. If KeyValidate(PK) is INVALID, return INVALID
  # 5. xP = pubkey_to_point(PK)
  # 6. Q = hash_pubkey_to_point(PK)
  # 7. C1 = pairing(Q, xP)
  # 8. C2 = pairing(R, P)
  # 9. If C1 == C2, return VALID, else return INVALID
  var pk{.noInit.}: array[48, byte]
  pk.blst_p1_affine_compress(publicKey.point)
  result = coreVerify(publicKey, pk, proof, DST_POP)

func sign*[T: byte|char](secretKey: SecretKey, message: openarray[T]): Signature =
  ## Computes a signature
  ## from a secret key and a message
  result.coreSign(secretKey, message, DST)

func verify*[T: byte|char](
       publicKey: PublicKey,
       proof: ProofOfPossession,
       message: openarray[T],
       signature: Signature) : bool =
  ## Check that a signature is valid for a message
  ## under the provided public key.
  ## returns `true` if the signature is valid, `false` otherwise.
  ##
  ## Compared to the IETF spec API, it is modified to
  ## enforce proper usage of the proof-of-possession
  if not publicKey.popVerify(proof):
    return false
  return publicKey.coreVerify(message, signature, DST)

func verify*[T: byte|char](
       publicKey: PublicKey,
       message: openarray[T],
       signature: Signature) : bool =
  ## Check that a signature is valid for a message
  ## under the provided public key.
  ## returns `true` if the signature is valid, `false` otherwise.
  ##
  ## The proof-of-possession MUST be verified before calling this function.
  ## It is recommended to use the overload that accepts a proof-of-possession
  ## to enforce correct usage.
  return publicKey.coreVerify(message, signature, DST)

func aggregateVerify*(
        publicKeys: openarray[PublicKey],
        proofs: openarray[ProofOfPossession],
        messages: openarray[string or seq[byte]],
        signature: Signature): bool =
  ## Check that an aggregated signature over several (publickey, message) pairs
  ## returns `true` if the signature is valid, `false` otherwise.
  ##
  ## Compared to the IETF spec API, it is modified to
  ## enforce proper usage of the proof-of-possessions
  # Note: we can't have openarray of openarrays until openarrays are first-class value types
  if publicKeys.len != proofs.len or publicKeys != messages.len:
    return false
  if not(publicKeys.len >= 1):
    return false

  var ctx: ContextCoreAggregateVerify
  ctx.init()
  for i in 0 ..< publicKeys.len:
    if not publicKeys[i].popVerify(proofs[i]):
      return false
    ctx.update(publicKeys[i], messages[i], DST)
  return ctx.finish(signature)

func aggregateVerify*(
        publicKeys: openarray[PublicKey],
        messages: openarray[string or seq[byte]],
        signature: Signature): bool =
  ## Check that an aggregated signature over several (publickey, message) pairs
  ## returns `true` if the signature is valid, `false` otherwise.
  ##
  ## The proof-of-possession MUST be verified before calling this function.
  ## It is recommended to use the overload that accepts a proof-of-possession
  ## to enforce correct usage.
  # Note: we can't have openarray of openarrays until openarrays are first-class value types
  if publicKeys.len != messages.len:
    return false
  if not(publicKeys.len >= 1):
    return false

  var ctx{.noInit.}: ContextCoreAggregateVerify
  ctx.init()
  for i in 0 ..< publicKeys.len:
    result = ctx.update(publicKeys[i], messages[i], DST)
    if not result:
      return
  return ctx.finish(signature)

func aggregateVerify*[T: string or seq[byte]](
        publicKey_msg_pairs: openarray[tuple[publicKey: PublicKey, message: T]],
        signature: Signature): bool =
  ## Check that an aggregated signature over several (publickey, message) pairs
  ## returns `true` if the signature is valid, `false` otherwise.
  ##
  ## The proof-of-possession MUST be verified before calling this function.
  ## It is recommended to use the overload that accepts a proof-of-possession
  ## to enforce correct usage.
  # Note: we can't have tuple of openarrays until openarrays are first-class value types
  if not(publicKey_msg_pairs.len >= 1):
    return false
  var ctx: ContextCoreAggregateVerify
  ctx.init()
  for i in 0 ..< publicKey_msg_pairs.len:
    result = ctx.update(publicKey_msg_pairs[i].publicKey, publicKey_msg_pairs[i].message, DST)
    if not result:
      return
  return ctx.finish(signature)

func fastAggregateVerify*[T: byte|char](
        publicKeys: openarray[PublicKey],
        proofs: openarray[ProofOfPossession],
        message: openarray[T],
        signature: Signature
      ): bool =
  ## Verify the aggregate of multiple signatures on the same message
  ## This function is faster than AggregateVerify
  ## Compared to the IETF spec API, it is modified to
  ## enforce proper usage of the proof-of-posession
  # 1. aggregate = pubkey_to_point(PK_1)
  # 2. for i in 2, ..., n:
  # 3.     next = pubkey_to_point(PK_i)
  # 4.     aggregate = aggregate + next
  # 5. PK = point_to_pubkey(aggregate)
  # 6. return CoreVerify(PK, message, signature)
  if publicKeys.len == 0:
    return false
  if not publicKeys[0].popVerify(proofs[0]):
    return false
  var aggregate {.noInit.}: blst_p1
  aggregate.blst_p1_from_affine(publicKeys[0].point)
  for i in 1 ..< publicKeys.len:
    if not publicKeys[i].popVerify(proofs[i]):
      return false
    # We assume that the PublicKey is in on curve, in the proper subgroup
    aggregate.blst_p1_add_or_double_affine(publicKeys[i].point)

  var aggAffine{.noInit.}: PublicKey
  aggAffine.point.blst_p1_to_affine(aggregate)
  return coreVerify(aggAffine, message, signature, DST)

func fastAggregateVerify*[T: byte|char](
        publicKeys: openarray[PublicKey],
        message: openarray[T],
        signature: Signature
      ): bool =
  ## Verify the aggregate of multiple signatures on the same message
  ## This function is faster than AggregateVerify
  ##
  ## The proof-of-possession MUST be verified before calling this function.
  ## It is recommended to use the overload that accepts a proof-of-possession
  ## to enforce correct usage.
  # 1. aggregate = pubkey_to_point(PK_1)
  # 2. for i in 2, ..., n:
  # 3.     next = pubkey_to_point(PK_i)
  # 4.     aggregate = aggregate + next
  # 5. PK = point_to_pubkey(aggregate)
  # 6. return CoreVerify(PK, message, signature)
  if publicKeys.len == 0:
    return false
  var aggregate {.noInit.}: blst_p1
  aggregate.blst_p1_from_affine(publicKeys[0].point)
  for i in 1 ..< publicKeys.len:
    # We assume that the PublicKey is in on curve, in the proper subgroup
    aggregate.blst_p1_add_or_double_affine(aggregate, publicKeys[i].point)

  var aggAffine{.noInit.}: PublicKey
  aggAffine.point.blst_p1_to_affine(aggregate)
  return coreVerify(aggAffine, message, signature, DST)

func keyGen*(ikm: openarray[byte], publicKey: var PublicKey, secretKey: var SecretKey): bool =
  ## Generate a (public key, secret key) pair
  ## from the input keying material `ikm`
  ##
  ## For security, `ikm` MUST be infeasible to guess, for example,
  ## generated from a trusted source of randomness.
  ##
  ## `ikm` MUST be at least 32 bytes long but may be longer
  ##
  ## Key generation is deterministic
  ##
  ## Either the keypair (publickey, secretkey) can be stored or
  ## the `ikm` can be stored and keys can be regenerated on demand.
  ##
  ## Inputs:
  ##   - IKM: a secret array or sequence of bytes
  ##
  ## Outputs:
  ##   - publicKey
  ##   - secretKey
  ##
  ## Returns `true` if generation successful
  ## Returns `false` if generation failed
  ## Generation fails if `ikm` length is less than 32 bytes
  ##
  ## `IKM` and  `secretkey` must be protected against side-channel attacks
  ## including timing attaks, memory dumps, attaching processes, ...
  ## and securely erased from memory.
  ##
  ## At the moment, the nim-blscurve library does not guarantee such protections

  #  (PK, SK) = KeyGen(IKM)
  #
  #  Inputs:
  #  - IKM, a secret octet string. See requirements above.
  #
  #  Outputs:
  #  - PK, a public key encoded as an octet string.
  #  - SK, the corresponding secret key, an integer 0 <= SK < r.
  #
  #  Definitions:
  #  - HKDF-Extract is as defined in RFC5869, instantiated with hash H.
  #  - HKDF-Expand is as defined in RFC5869, instantiated with hash H.
  #  - L is the integer given by ceil((1.5 * ceil(log2(r))) / 8).
  #  - "BLS-SIG-KEYGEN-SALT-" is an ASCII string comprising 20 octets.
  #  - "" is the empty string.
  #
  #  Procedure:
  #  1. PRK = HKDF-Extract("BLS-SIG-KEYGEN-SALT-", IKM)
  #  2. OKM = HKDF-Expand(PRK, "", L)
  #  3. x = OS2IP(OKM) mod r
  #  4. xP = x * P
  #  5. SK = x
  #  6. PK = point_to_pubkey(xP)
  #  7. return (PK, SK)
  secretKey.scalar.blst_keygen(ikm, info = "")
  publicKey = privToPub(secretKey)
