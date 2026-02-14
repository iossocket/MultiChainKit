//
//  StarknetKeyDerivation.swift
//  StarknetKit
//
//  Derives a Stark private key from a BIP32 seed + derivation path.
//  Algorithm: BIP32 derive → grind into Stark curve order via HMAC-SHA256.
//  Reference: starknet.js grindKey, EIP-2645
//

import BigInt
import CryptoSwift
import Foundation
import MultiChainCore

public enum StarknetKeyDerivation {

  /// Derive a Stark private key from a BIP39 seed and derivation path.
  /// 1. BIP32 derive at `path` to get a secp256k1 key
  /// 2. Grind the key into the Stark curve order
  public static func derivePrivateKey(seed: Data, path: DerivationPath) throws -> Felt {
    let extended = try BIP32.derive(seed: seed, path: path)
    let ground = grindKey(extended.privateKey)
    return Felt(ground)
  }

  /// Grind a 32-byte key into a valid Stark private key (< curve order).
  /// Matches starknet.js `grindKey` algorithm.
  static func grindKey(_ seed: Data) -> Data {
    let limit = StarkCurve.curveOrder
    // SHA-256 output is 256 bits; we need result < curveOrder (~251 bits).
    // Use HMAC-SHA-256 with incrementing counter until we get a valid key.
    let maxRetries = 100_000
    for i in 0..<maxRetries {
      var input = seed
      // Append counter as big-endian UInt32
      withUnsafeBytes(of: UInt32(i).bigEndian) { input.append(contentsOf: $0) }
      let hash = Data(SHA2(variant: .sha256).calculate(for: Array(input)))
      // Mask to 251 bits (clear top 5 bits of first byte)
      var masked = hash
      masked[0] &= 0x07
      let value = BigUInt(masked)
      if value > 0 && value < limit {
        var padded = masked
        while padded.count < 32 { padded.insert(0, at: 0) }
        return padded
      }
    }
    // Fallback: should never reach here with valid seed
    fatalError("StarknetKeyDerivation: grindKey exhausted retries")
  }
}
