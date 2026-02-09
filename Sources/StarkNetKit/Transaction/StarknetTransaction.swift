//
//  StarknetTransaction.swift
//  StarknetKit
//

import BigInt
import Foundation
import MultiChainCore

// MARK: - Data Availability Mode

public enum StarknetDAMode: UInt8, Sendable, Codable {
  case l1 = 0
  case l2 = 1
}

// MARK: - Transaction Hash Prefixes

private let invokePrefix = Felt.fromShortString("invoke")
private let deployAccountPrefix = Felt.fromShortString("deploy_account")
private let l1GasPrefix = Felt.fromShortString("L1_GAS")
private let l2GasPrefix = Felt.fromShortString("L2_GAS")
private let l1DataGasPrefix = Felt.fromShortString("L1_DATA")

// MARK: - InvokeV1

public struct StarknetInvokeV1: Sendable, Equatable {
  public let senderAddress: Felt
  public let calldata: [Felt]
  public let maxFee: Felt
  public let nonce: Felt
  public let chainId: Felt
  public var signature: [Felt]

  public init(
    senderAddress: Felt,
    calldata: [Felt],
    maxFee: Felt,
    nonce: Felt,
    chainId: Felt,
    signature: [Felt] = []
  ) {
    self.senderAddress = senderAddress
    self.calldata = calldata
    self.maxFee = maxFee
    self.nonce = nonce
    self.chainId = chainId
    self.signature = signature
  }

  /// Compute transaction hash using Pedersen.
  /// hash = pedersen_on([invoke, 1, sender, 0, pedersen_on(calldata), maxFee, chainId, nonce])
  public func transactionHash() throws -> Felt {
    let calldataHash = try Pedersen.hashMany(calldata)
    return try Pedersen.hashMany([
      invokePrefix, Felt(1), senderAddress, .zero, calldataHash, maxFee, chainId, nonce,
    ])
  }
}

// MARK: - InvokeV3

public struct StarknetInvokeV3: Sendable, Equatable {
  public let senderAddress: Felt
  public let calldata: [Felt]
  public let resourceBounds: StarknetResourceBoundsMapping
  public let tip: UInt64
  public let nonce: Felt
  public let nonceDAMode: StarknetDAMode
  public let feeDAMode: StarknetDAMode
  public let paymasterData: [Felt]
  public let accountDeploymentData: [Felt]
  public let chainId: Felt
  public var signature: [Felt]

  public init(
    senderAddress: Felt,
    calldata: [Felt],
    resourceBounds: StarknetResourceBoundsMapping,
    tip: UInt64 = 0,
    nonce: Felt,
    nonceDAMode: StarknetDAMode = .l1,
    feeDAMode: StarknetDAMode = .l1,
    paymasterData: [Felt] = [],
    accountDeploymentData: [Felt] = [],
    chainId: Felt,
    signature: [Felt] = []
  ) {
    self.senderAddress = senderAddress
    self.calldata = calldata
    self.resourceBounds = resourceBounds
    self.tip = tip
    self.nonce = nonce
    self.nonceDAMode = nonceDAMode
    self.feeDAMode = feeDAMode
    self.paymasterData = paymasterData
    self.accountDeploymentData = accountDeploymentData
    self.chainId = chainId
    self.signature = signature
  }

  /// Compute transaction hash using Poseidon.
  /// hash = poseidon_many([invoke, 3, sender, feeFieldHash, paymasterHash, chainId, nonce, daModes, accountDeployHash, calldataHash])
  public func transactionHash() throws -> Felt {
    let encodedBounds = StarknetTransactionHashUtil.encodeResourceBounds(resourceBounds)
    let feeFieldHash = try Poseidon.hashMany([Felt(tip)] + encodedBounds)
    let paymasterHash = try Poseidon.hashMany(paymasterData)
    let daModes = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: feeDAMode, nonceDAMode: nonceDAMode)
    let accountDeployHash = try Poseidon.hashMany(accountDeploymentData)
    let calldataHash = try Poseidon.hashMany(calldata)
    return try Poseidon.hashMany([
      invokePrefix, Felt(3), senderAddress, feeFieldHash, paymasterHash,
      chainId, nonce, daModes, accountDeployHash, calldataHash,
    ])
  }
}

// MARK: - DeployAccountV1

public struct StarknetDeployAccountV1: Sendable, Equatable {
  public let classHash: Felt
  public let contractAddressSalt: Felt
  public let constructorCalldata: [Felt]
  public let maxFee: Felt
  public let nonce: Felt
  public let chainId: Felt
  public var signature: [Felt]

  public init(
    classHash: Felt,
    contractAddressSalt: Felt,
    constructorCalldata: [Felt],
    maxFee: Felt,
    nonce: Felt,
    chainId: Felt,
    signature: [Felt] = []
  ) {
    self.classHash = classHash
    self.contractAddressSalt = contractAddressSalt
    self.constructorCalldata = constructorCalldata
    self.maxFee = maxFee
    self.nonce = nonce
    self.chainId = chainId
    self.signature = signature
  }

  /// Compute the contract address that will be deployed.
  public func contractAddress() throws -> Felt {
    try StarknetContractAddress.calculate(
      classHash: classHash, calldata: constructorCalldata,
      salt: contractAddressSalt)
  }

