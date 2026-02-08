//
//  StarkCurveTests.swift
//  StarknetKitTests
//
//  Tests for StarkCurve ECDSA operations
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

private let testPrivateKey = Felt("0x4070e7abfa479cf8a30d38895e93800a88862c4a65aa00e2b11495998818046")!
private let testPublicKey = Felt("0x7697f8f9a4c3e2b1efd882294462fda2ca9c439d02a3a04cf0a0cdb627f11ee")!

@Suite("StarkCurve Tests")
struct StarkCurveTests {

  // MARK: - Public Key Derivation

  @Test("Derive public key from private key")
  func getPublicKey() throws {
    let result = try StarkCurve.getPublicKey(privateKey: testPrivateKey)
    #expect(result == testPublicKey)
  }

  @Test("Derive public key from zero private key throws")
  func getPublicKeyZeroThrows() {
    #expect(throws: (any Error).self) {
      _ = try StarkCurve.getPublicKey(privateKey: .zero)
    }
  }

  // MARK: - Signing

  @Test("Sign and verify message hash")
  func signAndVerify() throws {
    let privateKey = Felt("0x0139fe4d6f02e666e86a6f58e65060f115cd3c185bd9e98bd829636931458f79")!
    let publicKey = Felt("0x02c5dbad71c92a45cc4b40573ae661f8147869a91d57b8d9b8f48c8af7f83159")!
    let hash = Felt("0x06fea80189363a786037ed3e7ba546dad0ef7de49fccae0e31eb658b7dd4ea76")!

    let signature = try StarkCurve.sign(privateKey: privateKey, hash: hash)

    let expectedR = Felt("0x061ec782f76a66f6984efc3a1b6d152a124c701c00abdd2bf76641b4135c770f")!
    let expectedS = Felt("0x04e44e759cea02c23568bb4d8a09929bbca8768ab68270d50c18d214166ccd9a")!

    #expect(signature.r == expectedR)
    #expect(signature.s == expectedS)

    let valid = try StarkCurve.verify(publicKey: publicKey, hash: hash, r: signature.r, s: signature.s)
    #expect(valid)
  }

  // MARK: - Verification

  @Test("Verify known signature")
  func verifyKnownSignature() throws {
    let r = Felt("0x66f8955f5c4cbad5c21905ca2a968bc32a183e81069b851b7fc388eceaf57f1")!
    let s = Felt("0x13d5af50c934213f27a8cc5863aa304165aa886487fcc575fe6e1228879f9fe")!

    let valid = try StarkCurve.verify(publicKey: testPublicKey, hash: Felt(1), r: r, s: s)
    #expect(valid)
  }

  @Test("Verify with swapped r,s returns false")
  func verifySwappedRS() throws {
    let r = Felt("0x66f8955f5c4cbad5c21905ca2a968bc32a183e81069b851b7fc388eceaf57f1")!
    let s = Felt("0x13d5af50c934213f27a8cc5863aa304165aa886487fcc575fe6e1228879f9fe")!

    let invalid = try StarkCurve.verify(publicKey: testPublicKey, hash: Felt(1), r: s, s: r)
    #expect(!invalid)
  }
}
