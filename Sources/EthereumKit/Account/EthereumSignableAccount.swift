//
//  EthereumSignableAccount.swift
//  EthereumKit
//


import Foundation
import MultiChainCore

public struct EthereumSignableAccount: Account, Signer, Sendable {
  public typealias C = Ethereum

  private let signer: EthereumSigner
  private let account: EthereumAccount

  // MARK: - Init

  public init(_ signer: EthereumSigner) throws {
    guard let address = signer.address else {
      throw SignerError.invalidPrivateKey
    }
    self.signer = signer
    self.account = EthereumAccount(address: address)
  }

  public init(privateKey: Data) throws {
    let signer = try EthereumSigner(privateKey: privateKey)
    try self.init(signer)
  }

  public init(mnemonic: String, path: DerivationPath) throws {
    let signer = try EthereumSigner(mnemonic: mnemonic, path: path)
    try self.init(signer)
  }

  // MARK: - Account Protocol

  public var address: EthereumAddress {
    signer.address!
  }

  public var publicKey: Data? {
    self.signer.publicKey
  }

  public func balanceRequest() -> ChainRequest {
    self.account.balanceRequest()
  }

  public func nonceRequest() -> ChainRequest {
    self.account.nonceRequest()
  }

  // MARK: - Signer Protocol

  public func sign(hash: Data) throws -> EthereumSignature {
    try self.signer.sign(hash: hash)
  }

  // MARK: - Message Signing (EIP-191)

  public func signMessage(_ message: String) throws -> EthereumSignature {
    try self.signer.signPersonalMessage(message)
  }

  public func signMessage(_ message: Data) throws -> EthereumSignature {
    try self.signer.signPersonalMessage(message)
  }

  public func recoverMessageSigner(message: String, signature: EthereumSignature) throws -> EthereumAddress {
    let messageData = message.data(using: .utf8)!
    let prefix = "\u{19}Ethereum Signed Message:\n\(messageData.count)"
    let prefixedMessage = prefix.data(using: .utf8)! + messageData
    let hash = Keccak256.hash(prefixedMessage)
    return try signature.recoverAddress(from: hash)
  }

  // MARK: - Transaction Signing

  public func sign(transaction: inout EthereumTransaction) throws {
    try transaction.sign(with: self.signer)
  }

  // MARK: - Transfer Helper

  public func transferTransaction(
    to: EthereumAddress,
    value: Wei,
    nonce: UInt64,
    maxPriorityFeePerGas: Wei,
    maxFeePerGas: Wei,
    chainId: UInt64
  ) -> EthereumTransaction {
    EthereumTransaction(
      chainId: chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: 21000,
      to: to,
      value: value,
      data: Data()
    )
  }
}