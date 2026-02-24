//
//  EthereumAccount.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public struct EthereumAccount: Account, Sendable, Equatable, Hashable {
  public typealias C = EvmChain

  public let address: EthereumAddress

  // MARK: - Init

  public init(address: EthereumAddress) {
    self.address = address
  }

  public init?(address: String) {
    guard let ethAddr = EthereumAddress(address) else {
      return nil
    }
    self.address = ethAddr
  }

  public init?(signer: EthereumSigner) {
    guard let address = signer.address else {
      return nil
    }
    self.address = address
  }

  public init(privateKey: Data) throws {
    let ethAddr = try Secp256k1.ethereumAddress(fromPrivateKey: privateKey)
    self.address = ethAddr
  }

  public init(mnemonic: String, path: DerivationPath) throws {
    guard BIP39.validate(mnemonic) else {
      throw SignerError.invalidMnemonic
    }
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try BIP32.derive(seed: seed, path: path)
    try self.init(privateKey: key.privateKey)
  }

  // MARK: - Account Protocol

  public func balanceRequest() -> ChainRequest {
    balanceRequest(at: .latest)
  }

  public func balanceRequest(at block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getBalance", params: [address.checksummed, block.rawValue])
  }

  public func nonceRequest() -> ChainRequest {
    nonceRequest(at: .latest)
  }

  public func nonceRequest(at block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getTransactionCount", params: [address.checksummed, block.rawValue])
  }

  public func codeRequest() -> ChainRequest {
    codeRequest(at: .latest)
  }

  public func codeRequest(at block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getCode", params: [address.checksummed, block.rawValue])
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(address)
  }
}
