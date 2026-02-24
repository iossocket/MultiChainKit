//
//  StarkCurve.swift
//  StarknetKit
//

import BigInt
import Foundation
import MultiChainCore
import StarknetCrypto

public enum StarkCurveError: Error, Sendable {
  case invalidPrivateKey
  case invalidPublicKey
  case signingFailed
  case verifyFailed
  case deserializationError
}

public struct StarknetSignature: ChainSignature, Sendable, Equatable {
  public let r: Felt
  public let s: Felt

  public var feltArray: [Felt] { [r, s] }

  public var rawData: Data {
    r.bigEndianData + s.bigEndianData
  }
}

public enum StarkCurve {

  /// Curve order N
  public static let curveOrder = BigUInt(
    "800000000000010FFFFFFFFFFFFFFFFB781126DCAE7B2321E66A241ADC64D2F", radix: 16)!

  // MARK: - Public Key

  /// Derive public key (x coordinate) from private key.
  public static func getPublicKey(privateKey: Felt) throws -> Felt {
    guard privateKey != .zero else {
      throw StarkCurveError.invalidPrivateKey
    }
    let result = try StarkSigner.publicKey(privateKey: privateKey.littleEndianData)
    return Felt(littleEndian: result)
  }

  // MARK: - Sign

  /// Sign a message hash with a private key (RFC 6979 deterministic k).
  public static func sign(privateKey: Felt, hash: Felt) throws -> StarknetSignature {
    guard privateKey != .zero else {
      throw StarkCurveError.invalidPrivateKey
    }
    let k = try StarkSigner.rfc6979Nonce(
      messageHash: hash.littleEndianData,
      privateKey: privateKey.littleEndianData,
      seed: nil
    )
    let (rData, sData) = try StarkSigner.sign(
      privateKey: privateKey.littleEndianData,
      hash: hash.littleEndianData,
      k: k
    )
    return StarknetSignature(r: Felt(littleEndian: rData), s: Felt(littleEndian: sData))
  }

  // MARK: - Verify

  /// Verify a signature against a public key and message hash.
  public static func verify(publicKey: Felt, hash: Felt, r: Felt, s: Felt) throws -> Bool {
    try StarkSigner.verify(
      publicKey: publicKey.littleEndianData,
      hash: hash.littleEndianData,
      r: r.littleEndianData,
      s: s.littleEndianData
    )
  }
}
