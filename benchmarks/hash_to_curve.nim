# Nim-BLSCurve
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  # Internals
  ../blst/blst_lowlevel,
  # Bench
  ./bench_templates

# ############################################################
#
#             Benchmark of Hash to G2 of BLS12-381
#           Using Draft #5 of IETF spec (HKDF-based)
#
# ############################################################
# https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-05#appendix-C.3

proc benchHashToG2*(iters: int) =
  const dst = "BLS_SIG_BLS12381G2-SHA256-SSWU-RO_POP_"
  let msg = "msg"

  var point: blst_p2

  bench("Hash to G2 (Draft #8)", iters):
    point.blst_hash_to_g2(msg, dst, aug = "")

when isMainModule:
  benchHashToG2(1000)
  echo ""
  echo "On Broadwell CPUs (Intel 2015) or Ryzen CPUs (AMD 2017) or later support the \"ADX\" instructions dedicated to big integer arithmetics"
  echo "You might want to benchmark with --passC:-madx or --passC:\"-march=native\" to use them."
