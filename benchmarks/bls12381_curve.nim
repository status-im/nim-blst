# Nim-BLSCurve
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  # Stdlib
  std/random,
  # Internals
  ../blst/blst_lowlevel,
  # Bench
  ./bench_templates

# ############################################################
#
#             Benchmark of BLS curve
#              (Barreto-Lynn-Scott)
#
# ############################################################

var benchRNG = initRand(0xFACADE)

proc benchScalarMultG1*(iters: int) =
  var x{.noInit.}: blst_p1
  x.blst_p1_from_affine(BLS12_381_G1) # init from generator

  var scal{.noInit.}: array[32, byte]
  for val in scal.mitems:
    val = byte benchRNG.rand(0xFF)

  var scalar{.noInit.}: blst_scalar

  bench("Scalar multiplication G1 (255-bit)", iters):
    x.blst_p1_mult_w5(x, scalar, 255)

proc benchScalarMultG2*(iters: int) =
  var x{.noInit.}: blst_p2
  x.blst_p2_from_affine(BLS12_381_G2) # init from generator

  var scal{.noInit.}: array[32, byte]
  for val in scal.mitems:
    val = byte benchRNG.rand(0xFF)

  var scalar{.noInit.}: blst_scalar

  bench("Scalar multiplication G2 (255-bit)", iters):
    x.blst_p2_mult_w5(x, scalar, 255)

proc benchECAddG1*(iters: int) =
  var x{.noInit.}, y{.noInit.}: blst_p1
  x.blst_p1_from_affine(BLS12_381_G1) # init from generator
  y = x

  bench("EC add G1", iters):
    x.blst_p1_add_or_double(x, y)

proc benchECAddG2*(iters: int) =
  var x{.noInit.}, y{.noInit.}: blst_p2
  x.blst_p2_from_affine(BLS12_381_G2) # init from generator
  y = x

  bench("EC add G2", iters):
    x.blst_p2_add_or_double(x, y)

proc newKeyPair(pubkey: var blst_p1_affine, seckey: var blst_scalar) =
  var ikm{.noInit.}: array[32, byte]
  for val in ikm.mitems:
    val = byte benchRNG.rand(0xFF)

  seckey.blst_keygen(ikm, info = "")
  var pk{.noInit.}: blst_p1
  pk.blst_sk_to_pk_in_g1(seckey)
  pubkey.blst_p1_to_affine(pk)

proc sign(signature: var blst_p2_affine, seckey: blst_scalar, msg, domainSepTag: string) =
  var sig{.noInit.}: blst_p2
  sig.blst_hash_to_g2(
    msg,
    domainSepTag,
    aug = ""
  )
  sig.blst_sign_pk_in_g1(sig, seckey)
  signature.blst_p2_to_affine(sig)

var ctxSave: blst_pairing # Save some stack
const msg = "msg"
const domainSepTag = "BLS_SIG_BLS12381G2-SHA256-SSWU-RO_POP_"

proc benchPairing*(iters: int) =
  # Ideally we don't depend on the bls_signature_scheme but it's much simpler
  var
    pubkey {.noInit.}: blst_p1_affine
    seckey {.noInit.}: blst_scalar
  newKeyPair(pubkey, seckey)

  # Signing
  var sig{.noInit.}: blst_p2_affine
  sig.sign(seckey, msg, domainSepTag)

  # Verification
  var ctx: ref blst_pairing # Avoid stack smashing
  new ctx
  ctx[].blst_pairing_init()
  discard ctx[].blst_pairing_aggregate_pk_in_g1(
    PK = pubkey.unsafeAddr,
    signature = nil,
    hash_or_encode = kHash,
    msg,
    domainSepTag,
    aug = ""
  )
  discard ctx[].blst_pairing_aggregate_pk_in_g1(
    PK = nil,
    signature = sig.unsafeAddr,
    hash_or_encode = kHash,
    msg = "",
    domainSepTag = "",
    aug = ""
  )

  ctxSave = ctx[]
  # Pairing: e(Q, xP) == e(R, P)
  bench("Pairing (Miller loop + Final Exponentiation)", iters):
    ctx[] = ctxSave
    ctx[].blst_pairing_commit()                 # Miller loop
    discard ctx[].blst_pairing_finalVerify(nil) # Final Exponentiation

when isMainModule:
  benchScalarMultG1(1000)
  benchScalarMultG2(1000)
  benchEcAddG1(1000)
  benchEcAddG2(1000)

  benchPairing(1000)

  echo ""
  echo "On Broadwell CPUs (Intel 2015) or Ryzen CPUs (AMD 2017) or later support the \"ADX\" instructions dedicated to big integer arithmetics"
  echo "You might want to benchmark with --passC:-madx or --passC:\"-march=native\" to use them."
