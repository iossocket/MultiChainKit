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
  public let provider: EthereumProvider?

  // MARK: - Init

  public init(_ signer: EthereumSigner, provider: EthereumProvider? = nil) throws {
    guard let address = signer.address else {
      throw SignerError.invalidPrivateKey
    }
    self.signer = signer
    self.account = EthereumAccount(address: address)
    self.provider = provider
  }

  public init(privateKey: Data, provider: EthereumProvider? = nil) throws {
    let signer = try EthereumSigner(privateKey: privateKey)
    try self.init(signer, provider: provider)
  }

  public init(mnemonic: String, path: DerivationPath, provider: EthereumProvider? = nil) throws {
    let signer = try EthereumSigner(mnemonic: mnemonic, path: path)
    try self.init(signer, provider: provider)
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

  // MARK: - Send Transaction

  /// Build a ready-to-sign EIP-1559 transaction with auto-filled nonce, gas, and fees.
  public func prepareTransaction(
    to: EthereumAddress,
    value: Wei = .zero,
    data: Data = Data()
  ) async throws -> EthereumTransaction {
    let p = try requireProvider()

    let nonceHex: String = try await p.send(
      request: p.getTransactionCountRequest(address: address, block: .pending))
    let priorityFeeHex: String = try await p.send(
      request: p.maxPriorityFeePerGasRequest())
    let block: EthereumBlock = try await p.send(
      request: p.getBlockByNumberRequest(block: .latest, fullTransactions: false))

    guard let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) else {
      throw ChainError.invalidTransaction("Cannot parse nonce: \(nonceHex)")
    }
    guard let maxPriorityFeePerGas = Wei(priorityFeeHex) else {
      throw ChainError.invalidTransaction("Cannot parse priority fee: \(priorityFeeHex)")
    }
    guard let baseFeeHex = block.baseFeePerGas, let baseFee = Wei(baseFeeHex) else {
      throw ChainError.invalidTransaction("Cannot parse baseFeePerGas")
    }

    // maxFeePerGas = baseFee * 2 + maxPriorityFeePerGas
    let maxFeePerGas = baseFee + baseFee + maxPriorityFeePerGas

    // Estimate gas with a skeleton tx
    let skeleton = EthereumTransaction(
      chainId: p.chain.chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: 0,
      to: to,
      value: value,
      data: data
    )

    let gasHex: String = try await p.send(
      request: p.estimateGasRequest(transaction: skeleton))
    guard let gasLimit = UInt64(gasHex.dropFirst(2), radix: 16) else {
      throw ChainError.invalidTransaction("Cannot parse gas estimate: \(gasHex)")
    }

    return EthereumTransaction(
      chainId: p.chain.chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: gasLimit,
      to: to,
      value: value,
      data: data
    )
  }

  /// Prepare, sign, and broadcast a transaction. Returns the tx hash.
  public func sendTransaction(
    to: EthereumAddress,
    value: Wei = .zero,
    data: Data = Data()
  ) async throws -> String {
    let p = try requireProvider()
    var tx = try await prepareTransaction(to: to, value: value, data: data)
    try tx.sign(with: signer)
    guard let raw = tx.rawTransaction else {
      throw ChainError.invalidTransaction("Failed to encode signed transaction")
    }
    return try await p.send(request: p.sendRawTransactionRequest(raw))
  }

  private func requireProvider() throws -> EthereumProvider {
    guard let provider else {
      throw EthereumAccountError.noProvider
    }
    return provider
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

// MARK: - EthereumAccountError

public enum EthereumAccountError: Error, Sendable, Equatable {
  case noProvider
}