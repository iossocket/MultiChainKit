//
//  StarknetSigner.swift
//  StarknetKit
//
//  StarkNet signer conforming to Signer + PrivateKeySigner protocols.
//

import BigInt
import Foundation
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

  // MARK: - MnemonicSigner

  /// Derive a Stark private key from a BIP39 mnemonic via BIP32 + grind.
  public init(mnemonic: String, path: DerivationPath) throws {
    guard BIP39.validate(mnemonic) else {
      throw SignerError.invalidMnemonic
    }
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: path)
    try self.init(privateKey: key)
  }
}
