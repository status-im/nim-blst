# ------------------------------------------------------------------------------------------------
# Manual edits
import std/[strutils, os]

const headerPath = currentSourcePath.rsplit(DirSep, 1)[0]/".."/"vendor"/"blst"/"bindings"/"blst.h"

{.pragma: impblstHdr,
   header: headerPath.}

type CTbool* = distinct cint

# ------------------------------------------------------------------------------------------------
# Generated @ 2020-07-11T15:22:46+02:00
# Command line:
#   /.../.nimble/pkgs/nimterop-0.6.2/nimterop/toast -n -p --prefix=_ --typemap=bool=int32 -G=@\bin\b=src -G=@\bout\b=dst -o=blst/blst_abi_candidate.nim vendor/blst/bindings/blst.h

# const 'bool' has unsupported value '_Bool'
{.push hint[ConvFromXtoItselfNotNeeded]: off.}
import macros

macro defineEnum(typ: untyped): untyped =
  result = newNimNode(nnkStmtList)

  # Enum mapped to distinct cint
  result.add quote do:
    type `typ`* = distinct cint

  for i in ["+", "-", "*", "div", "mod", "shl", "shr", "or", "and", "xor", "<", "<=", "==", ">", ">="]:
    let
      ni = newIdentNode(i)
      typout = if i[0] in "<=>": newIdentNode("bool") else: typ # comparisons return bool
    if i[0] == '>': # cannot borrow `>` and `>=` from templates
      let
        nopp = if i.len == 2: newIdentNode("<=") else: newIdentNode("<")
      result.add quote do:
        proc `ni`*(x: `typ`, y: cint): `typout` = `nopp`(y, x)
        proc `ni`*(x: cint, y: `typ`): `typout` = `nopp`(y, x)
        proc `ni`*(x, y: `typ`): `typout` = `nopp`(y, x)
    else:
      result.add quote do:
        proc `ni`*(x: `typ`, y: cint): `typout` {.borrow.}
        proc `ni`*(x: cint, y: `typ`): `typout` {.borrow.}
        proc `ni`*(x, y: `typ`): `typout` {.borrow.}
    result.add quote do:
      proc `ni`*(x: `typ`, y: int): `typout` = `ni`(x, y.cint)
      proc `ni`*(x: int, y: `typ`): `typout` = `ni`(x.cint, y)

  let
    divop = newIdentNode("/")   # `/`()
    dlrop = newIdentNode("$")   # `$`()
    notop = newIdentNode("not") # `not`()
  result.add quote do:
    proc `divop`*(x, y: `typ`): `typ` = `typ`((x.float / y.float).cint)
    proc `divop`*(x: `typ`, y: cint): `typ` = `divop`(x, `typ`(y))
    proc `divop`*(x: cint, y: `typ`): `typ` = `divop`(`typ`(x), y)
    proc `divop`*(x: `typ`, y: int): `typ` = `divop`(x, y.cint)
    proc `divop`*(x: int, y: `typ`): `typ` = `divop`(x.cint, y)

    proc `dlrop`*(x: `typ`): string {.borrow.}
    proc `notop`*(x: `typ`): `typ` {.borrow.}

defineEnum(BLST_ERROR)
const
  BLST_SUCCESS* = (0).BLST_ERROR
  BLST_BAD_ENCODING* = (BLST_SUCCESS + 1).BLST_ERROR
  BLST_POINT_NOT_ON_CURVE* = (BLST_BAD_ENCODING + 1).BLST_ERROR
  BLST_POINT_NOT_IN_GROUP* = (BLST_POINT_NOT_ON_CURVE + 1).BLST_ERROR
  BLST_AGGR_TYPE_MISMATCH* = (BLST_POINT_NOT_IN_GROUP + 1).BLST_ERROR
  BLST_VERIFY_FAIL* = (BLST_AGGR_TYPE_MISMATCH + 1).BLST_ERROR
