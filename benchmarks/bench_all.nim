import
  ./bls12381_curve,
  ./hash_to_curve

benchScalarMultG1(1000)
benchScalarMultG2(1000)
benchEcAddG1(1000)
benchEcAddG2(1000)

benchPairing(1000)

benchHashToG2(1000)

echo ""
echo "On Broadwell CPUs (Intel 2015) or Ryzen CPUs (AMD 2017) or later support the \"ADX\" instructions dedicated to big integer arithmetics"
echo "You might want to benchmark with --passC:-madx or --passC:\"-march=native\" to use them."
