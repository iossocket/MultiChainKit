//
//  StarknetSignerTests.swift
//  StarknetKitTests
//
//  Tests for Starknet chain definition, signature, and signer.
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

// Known test vectors from starknet.swift
private let testPrivateKey = Felt(
  "0x4070e7abfa479cf8a30d38895e93800a88862c4a65aa00e2b11495998818046")!
private let testPublicKey = Felt(
  "0x7697f8f9a4c3e2b1efd882294462fda2ca9c439d02a3a04cf0a0cdb627f11ee")!

@Suite("Felt ShortString Tests")
struct FeltShortStringTests {

  @Test("fromShortString: SN_MAIN")
  func shortStringMain() {
    let felt = Felt.fromShortString("SN_MAIN")
    #expect(felt == Felt("0x534e5f4d41494e")!)
  }

  @Test("fromShortString: SN_SEPOLIA")
  func shortStringSepolia() {
    let felt = Felt.fromShortString("SN_SEPOLIA")
    #expect(felt == Felt("0x534e5f5345504f4c4941")!)
  }

  @Test("toShortString roundtrip")
  func shortStringRoundtrip() {
    let original = "SN_MAIN"
    let felt = Felt.fromShortString(original)
    #expect(felt.toShortString() == original)
  }

  @Test("fromShortString: empty string is zero")
  func shortStringEmpty() {
    let felt = Felt.fromShortString("")
    #expect(felt == .zero)
  }

  @Test("fromShortString: single char")
  func shortStringSingleChar() {
    let felt = Felt.fromShortString("A")
    #expect(felt == Felt(65))
  }
}

@Suite("Starknet Chain Tests")
struct StarknetChainTests {

  @Test("Mainnet chain ID")
  func mainnetChainId() {
    let mainnet = Starknet.mainnet
    #expect(mainnet.chainId == Felt.fromShortString("SN_MAIN"))
    #expect(mainnet.name == "StarkNet Mainnet")
    #expect(!mainnet.isTestnet)
  }

  @Test("Sepolia chain ID")
  func sepoliaChainId() {
    let sepolia = Starknet.sepolia
    #expect(sepolia.chainId == Felt.fromShortString("SN_SEPOLIA"))
    #expect(sepolia.name == "StarkNet Sepolia")
    #expect(sepolia.isTestnet)
  }

  @Test("Chain id string format")
  func chainIdString() {
    let mainnet = Starknet.mainnet
    #expect(mainnet.id == "starknet:\(mainnet.chainId.hexString)")
  }

  @Test("Equatable: same chain ID")
  func equatable() {
    let a = Starknet.mainnet
    let b = Starknet(
      chainId: Felt.fromShortString("SN_MAIN"),
      name: "Different Name",
      rpcURL: URL(string: "https://example.com")!,
      isTestnet: false
    )
    #expect(a == b)
  }

  @Test("Equatable: different chain ID")
  func notEqual() {
    #expect(Starknet.mainnet != Starknet.sepolia)
  }

  @Test("Hashable: same chain ID same hash")
  func hashable() {
    let set: Set<Starknet> = [Starknet.mainnet, Starknet.mainnet]
    #expect(set.count == 1)
  }
}

@Suite("StarknetSignature Tests")
struct StarknetSignatureTests {

  @Test("rawData is r + s (64 bytes)")
  func rawData() {
    let sig = StarknetSignature(r: Felt(1), s: Felt(2))
    #expect(sig.rawData.count == 64)
    #expect(Felt(sig.rawData.prefix(32)) == Felt(1))
    #expect(Felt(sig.rawData.suffix(32)) == Felt(2))
  }

  @Test("feltArray returns [r, s]")
  func feltArray() {
    let sig = StarknetSignature(r: Felt(10), s: Felt(20))
    #expect(sig.feltArray == [Felt(10), Felt(20)])
  }

  @Test("Equatable")
  func equatable() {
    let a = StarknetSignature(r: Felt(1), s: Felt(2))
    let b = StarknetSignature(r: Felt(1), s: Felt(2))
    let c = StarknetSignature(r: Felt(1), s: Felt(3))
    #expect(a == b)
    #expect(a != c)
  }
}

@Suite("StarknetSigner Tests")
struct StarknetSignerTests {

  @Test("Init from Felt private key")
  func initFromFelt() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    #expect(signer.publicKeyFelt == testPublicKey)
  }

  @Test("Init from Data private key")
  func initFromData() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey.bigEndianData)
    #expect(signer.publicKeyFelt == testPublicKey)
  }

  @Test("publicKey returns 32-byte Data")
  func publicKeyData() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pk = signer.publicKey
    #expect(pk != nil)
    #expect(pk!.count == 32)
  }

  @Test("Init with zero private key throws")
  func initZeroThrows() {
    #expect(throws: (any Error).self) {
      _ = try StarknetSigner(privateKey: Felt.zero)
    }
  }

  @Test("Init with zero Data throws")
  func initZeroDataThrows() {
    #expect(throws: (any Error).self) {
      _ = try StarknetSigner(privateKey: Data(repeating: 0, count: 32))
    }
  }

  @Test("Sign and verify")
  func signAndVerify() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let hash = Felt("0x06fea80189363a786037ed3e7ba546dad0ef7de49fccae0e31eb658b7dd4ea76")!

    let signature = try signer.sign(feltHash: hash)
    #expect(signature.r != .zero)
    #expect(signature.s != .zero)

    // Verify with StarkCurve
    let valid = try StarkCurve.verify(
      publicKey: testPublicKey,
      hash: hash,
      r: signature.r,
      s: signature.s
    )
    #expect(valid)
  }

  @Test("sign(hash:) accepts 32-byte Data")
  func signHashData() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let hashData = Felt("0x06fea80189363a786037ed3e7ba546dad0ef7de49fccae0e31eb658b7dd4ea76")!
      .bigEndianData

    let signature = try signer.sign(hash: hashData)
    #expect(signature.r != .zero)
    #expect(signature.s != .zero)
  }

  @Test("Deterministic signing: same hash produces same signature")
  func deterministicSigning() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let hash = Felt("0x052fc40e34aee86948cd47e1a0096fa67df8410f81421f314a1eb18102251a82")!

    let sig1 = try signer.sign(feltHash: hash)
    let sig2 = try signer.sign(feltHash: hash)
    #expect(sig1 == sig2)
  }
}