  /// Compute transaction hash using Pedersen.
  /// hash = pedersen_on([deploy_account, 1, contractAddress, 0, pedersen_on([classHash, salt, ...calldata]), maxFee, chainId, nonce])
  public func transactionHash() throws -> Felt {
    let address = try contractAddress()
    let calldataHash = try Pedersen.hashMany([classHash, contractAddressSalt] + constructorCalldata)
    return try Pedersen.hashMany([
      deployAccountPrefix, Felt(1), address, .zero, calldataHash, maxFee, chainId, nonce,
    ])
  }
}

// MARK: - DeployAccountV3

public struct StarknetDeployAccountV3: Sendable, Equatable {
  public let classHash: Felt
  public let contractAddressSalt: Felt
  public let constructorCalldata: [Felt]
  public let resourceBounds: StarknetResourceBoundsMapping
  public let tip: UInt64
  public let nonce: Felt
  public let nonceDAMode: StarknetDAMode
  public let feeDAMode: StarknetDAMode
  public let paymasterData: [Felt]
  public let chainId: Felt
  public var signature: [Felt]

  public init(
    classHash: Felt,
    contractAddressSalt: Felt,
    constructorCalldata: [Felt],
    resourceBounds: StarknetResourceBoundsMapping,
    tip: UInt64 = 0,
    nonce: Felt,
    nonceDAMode: StarknetDAMode = .l1,
    feeDAMode: StarknetDAMode = .l1,
    paymasterData: [Felt] = [],
    chainId: Felt,
    signature: [Felt] = []
  ) {
    self.classHash = classHash
    self.contractAddressSalt = contractAddressSalt
    self.constructorCalldata = constructorCalldata
    self.resourceBounds = resourceBounds
    self.tip = tip
    self.nonce = nonce
    self.nonceDAMode = nonceDAMode
    self.feeDAMode = feeDAMode
    self.paymasterData = paymasterData
    self.chainId = chainId
    self.signature = signature
  }

  /// Compute the contract address that will be deployed.
  public func contractAddress() throws -> Felt {
    try StarknetContractAddress.calculate(
      classHash: classHash, calldata: constructorCalldata,
      salt: contractAddressSalt)
  }

  /// Compute transaction hash using Poseidon.
  /// hash = poseidon_many([deploy_account, 3, contractAddress, feeFieldHash, paymasterHash, chainId, nonce, daModes, poseidon_many(calldata), classHash, salt])
  public func transactionHash() throws -> Felt {
    let address = try contractAddress()
    let encodedBounds = StarknetTransactionHashUtil.encodeResourceBounds(resourceBounds)
    let feeFieldHash = try Poseidon.hashMany([Felt(tip)] + encodedBounds)
    let paymasterHash = try Poseidon.hashMany(paymasterData)
    let daModes = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: feeDAMode, nonceDAMode: nonceDAMode)
    let calldataHash = try Poseidon.hashMany(constructorCalldata)
    return try Poseidon.hashMany([
      deployAccountPrefix, Felt(3), address, feeFieldHash, paymasterHash,
      chainId, nonce, daModes, calldataHash, classHash, contractAddressSalt,
    ])
  }
}

// MARK: - Contract Address Calculation

public enum StarknetContractAddress {
  private static let contractAddressPrefix = Felt.fromShortString("STARKNET_CONTRACT_ADDRESS")

  /// Calculate contract address from class hash, constructor calldata, salt, and deployer.
  /// address = pedersen("STARKNET_CONTRACT_ADDRESS", deployer, salt, classHash, pedersen(calldata)) mod 2^251
  public static func calculate(
    classHash: Felt,
    calldata: [Felt],
    salt: Felt,
    deployerAddress: Felt = .zero
  ) throws -> Felt {
    let calldataHash = try Pedersen.hashMany(calldata)
    let fullHash = try Pedersen.hashMany([contractAddressPrefix, deployerAddress, salt, classHash, calldataHash])
    let mask = BigUInt(1) << 251
    return Felt(fullHash.bigUIntValue % mask)
  }
}

// MARK: - V3 Hash Helpers

public enum StarknetTransactionHashUtil {
  /// Encode resource bounds into 3 Felt values for V3 hash.
  /// Each: prefix << 192 | maxAmount << 128 | maxPricePerUnit
  public static func encodeResourceBounds(_ bounds: StarknetResourceBoundsMapping) -> [Felt] {
    func encode(prefix: Felt, bound: StarknetResourceBounds) -> Felt {
      let value = (prefix.bigUIntValue << 192)
        + (BigUInt(bound.maxAmount) << 128)
        + bound.maxPricePerUnit
      return Felt(value)
    }
    return [
      encode(prefix: l1GasPrefix, bound: bounds.l1Gas),
      encode(prefix: l2GasPrefix, bound: bounds.l2Gas),
      encode(prefix: l1DataGasPrefix, bound: bounds.l1DataGas),
    ]
  }

  /// Encode DA modes into a single Felt: (nonceDAMode << 32) + feeDAMode
  public static func encodeDAModes(
    feeDAMode: StarknetDAMode,
    nonceDAMode: StarknetDAMode
  ) -> Felt {
    Felt(UInt64(nonceDAMode.rawValue) << 32 + UInt64(feeDAMode.rawValue))
  }
}

// MARK: - ChainTransaction Conformance (wrapper)

public struct StarknetTransaction: ChainTransaction, Sendable {
  public typealias C = Starknet

  public let hash: Data?

  public func hashForSigning() -> Data {
    hash ?? Data()
  }

  public func encode() -> Data {
    Data()
  }
}
