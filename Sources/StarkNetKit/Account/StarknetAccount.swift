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

public struct StarknetAccount: Sendable {
  public let signer: StarknetSigner
  public let address: StarknetAddress
  public let chain: Starknet

  /// Create an account from a signer and a known deployed address.
  public init(signer: StarknetSigner, address: StarknetAddress, chain: Starknet) {
    self.signer = signer
    self.address = address
    self.chain = chain
  }

  /// The sender address as Felt (for transaction building).
  public var addressFelt: Felt { Felt(address.data) }

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
}