type
  byte* {.importc, impblstHdr.} = uint8
  limb_t* {.importc, impblstHdr.} = uint64
  blst_scalar* {.bycopy, importc, impblstHdr.} = object
    l*: array[typeof(256)(typeof(256)(256 / typeof(256)(8)) /
        typeof(256)(sizeof((limb_t)))), limb_t]

  blst_fr* {.bycopy, importc, impblstHdr.} = object
    l*: array[typeof(256)(typeof(256)(256 / typeof(256)(8)) /
        typeof(256)(sizeof((limb_t)))), limb_t]

  blst_fp* {.bycopy, importc, impblstHdr.} = object ## ```
                                              ##   0 is "real" part, 1 is "imaginary"
                                              ## ```
    l*: array[typeof(384)(typeof(384)(384 / typeof(384)(8)) /
        typeof(384)(sizeof((limb_t)))), limb_t]

  blst_fp2* {.bycopy, importc, impblstHdr.} = object ## ```
                                               ##   0 is "real" part, 1 is "imaginary"
                                               ## ```
    fp*: array[2, blst_fp]

  blst_fp6* {.bycopy, importc, impblstHdr.} = object
    fp2*: array[3, blst_fp2]

  blst_fp12* {.bycopy, importc, impblstHdr.} = object
    fp6*: array[2, blst_fp6]

  blst_p1* {.bycopy, importc, impblstHdr.} = object ## ```
                                              ##   BLS12-381-specifc point operations.
                                              ## ```
    x*: blst_fp
    y*: blst_fp
    z*: blst_fp

  blst_p1_affine* {.bycopy, importc, impblstHdr.} = object
    x*: blst_fp
    y*: blst_fp

  blst_p2* {.bycopy, importc, impblstHdr.} = object
    x*: blst_fp2
    y*: blst_fp2
    z*: blst_fp2

  blst_p2_affine* {.bycopy, importc, impblstHdr.} = object
    x*: blst_fp2
    y*: blst_fp2

  blst_pairing* {.incompleteStruct, importc, impblstHdr.} = object
var
  BLS12_381_G1* {.importc, impblstHdr.}: blst_p1_affine
  BLS12_381_NEG_G1* {.importc, impblstHdr.}: blst_p1_affine
  BLS12_381_G2* {.importc, impblstHdr.}: blst_p2_affine
  BLS12_381_NEG_G2* {.importc, impblstHdr.}: blst_p2_affine
proc blst_scalar_from_uint32*(ret: ptr blst_scalar; a: array[8, uint32]) {.importc,
    cdecl, impblstHdr.}
proc blst_uint32_from_scalar*(ret: array[8, uint32]; a: ptr blst_scalar) {.importc,
    cdecl, impblstHdr.}
proc blst_scalar_from_uint64*(ret: ptr blst_scalar; a: array[4, uint64]) {.importc,
    cdecl, impblstHdr.}
proc blst_uint64_from_scalar*(ret: array[4, uint64]; a: ptr blst_scalar) {.importc,
    cdecl, impblstHdr.}
proc blst_scalar_from_bendian*(ret: ptr blst_scalar; a: array[32, byte]) {.importc,
    cdecl, impblstHdr.}
proc blst_bendian_from_scalar*(ret: array[32, byte]; a: ptr blst_scalar) {.importc,
    cdecl, impblstHdr.}
proc blst_scalar_from_lendian*(ret: ptr blst_scalar; a: array[32, byte]) {.importc,
    cdecl, impblstHdr.}
proc blst_lendian_from_scalar*(ret: array[32, byte]; a: ptr blst_scalar) {.importc,
    cdecl, impblstHdr.}
proc blst_scalar_fr_check*(a: ptr blst_scalar): CTBool {.importc, cdecl, impblstHdr.}
proc blst_fr_add*(ret: ptr blst_fr; a: ptr blst_fr; b: ptr blst_fr) {.importc, cdecl,
    impblstHdr.}
  ## ```
  ##   BLS12-381-specifc Fr operations.
  ## ```
proc blst_fr_sub*(ret: ptr blst_fr; a: ptr blst_fr; b: ptr blst_fr) {.importc, cdecl,
    impblstHdr.}
