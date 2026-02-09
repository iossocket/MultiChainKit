//
//  StarknetSigner.swift
//  StarknetKit
//
//  StarkNet signer conforming to Signer + PrivateKeySigner protocols.
//

import Foundation
import BigInt
import MultiChainCore

public struct StarknetSigner: Signer, PrivateKeySigner, Sendable {
  public typealias C = Starknet

  private let privateKey: Felt

  // MARK: - Signer

  public var publicKey: Data? {
    try? StarkCurve.getPublicKey(privateKey: privateKey).bigEndianData
  }

  public var address: StarknetAddress? {
    nil
  }

  public var publicKeyFelt: Felt? {
    guard let pubKey = publicKey else {
      return nil
    }
    return Felt(pubKey)
  }

  public func sign(hash: Data) throws -> StarknetSignature {
    try sign(feltHash: Felt(hash))
  }

  /// Sign a Felt message hash directly.
  public func sign(feltHash: Felt) throws -> StarknetSignature {
    try StarkCurve.sign(privateKey: privateKey, hash: feltHash)
  }

  // MARK: - PrivateKeySigner

  public init(privateKey: Data) throws {
    if BigInt(privateKey) == 0 {
      throw StarkCurveError.invalidPrivateKey
    }
    self.privateKey = Felt(privateKey)
  }

  /// Initialize from a Felt private key.
  public init(privateKey: Felt) throws {
    guard privateKey != .zero else {
      throw StarkCurveError.invalidPrivateKey
    }
    self.privateKey = privateKey
  }
}
