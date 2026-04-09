//
//  StarknetAccount.swift
//  StarknetKit
//
//  Starknet account: combines signing with an address to sign and build transactions.
//  Works with any already-deployed account (OZ, Argent, Braavos, etc.).
//

import BigInt
import Foundation
import MultiChainCore

// MARK: - StarknetAccount

public struct StarknetAccount: Account, Sendable {
  public typealias C = Starknet

  private let privateKey: Felt
  public let address: StarknetAddress
  public let chain: Starknet
  public let provider: (any Provider<Starknet>)?
  public let accountType: (any StarknetAccountType)?

  // MARK: - Init

  public init(
    privateKey: Felt, address: StarknetAddress, chain: Starknet,
    provider: (any Provider<Starknet>)? = nil,
    accountType: (any StarknetAccountType)? = nil
  ) throws {
    guard privateKey != .zero else {
      throw StarkCurveError.invalidPrivateKey
    }
    self.privateKey = privateKey
    self.address = address
    self.chain = chain
    self.provider = provider
    self.accountType = accountType
  }

  public init(
    privateKey: Data, address: StarknetAddress, chain: Starknet,
    provider: (any Provider<Starknet>)? = nil,
    accountType: (any StarknetAccountType)? = nil
  ) throws {
    let felt = Felt(privateKey)
    try self.init(privateKey: felt, address: address, chain: chain, provider: provider, accountType: accountType)
  }