proc blst_fr_mul_by_3*(ret: ptr blst_fr; a: ptr blst_fr) {.importc, cdecl, impblstHdr.}
proc blst_fr_lshift*(ret: ptr blst_fr; a: ptr blst_fr; count: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fr_rshift*(ret: ptr blst_fr; a: ptr blst_fr; count: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fr_mul*(ret: ptr blst_fr; a: ptr blst_fr; b: ptr blst_fr) {.importc, cdecl,
    impblstHdr.}
proc blst_fr_sqr*(ret: ptr blst_fr; a: ptr blst_fr) {.importc, cdecl, impblstHdr.}
proc blst_fr_cneg*(ret: ptr blst_fr; a: ptr blst_fr; flag: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fr_to*(ret: ptr blst_fr; a: ptr blst_fr) {.importc, cdecl, impblstHdr.}
proc blst_fr_from*(ret: ptr blst_fr; a: ptr blst_fr) {.importc, cdecl, impblstHdr.}
proc blst_fp_add*(ret: ptr blst_fp; a: ptr blst_fp; b: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
  ## ```
  ##   BLS12-381-specifc Fp operations.
  ## ```
proc blst_fp_sub*(ret: ptr blst_fp; a: ptr blst_fp; b: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_mul_by_3*(ret: ptr blst_fp; a: ptr blst_fp) {.importc, cdecl, impblstHdr.}
proc blst_fp_mul_by_8*(ret: ptr blst_fp; a: ptr blst_fp) {.importc, cdecl, impblstHdr.}
proc blst_fp_lshift*(ret: ptr blst_fp; a: ptr blst_fp; count: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_mul*(ret: ptr blst_fp; a: ptr blst_fp; b: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_sqr*(ret: ptr blst_fp; a: ptr blst_fp) {.importc, cdecl, impblstHdr.}
proc blst_fp_cneg*(ret: ptr blst_fp; a: ptr blst_fp; flag: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_eucl_inverse*(ret: ptr blst_fp; a: ptr blst_fp) {.importc, cdecl, impblstHdr.}
proc blst_fp_to*(ret: ptr blst_fp; a: ptr blst_fp) {.importc, cdecl, impblstHdr.}
proc blst_fp_from*(ret: ptr blst_fp; a: ptr blst_fp) {.importc, cdecl, impblstHdr.}
proc blst_fp_from_uint32*(ret: ptr blst_fp; a: array[12, uint32]) {.importc, cdecl,
    impblstHdr.}
proc blst_uint32_from_fp*(ret: array[12, uint32]; a: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_from_uint64*(ret: ptr blst_fp; a: array[6, uint64]) {.importc, cdecl,
    impblstHdr.}
proc blst_uint64_from_fp*(ret: array[6, uint64]; a: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_from_bendian*(ret: ptr blst_fp; a: array[48, byte]) {.importc, cdecl,
    impblstHdr.}
proc blst_bendian_from_fp*(ret: array[48, byte]; a: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_fp_from_lendian*(ret: ptr blst_fp; a: array[48, byte]) {.importc, cdecl,
    impblstHdr.}
proc blst_lendian_from_fp*(ret: array[48, byte]; a: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_fp2_add*(ret: ptr blst_fp2; a: ptr blst_fp2; b: ptr blst_fp2) {.importc, cdecl,
    impblstHdr.}
  ## ```
  ##   BLS12-381-specifc Fp2 operations.
  ## ```
proc blst_fp2_sub*(ret: ptr blst_fp2; a: ptr blst_fp2; b: ptr blst_fp2) {.importc, cdecl,
    impblstHdr.}
proc blst_fp2_mul_by_3*(ret: ptr blst_fp2; a: ptr blst_fp2) {.importc, cdecl, impblstHdr.}
proc blst_fp2_mul_by_8*(ret: ptr blst_fp2; a: ptr blst_fp2) {.importc, cdecl, impblstHdr.}
proc blst_fp2_lshift*(ret: ptr blst_fp2; a: ptr blst_fp2; count: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fp2_mul*(ret: ptr blst_fp2; a: ptr blst_fp2; b: ptr blst_fp2) {.importc, cdecl,
    impblstHdr.}
proc blst_fp2_sqr*(ret: ptr blst_fp2; a: ptr blst_fp2) {.importc, cdecl, impblstHdr.}
proc blst_fp2_cneg*(ret: ptr blst_fp2; a: ptr blst_fp2; flag: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_fp12_sqr*(ret: ptr blst_fp12; a: ptr blst_fp12) {.importc, cdecl, impblstHdr.}
  ## ```
  ##   BLS12-381-specifc Fp12 operations.
  ## ```
proc blst_fp12_cyclotomic_sqr*(ret: ptr blst_fp12; a: ptr blst_fp12) {.importc, cdecl,
    impblstHdr.}
proc blst_fp12_mul*(ret: ptr blst_fp12; a: ptr blst_fp12; b: ptr blst_fp12) {.importc,
    cdecl, impblstHdr.}
proc blst_fp12_mul_by_xy00z0*(ret: ptr blst_fp12; a: ptr blst_fp12;
                             xy00z0: ptr blst_fp6) {.importc, cdecl, impblstHdr.}
proc blst_fp12_conjugate*(a: ptr blst_fp12) {.importc, cdecl, impblstHdr.}
proc blst_fp12_inverse*(ret: ptr blst_fp12; a: ptr blst_fp12) {.importc, cdecl,
    impblstHdr.}
  ## ```
  ##   caveat lector! |n| has to be non-zero and not more than 3!
  ## ```
proc blst_fp12_frobenius_map*(ret: ptr blst_fp12; a: ptr blst_fp12; n: uint) {.importc,
    cdecl, impblstHdr.}
  ## ```
  ##   caveat lector! |n| has to be non-zero and not more than 3!
  ## ```
proc blst_fp12_is_equal*(a: ptr blst_fp12; b: ptr blst_fp12): CTBool {.importc, cdecl,
    impblstHdr.}
proc blst_fp12_is_one*(a: ptr blst_fp12): CTBool {.importc, cdecl, impblstHdr.}
proc blst_p1_add*(dst: ptr blst_p1; a: ptr blst_p1; b: ptr blst_p1) {.importc, cdecl,
    impblstHdr.}
proc blst_p1_add_or_double*(dst: ptr blst_p1; a: ptr blst_p1; b: ptr blst_p1) {.importc,
    cdecl, impblstHdr.}
proc blst_p1_add_affine*(dst: ptr blst_p1; a: ptr blst_p1; b: ptr blst_p1_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_p1_add_or_double_affine*(dst: ptr blst_p1; a: ptr blst_p1;
                                  b: ptr blst_p1_affine) {.importc, cdecl, impblstHdr.}
proc blst_p1_double*(dst: ptr blst_p1; a: ptr blst_p1) {.importc, cdecl, impblstHdr.}
proc blst_p1_mult_w5*(dst: ptr blst_p1; p: ptr blst_p1; scalar: ptr blst_scalar;
                     nbits: uint) {.importc, cdecl, impblstHdr.}
proc blst_p1_cneg*(p: ptr blst_p1; cbit: uint) {.importc, cdecl, impblstHdr.}
proc blst_p1_to_affine*(dst: ptr blst_p1_affine; src: ptr blst_p1) {.importc, cdecl,
    impblstHdr.}
proc blst_p1_from_affine*(dst: ptr blst_p1; src: ptr blst_p1_affine) {.importc, cdecl,
    impblstHdr.}
proc blst_p1_affine_on_curve*(p: ptr blst_p1_affine): CTBool {.importc, cdecl, impblstHdr.}
proc blst_p1_affine_in_g1*(p: ptr blst_p1_affine): CTBool {.importc, cdecl, impblstHdr.}
proc blst_p1_affine_is_equal*(a: ptr blst_p1_affine; b: ptr blst_p1_affine): CTBool {.
    importc, cdecl, impblstHdr.}
proc blst_p2_add*(dst: ptr blst_p2; a: ptr blst_p2; b: ptr blst_p2) {.importc, cdecl,
    impblstHdr.}
proc blst_p2_add_or_double*(dst: ptr blst_p2; a: ptr blst_p2; b: ptr blst_p2) {.importc,
    cdecl, impblstHdr.}
proc blst_p2_add_affine*(dst: ptr blst_p2; a: ptr blst_p2; b: ptr blst_p2_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_p2_add_or_double_affine*(dst: ptr blst_p2; a: ptr blst_p2;
                                  b: ptr blst_p2_affine) {.importc, cdecl, impblstHdr.}
proc blst_p2_double*(dst: ptr blst_p2; a: ptr blst_p2) {.importc, cdecl, impblstHdr.}
proc blst_p2_mult_w5*(dst: ptr blst_p2; p: ptr blst_p2; scalar: ptr blst_scalar;
                     nbits: uint) {.importc, cdecl, impblstHdr.}
proc blst_p2_cneg*(p: ptr blst_p2; cbit: uint) {.importc, cdecl, impblstHdr.}
proc blst_p2_to_affine*(dst: ptr blst_p2_affine; src: ptr blst_p2) {.importc, cdecl,
    impblstHdr.}
proc blst_p2_from_affine*(dst: ptr blst_p2; src: ptr blst_p2_affine) {.importc, cdecl,
    impblstHdr.}
proc blst_p2_affine_on_curve*(p: ptr blst_p2_affine): CTBool {.importc, cdecl, impblstHdr.}
proc blst_p2_affine_in_g2*(p: ptr blst_p2_affine): CTBool {.importc, cdecl, impblstHdr.}
proc blst_p2_affine_is_equal*(a: ptr blst_p2_affine; b: ptr blst_p2_affine): CTBool {.
    importc, cdecl, impblstHdr.}
proc blst_map_to_g1*(dst: ptr blst_p1; u: ptr blst_fp; v: ptr blst_fp) {.importc, cdecl,
    impblstHdr.}
proc blst_map_to_g2*(dst: ptr blst_p2; u: ptr blst_fp2; v: ptr blst_fp2) {.importc, cdecl,
    impblstHdr.}
proc blst_encode_to_g1*(dst: ptr blst_p1; msg: ptr byte; msg_len: uint; DST: ptr byte;
                       DST_len: uint; aug: ptr byte; aug_len: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_hash_to_g1*(dst: ptr blst_p1; msg: ptr byte; msg_len: uint; DST: ptr byte;
                     DST_len: uint; aug: ptr byte; aug_len: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_encode_to_g2*(dst: ptr blst_p2; msg: ptr byte; msg_len: uint; DST: ptr byte;
                       DST_len: uint; aug: ptr byte; aug_len: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_hash_to_g2*(dst: ptr blst_p2; msg: ptr byte; msg_len: uint; DST: ptr byte;
                     DST_len: uint; aug: ptr byte; aug_len: uint) {.importc, cdecl,
    impblstHdr.}
proc blst_p1_serialize*(dst: array[96, byte]; src: ptr blst_p1) {.importc, cdecl,
    impblstHdr.}
  ## ```
  ##   Zcash-compatible serialization/deserialization.
  ## ```
proc blst_p1_compress*(dst: array[48, byte]; src: ptr blst_p1) {.importc, cdecl,
    impblstHdr.}
proc blst_p1_affine_serialize*(dst: array[96, byte]; src: ptr blst_p1_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_p1_affine_compress*(dst: array[48, byte]; src: ptr blst_p1_affine) {.importc,
    cdecl, impblstHdr.}
proc blst_p1_uncompress*(dst: ptr blst_p1_affine; src: array[48, byte]): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_p1_deserialize*(dst: ptr blst_p1_affine; src: array[96, byte]): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_p2_serialize*(dst: array[192, byte]; src: ptr blst_p2) {.importc, cdecl,
    impblstHdr.}
proc blst_p2_compress*(dst: array[96, byte]; src: ptr blst_p2) {.importc, cdecl,
    impblstHdr.}
proc blst_p2_affine_serialize*(dst: array[192, byte]; src: ptr blst_p2_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_p2_affine_compress*(dst: array[96, byte]; src: ptr blst_p2_affine) {.importc,
    cdecl, impblstHdr.}
proc blst_p2_uncompress*(dst: ptr blst_p2_affine; src: array[96, byte]): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_p2_deserialize*(dst: ptr blst_p2_affine; src: array[192, byte]): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_keygen*(out_SK: ptr blst_scalar; IKM: ptr byte; IKM_len: uint; info: ptr byte;
                 info_len: uint) {.importc, cdecl, impblstHdr.}
  ## ```
  ##   Specification defines two variants, 'minimal-signature-size' and
  ##    'minimal-pubkey-size'. To unify appearance we choose to distinguish
  ##    them by suffix referring to the public key type, more specifically
  ##    _pk_in_g1 corresponds to 'minimal-pubkey-size' and _pk_in_g2 - to
  ##    'minimal-signature-size'. It might appear a bit counterintuitive
  ##    in sign call, but no matter how you twist it, something is bound to
  ##    turn a little odd.
  ##
  ##
  ##    Secret-key operations.
  ## ```
proc blst_sk_to_pk_in_g1*(out_pk: ptr blst_p1; SK: ptr blst_scalar) {.importc, cdecl,
    impblstHdr.}
proc blst_sign_pk_in_g1*(out_sig: ptr blst_p2; hash: ptr blst_p2; SK: ptr blst_scalar) {.
    importc, cdecl, impblstHdr.}
proc blst_sk_to_pk_in_g2*(out_pk: ptr blst_p2; SK: ptr blst_scalar) {.importc, cdecl,
    impblstHdr.}
proc blst_sign_pk_in_g2*(out_sig: ptr blst_p1; hash: ptr blst_p1; SK: ptr blst_scalar) {.
    importc, cdecl, impblstHdr.}
proc blst_miller_loop*(ret: ptr blst_fp12; Q: ptr blst_p2_affine; P: ptr blst_p1_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_final_exp*(ret: ptr blst_fp12; f: ptr blst_fp12) {.importc, cdecl, impblstHdr.}
proc blst_precompute_lines*(Qlines: array[68, blst_fp6]; Q: ptr blst_p2_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_miller_loop_lines*(ret: ptr blst_fp12; Qlines: array[68, blst_fp6];
                            P: ptr blst_p1_affine) {.importc, cdecl, impblstHdr.}
proc blst_pairing_sizeof*(): uint {.importc, cdecl, impblstHdr.}
proc blst_pairing_init*(new_ctx: ptr blst_pairing) {.importc, cdecl, impblstHdr.}
proc blst_pairing_commit*(ctx: ptr blst_pairing) {.importc, cdecl, impblstHdr.}
proc blst_pairing_aggregate_pk_in_g2*(ctx: ptr blst_pairing; PK: ptr blst_p2_affine;
                                     signature: ptr blst_p1_affine;
                                     hash_or_encode: CTBool; msg: ptr byte;
                                     msg_len: uint; DST: ptr byte; DST_len: uint;
                                     aug: ptr byte; aug_len: uint): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_pairing_mul_n_aggregate_pk_in_g2*(ctx: ptr blst_pairing;
    PK: ptr blst_p2_affine; sig: ptr blst_p1_affine; hash: ptr blst_p1_affine;
    scalar: ptr limb_t; nbits: uint): BLST_ERROR {.importc, cdecl, impblstHdr.}
proc blst_pairing_aggregate_pk_in_g1*(ctx: ptr blst_pairing; PK: ptr blst_p1_affine;
                                     signature: ptr blst_p2_affine;
                                     hash_or_encode: CTBool; msg: ptr byte;
                                     msg_len: uint; DST: ptr byte; DST_len: uint;
                                     aug: ptr byte; aug_len: uint): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_pairing_mul_n_aggregate_pk_in_g1*(ctx: ptr blst_pairing;
    PK: ptr blst_p1_affine; sig: ptr blst_p2_affine; hash: ptr blst_p2_affine;
    scalar: ptr limb_t; nbits: uint): BLST_ERROR {.importc, cdecl, impblstHdr.}
proc blst_pairing_merge*(ctx: ptr blst_pairing; ctx1: ptr blst_pairing): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_pairing_finalverify*(ctx: ptr blst_pairing; gtsig: ptr blst_fp12): CTBool {.
    importc, cdecl, impblstHdr.}
proc blst_aggregate_in_g1*(dst: ptr blst_p1; src: ptr blst_p1; zwire: ptr byte): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
  ## ```
  ##   Customarily applications aggregate signatures separately.
  ##    In which case application would have to pass NULLs for |signature|
  ##    to blst_pairing_aggregate calls and pass aggregated signature
  ##    collected with these calls to blst_pairing_finalverify. Inputs are
  ##    Zcash-compatible "straight-from-wire" byte vectors, compressed or
  ##    not.
  ## ```
proc blst_aggregate_in_g2*(dst: ptr blst_p2; src: ptr blst_p2; zwire: ptr byte): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
proc blst_aggregated_in_g1*(dst: ptr blst_fp12; signature: ptr blst_p1_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_aggregated_in_g2*(dst: ptr blst_fp12; signature: ptr blst_p2_affine) {.
    importc, cdecl, impblstHdr.}
proc blst_core_verify_pk_in_g1*(pk: ptr blst_p1_affine;
                               signature: ptr blst_p2_affine; hash_or_encode: CTBool;
                               msg: ptr byte; msg_len: uint; DST: ptr byte;
                               DST_len: uint; aug: ptr byte; aug_len: uint): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
  ## ```
  ##   "One-shot" CoreVerify entry points.
  ## ```
proc blst_core_verify_pk_in_g2*(pk: ptr blst_p2_affine;
                               signature: ptr blst_p1_affine; hash_or_encode: CTBool;
                               msg: ptr byte; msg_len: uint; DST: ptr byte;
                               DST_len: uint; aug: ptr byte; aug_len: uint): BLST_ERROR {.
    importc, cdecl, impblstHdr.}
{.pop.}
