//
//  EthereumSigner.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public struct EthereumSigner: Signer, PrivateKeySigner, MnemonicSigner, Sendable {
  public typealias C = EvmChain

  private let privateKey: Data

  // MARK: - Signer

  public var publicKey: Data? {
    try? Secp256k1.publicKey(from: privateKey)
  }

  public var address: EthereumAddress? {
    try? Secp256k1.ethereumAddress(fromPrivateKey: privateKey)
  }

  public func sign(hash: Data) throws -> EthereumSignature {
    do {
      let sigData = try Secp256k1.sign(message: hash, privateKey: privateKey)
      return try EthereumSignature(data: sigData)
    } catch {
      throw SignerError.signingFailed("\(error)")
    }
  }

  // MARK: - PrivateKeySigner

  public init(privateKey: Data) throws {
    guard (try? Secp256k1.publicKey(from: privateKey)) != nil else {
      throw SignerError.invalidPrivateKey
    }
    self.privateKey = privateKey
  }

  // MARK: - MnemonicSigner

  public init(mnemonic: String, path: DerivationPath) throws {
    try self.init(mnemonic: mnemonic, path: path, password: "")
  }

  public init(mnemonic: String, path: DerivationPath, password: String) throws {
    guard BIP39.validate(mnemonic) else {
      throw SignerError.invalidMnemonic
    }
    let seed = try BIP39.seed(from: mnemonic, password: password)
    let key = try BIP32.derive(seed: seed, path: path)
    self.privateKey = key.privateKey
  }

  // MARK: - Personal Message (EIP-191)

  public func signPersonalMessage(_ message: String) throws -> EthereumSignature {
    guard let data = message.data(using: .utf8) else {
      throw SignerError.signingFailed("invalid UTF-8")
    }
    return try signPersonalMessage(data)
  }

  public func signPersonalMessage(_ data: Data) throws -> EthereumSignature {
    let prefix = "\u{19}Ethereum Signed Message:\n\(data.count)"
    var prefixed = Data(prefix.utf8)
    prefixed.append(data)
    return try sign(hash: Keccak256.hash(prefixed))
  }

  // MARK: - EIP-712 Typed Data

  public func signTypedData(_ typedData: EIP712TypedData) throws -> EthereumSignature {
    let hash = try typedData.signHash()
    return try sign(hash: hash)
  }
}