  public init(
    mnemonic: String, path: DerivationPath, address: StarknetAddress, chain: Starknet,
    provider: (any Provider<Starknet>)? = nil,
    accountType: (any StarknetAccountType)? = nil
  ) throws {
    guard BIP39.validate(mnemonic) else {
      throw CryptoError.invalidMnemonic
    }
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: path)
    try self.init(privateKey: key, address: address, chain: chain, provider: provider, accountType: accountType)
  }

  /// Create account with auto-derived address from private key + account type.
  public init(
    privateKey: Felt,
    accountType: any StarknetAccountType = OpenZeppelinAccount(),
    chain: Starknet,
    provider: (any Provider<Starknet>)? = nil
  ) throws {
    guard privateKey != .zero else {
      throw StarkCurveError.invalidPrivateKey
    }
    guard let publicKey = try? StarkCurve.getPublicKey(privateKey: privateKey) else {
      throw CryptoError.publicKeyDerivationFailed
    }
    let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
    try self.init(privateKey: privateKey, address: address, chain: chain, provider: provider, accountType: accountType)
  }

  /// The sender address as Felt (for transaction building).
  public var addressFelt: Felt { Felt(address.data) }

  // MARK: - Account Protocol

  public var publicKey: Data? {
    try? StarkCurve.getPublicKey(privateKey: privateKey).bigEndianData
  }

  public var publicKeyFelt: Felt? {
    guard let pubKey = publicKey else { return nil }
    return Felt(pubKey)
  }

  public func sign(hash: Data) throws -> StarknetSignature {
    try sign(feltHash: Felt(hash))
  }

  /// Sign a Felt message hash directly.
  public func sign(feltHash: Felt) throws -> StarknetSignature {
    try StarkCurve.sign(privateKey: privateKey, hash: feltHash)
  }

  public func sign(transaction: inout StarknetTransaction) throws {
    let hash = try transaction.transactionHashFelt()
    let sig = try sign(feltHash: hash)
    let formatted = formatSig(sig)
    switch transaction {
    case .invokeV1(var tx):
      tx.signature = formatted
      transaction = .invokeV1(tx)
    case .invokeV3(var tx):
      tx.signature = formatted
      transaction = .invokeV3(tx)
    case .deployAccountV1(var tx):
      tx.signature = formatted
      transaction = .deployAccountV1(tx)
    case .deployAccountV3(var tx):
      tx.signature = formatted
      transaction = .deployAccountV3(tx)
    }
  }

  public func signMessage(_ message: Data) throws -> StarknetSignature {
    try sign(feltHash: Felt(message))
  }

  public func sendTransaction(_ transaction: StarknetTransaction) async throws -> TxHash {
    let p = try requireProvider()
    let request: ChainRequest
    switch transaction {
    case .invokeV1(let tx):
      let param = StarknetInvokeV1Param(tx: tx)
      request = ChainRequest(method: "starknet_addInvokeTransaction", params: [param])
    case .invokeV3(let tx):
      let param = StarknetInvokeV3Param(tx: tx)
      request = ChainRequest(method: "starknet_addInvokeTransaction", params: [param])
    case .deployAccountV1(let tx):
      let param = StarknetDeployAccountV1Param(tx: tx)
      request = ChainRequest(method: "starknet_addDeployAccountTransaction", params: [param])
    case .deployAccountV3(let tx):
      let param = StarknetDeployAccountV3Param(tx: tx)
      request = ChainRequest(method: "starknet_addDeployAccountTransaction", params: [param])
    }
    let response: StarknetInvokeTransactionResponse = try await p.send(request: request)
    return response.transactionHash
  }

  // MARK: - Build InvokeV1

  /// Build an unsigned InvokeV1 transaction from calls.
  public func buildInvokeV1(calls: [StarknetCall], maxFee: Felt, nonce: Felt) -> StarknetInvokeV1 {
    let calldata = StarknetCall.encodeMulticall(calls)
    return StarknetInvokeV1(
      senderAddress: addressFelt,
      calldata: calldata,
      maxFee: maxFee,
      nonce: nonce,
      chainId: chain.chainId
    )
  }

  // MARK: - Build InvokeV3

  /// Build an unsigned InvokeV3 transaction from calls.
  public func buildInvokeV3(
    calls: [StarknetCall],
    resourceBounds: StarknetResourceBoundsMapping,
    nonce: Felt,
    tip: UInt64 = 0,
    nonceDAMode: StarknetDAMode = .l1,
    feeDAMode: StarknetDAMode = .l1,
    paymasterData: [Felt] = [],
    accountDeploymentData: [Felt] = []
  ) -> StarknetInvokeV3 {
    let calldata = StarknetCall.encodeMulticall(calls)
    return StarknetInvokeV3(
      senderAddress: addressFelt,
      calldata: calldata,
      resourceBounds: resourceBounds,
      tip: tip,
      nonce: nonce,
      nonceDAMode: nonceDAMode,
      feeDAMode: feeDAMode,
      paymasterData: paymasterData,
      accountDeploymentData: accountDeploymentData,
      chainId: chain.chainId
    )
  }

  // MARK: - Sign Specific Transactions

  /// Sign an InvokeV1 transaction and return a copy with the signature attached.
  public func signInvokeV1(_ tx: StarknetInvokeV1) throws -> StarknetInvokeV1 {
    let hash = try tx.transactionHash()
    let sig = try sign(feltHash: hash)
    var signed = tx
    signed.signature = formatSig(sig)
    return signed
  }

  /// Sign an InvokeV3 transaction and return a copy with the signature attached.
  public func signInvokeV3(_ tx: StarknetInvokeV3) throws -> StarknetInvokeV3 {
    let hash = try tx.transactionHash()
    let sig = try sign(feltHash: hash)
    var signed = tx
    signed.signature = formatSig(sig)
    return signed
  }

  /// Sign a DeployAccountV1 transaction and return a copy with the signature attached.
  public func signDeployAccountV1(_ tx: StarknetDeployAccountV1) throws -> StarknetDeployAccountV1 {
    let hash = try tx.transactionHash()
    let sig = try sign(feltHash: hash)
    var signed = tx
    signed.signature = formatSig(sig)
    return signed
  }

  /// Sign a DeployAccountV3 transaction and return a copy with the signature attached.
  public func signDeployAccountV3(_ tx: StarknetDeployAccountV3) throws -> StarknetDeployAccountV3 {
    let hash = try tx.transactionHash()
    let sig = try sign(feltHash: hash)
    var signed = tx
    signed.signature = formatSig(sig)
    return signed
  }

  // MARK: - Fee Estimation (batch)

  /// Estimate the fee for a batch of calls.
  public func estimateFee(
    calls: [StarknetCall],
    nonce: Felt,
    resourceBounds: StarknetResourceBoundsMapping = .zero
  ) async throws -> StarknetFeeEstimate {
    let p = try requireProvider()
    let tx = buildInvokeV3(calls: calls, resourceBounds: resourceBounds, nonce: nonce)
    let signed = try signInvokeV3(tx)
    let request = StarknetRequestBuilder.estimateFeeRequest(invokeV3: signed)
    let results: [StarknetFeeEstimate] = try await p.send(request: request)
    guard let estimate = results.first else {
      throw ProviderError.emptyResult
    }
    return estimate
  }

  // MARK: - Execute (batch)

  /// Execute a batch of calls: build V3 invoke, sign, and broadcast.
  public func execute(
    calls: [StarknetCall],
    resourceBounds: StarknetResourceBoundsMapping,
    nonce: Felt
  ) async throws -> StarknetInvokeTransactionResponse {
    let p = try requireProvider()
    let tx = buildInvokeV3(calls: calls, resourceBounds: resourceBounds, nonce: nonce)
    let signed = try signInvokeV3(tx)
    let request = StarknetRequestBuilder.addInvokeTransactionRequest(invokeV3: signed)
    return try await p.send(request: request)
  }

  // MARK: - Execute V3 (auto fee)

  /// Execute calls with automatic nonce + fee estimation.
  public func executeV3(
    calls: [StarknetCall],
    feeMultiplier: Double = 1.5
  ) async throws -> StarknetInvokeTransactionResponse {
    let p = try requireProvider()

    // Get nonce
    let nonceHex: String = try await p.send(
      request: StarknetRequestBuilder.getNonceRequest(address: address))
    guard let nonce = Felt(nonceHex) else {
      throw ChainError.invalidTransaction("Cannot parse nonce: \(nonceHex)")
    }

    // Estimate fee
    let estimate = try await estimateFee(calls: calls, nonce: nonce)
    let resourceBounds = estimate.toResourceBounds(multiplier: feeMultiplier)

    return try await execute(calls: calls, resourceBounds: resourceBounds, nonce: nonce)
  }

  // MARK: - Private

  private func formatSig(_ sig: StarknetSignature) -> [Felt] {
    if accountType != nil, let pubKey = publicKeyFelt {
      return accountType!.formatSignature(sig, publicKey: pubKey)
    }
    return sig.feltArray
  }

  private func requireProvider() throws -> any Provider<Starknet> {
    guard let provider else {
      throw ChainError.noProvider
    }
    return provider
  }
}
