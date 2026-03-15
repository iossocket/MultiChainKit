//
//  EthereumAccount.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public struct EthereumAccount: Account, PrivateKeySigner, MnemonicSigner, Sendable {
  public typealias C = EvmChain

  private let privateKey: Data
  public let provider: (any Provider<EvmChain>)?

  // MARK: - PrivateKeySigner

  public init(privateKey: Data) throws {
    try self.init(privateKey: privateKey, provider: nil)
  }

  // MARK: - MnemonicSigner

  public init(mnemonic: String, path: DerivationPath) throws {
    try self.init(mnemonic: mnemonic, path: path, provider: nil)
  }

  // MARK: - Init

  public init(privateKey: Data, provider: (any Provider<EvmChain>)?) throws {
    guard (try? Secp256k1.publicKey(from: privateKey)) != nil else {
      throw CryptoError.invalidPrivateKey
    }
    self.privateKey = privateKey
    self.provider = provider
  }

  public init(mnemonic: String, path: DerivationPath, provider: (any Provider<EvmChain>)?) throws {
    guard BIP39.validate(mnemonic) else {
      throw CryptoError.invalidMnemonic
    }
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try BIP32.derive(seed: seed, path: path)
    try self.init(privateKey: key.privateKey, provider: provider)
  }

  // MARK: - Account Protocol

  public var address: EthereumAddress {
    try! Secp256k1.ethereumAddress(fromPrivateKey: privateKey)
  }

  public var publicKey: Data? {
    try? Secp256k1.publicKey(from: privateKey)
  }

  public func sign(hash: Data) throws -> EthereumSignature {
    do {
      let sigData = try Secp256k1.sign(message: hash, privateKey: privateKey)
      return try EthereumSignature(data: sigData)
    } catch {
      throw CryptoError.signingFailed(error.localizedDescription)
    }
  }

  public func sign(transaction: inout EthereumTransaction) throws {
    transaction.signature = try sign(hash: transaction.hashForSigning())
  }

  public func signMessage(_ message: Data) throws -> EthereumSignature {
    let prefix = "\u{19}Ethereum Signed Message:\n\(message.count)"
    var prefixed = Data(prefix.utf8)
    prefixed.append(message)
    return try sign(hash: Keccak256.hash(prefixed))
  }

  public func sendTransaction(_ transaction: EthereumTransaction) async throws -> TxHash {
    guard let raw = transaction.rawTransaction else {
      throw ChainError.invalidTransaction("Transaction not signed")
    }
    let p = try requireProvider()
    return try await p.send(request: EthereumRequestBuilder.sendRawTransactionRequest(raw))
  }

  // MARK: - Message Signing (EIP-191)

  public func signMessage(_ message: String) throws -> EthereumSignature {
    guard let data = message.data(using: .utf8) else {
      throw CryptoError.signingFailed("Invalid UTF-8 string")
    }
    return try signMessage(data)
  }

  public func recoverMessageSigner(message: String, signature: EthereumSignature) throws
    -> EthereumAddress
  {
    let messageData = message.data(using: .utf8)!
    let prefix = "\u{19}Ethereum Signed Message:\n\(messageData.count)"
    let prefixedMessage = prefix.data(using: .utf8)! + messageData
    let hash = Keccak256.hash(prefixedMessage)
    return try signature.recoverAddress(from: hash)
  }

  // MARK: - EIP-712 Typed Data

  public func signTypedData(_ typedData: EIP712TypedData) throws -> EthereumSignature {
    let hash = try typedData.signHash()
    return try sign(hash: hash)
  }

  // MARK: - Send Transaction (Convenience)

  /// Prepare, sign, and broadcast a transaction. Returns the tx hash.
  public func sendTransaction(
    to: EthereumAddress,
    value: Wei = .zero,
    data: Data = Data()
  ) async throws -> String {
    let p = try requireProvider()
    var tx = try await prepareTransaction(to: to, value: value, data: data)
    try sign(transaction: &tx)
    guard let raw = tx.rawTransaction else {
      throw ChainError.invalidTransaction("Failed to encode signed transaction")
    }
    return try await p.send(request: EthereumRequestBuilder.sendRawTransactionRequest(raw))
  }

  /// Build a ready-to-sign EIP-1559 transaction with auto-filled nonce, gas, and fees.
  public func prepareTransaction(
    to: EthereumAddress,
    value: Wei = .zero,
    data: Data = Data()
  ) async throws -> EthereumTransaction {
    let p = try requireProvider()

    let nonceHex: String = try await p.send(
      request: EthereumRequestBuilder.getTransactionCountRequest(address: address, block: .pending))
    let priorityFeeHex: String = try await p.send(
      request: EthereumRequestBuilder.maxPriorityFeePerGasRequest())
    let block: EthereumBlock = try await p.send(
      request: EthereumRequestBuilder.getBlockByNumberRequest(block: .latest, fullTransactions: false))

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
      request: EthereumRequestBuilder.estimateGasRequest(transaction: skeleton, from: address))
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

  private func requireProvider() throws -> any Provider<EvmChain> {
    guard let provider else {
      throw ChainError.noProvider
    }
    return provider
  }
}
