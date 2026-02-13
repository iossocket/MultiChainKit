//
//  StarknetAccount.swift
//  StarknetKit
//
//  Starknet account: combines a signer with an address to sign and build transactions.
//  Works with any already-deployed account (OZ, Argent, Braavos, etc.).
//

import BigInt
import Foundation
import MultiChainCore

// MARK: - StarknetAccount

public struct StarknetAccount: SignableAccount, Sendable {
  public typealias C = Starknet
  public typealias S = StarknetSigner

  public let signer: StarknetSigner
  public let address: StarknetAddress
  public let chain: Starknet
  public let provider: StarknetProvider?

  /// Create an account from a signer and a known deployed address.
  public init(signer: StarknetSigner, address: StarknetAddress, chain: Starknet, provider: StarknetProvider? = nil) {
    self.signer = signer
    self.address = address
    self.chain = chain
    self.provider = provider
  }

  /// The sender address as Felt (for transaction building).
  public var addressFelt: Felt { Felt(address.data) }

  // MARK: - SignableAccount Protocol

  public func balanceRequest() -> ChainRequest {
    // STRK is the native token on Starknet.
    let strkContract = Felt("0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d")!
    let call = StarknetCall(
      contractAddress: strkContract,
      entrypoint: "balanceOf",
      calldata: [addressFelt]
    )
    let callParam = StarknetCallParam(
      contractAddress: strkContract.hexString,
      entryPointSelector: call.entryPointSelector.hexString,
      calldata: call.calldata.map { $0.hexString }
    )
    return ChainRequest(method: "starknet_call", params: [callParam, StarknetBlockId.latest])
  }

  public func sign(transaction: inout StarknetTransaction) throws {
    try transaction.sign(with: signer)
  }

  public func signMessage(_ message: Data) throws -> StarknetSignature {
    try signer.sign(hash: message)
  }

  public func sendTransactionRequest(_ transaction: StarknetTransaction) -> ChainRequest {
    switch transaction {
    case .invokeV1(let tx):
      let param = StarknetInvokeV1Param(tx: tx)
      return ChainRequest(method: "starknet_addInvokeTransaction", params: [param])
    case .invokeV3(let tx):
      let param = StarknetInvokeV3Param(tx: tx)
      return ChainRequest(method: "starknet_addInvokeTransaction", params: [param])
    case .deployAccountV1(let tx):
      let param = StarknetDeployAccountV1Param(tx: tx)
      return ChainRequest(method: "starknet_addDeployAccountTransaction", params: [param])
    case .deployAccountV3(let tx):
      let param = StarknetDeployAccountV3Param(tx: tx)
      return ChainRequest(method: "starknet_addDeployAccountTransaction", params: [param])
    }
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

  // MARK: - Sign

  /// Sign an InvokeV1 transaction and return a copy with the signature attached.
  public func signInvokeV1(_ tx: StarknetInvokeV1) throws -> StarknetInvokeV1 {
    let hash = try tx.transactionHash()
    let sig = try signer.sign(feltHash: hash)
    var signed = tx
    signed.signature = sig.feltArray
    return signed
  }

  /// Sign an InvokeV3 transaction and return a copy with the signature attached.
  public func signInvokeV3(_ tx: StarknetInvokeV3) throws -> StarknetInvokeV3 {
    let hash = try tx.transactionHash()
    let sig = try signer.sign(feltHash: hash)
    var signed = tx
    signed.signature = sig.feltArray
    return signed
  }

  /// Sign a DeployAccountV1 transaction and return a copy with the signature attached.
  public func signDeployAccountV1(_ tx: StarknetDeployAccountV1) throws -> StarknetDeployAccountV1 {
    let hash = try tx.transactionHash()
    let sig = try signer.sign(feltHash: hash)
    var signed = tx
    signed.signature = sig.feltArray
    return signed
  }

  /// Sign a DeployAccountV3 transaction and return a copy with the signature attached.
  public func signDeployAccountV3(_ tx: StarknetDeployAccountV3) throws -> StarknetDeployAccountV3 {
    let hash = try tx.transactionHash()
    let sig = try signer.sign(feltHash: hash)
    var signed = tx
    signed.signature = sig.feltArray
    return signed
  }

  // MARK: - Fee Estimation (batch)

  /// Estimate the fee for a batch of calls.
  /// Builds a V3 invoke transaction, signs it, and sends to starknet_estimateFee.
  public func estimateFee(
    calls: [StarknetCall],
    nonce: Felt,
    resourceBounds: StarknetResourceBoundsMapping = .zero
  ) async throws -> StarknetFeeEstimate {
    let p = try requireProvider()
    let tx = buildInvokeV3(calls: calls, resourceBounds: resourceBounds, nonce: nonce)
    let signed = try signInvokeV3(tx)
    let request = p.estimateFeeRequest(invokeV3: signed)
    let results: [StarknetFeeEstimate] = try await p.send(request: request)
    guard let estimate = results.first else {
      throw StarknetAccountError.emptyFeeEstimate
    }
    return estimate
  }

  // MARK: - Execute (batch)

  /// Execute a batch of calls: build V3 invoke, sign, and broadcast.
  /// Returns the transaction hash.
  public func execute(
    calls: [StarknetCall],
    resourceBounds: StarknetResourceBoundsMapping,
    nonce: Felt
  ) async throws -> StarknetInvokeTransactionResponse {
    let p = try requireProvider()
    let tx = buildInvokeV3(calls: calls, resourceBounds: resourceBounds, nonce: nonce)
    let signed = try signInvokeV3(tx)
    let request = p.addInvokeTransactionRequest(invokeV3: signed)
    return try await p.send(request: request)
  }

  // MARK: - Private

  private func requireProvider() throws -> StarknetProvider {
    guard let provider else {
      throw StarknetAccountError.noProvider
    }
    return provider
  }
}

// MARK: - StarknetAccountError

public enum StarknetAccountError: Error, Sendable, Equatable {
  case noProvider
  case emptyFeeEstimate
}
