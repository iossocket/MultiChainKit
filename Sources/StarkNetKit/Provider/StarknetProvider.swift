//
//  StarknetProvider.swift
//  StarknetKit
//

import BigInt
import Foundation
import MultiChainCore

// MARK: - StarknetProvider

public final class StarknetProvider: JsonRpcProvider, Sendable {
  public typealias C = Starknet

  public let chain: Starknet
  public let session: URLSession

  public init(chain: Starknet, session: URLSession = .shared) {
    self.chain = chain
    self.session = session
  }

  // MARK: - Wait For Transaction

  /// Poll until a transaction is accepted, then return the full receipt.
  public func waitForTransaction(
    hash: Felt,
    config: PollingConfig = .default
  ) async throws -> StarknetReceipt {
    let deadline = Date().addingTimeInterval(config.timeoutSeconds)
    let sleepNanos = UInt64(config.intervalSeconds * 1_000_000_000)

    while Date() < deadline {
      // Poll status — RPC error means tx not yet in mempool, just retry
      let status: StarknetTransactionStatus
      do {
        status = try await send(request: StarknetRequestBuilder.getTransactionStatusRequest(hash: hash))
      } catch let error as ProviderError {
        if case .rpcError = error {
          try await Task.sleep(nanoseconds: sleepNanos)
          continue
        }
        throw error
      }

      if status.isRejected {
        throw ChainError.transactionFailed(reason: "REJECTED", txHash: hash.hexString)
      }
      if status.isReverted {
        throw ChainError.transactionFailed(
          reason: status.failureReason ?? "REVERTED", txHash: hash.hexString)
      }
      if status.isAccepted {
        return try await send(request: StarknetRequestBuilder.getTransactionReceiptRequest(hash: hash))
      }

      // RECEIVED or other — keep polling
      try await Task.sleep(nanoseconds: sleepNanos)
    }

    throw ProviderError.timeout
  }
}

// MARK: - Block ID

public enum StarknetBlockId: Encodable, Sendable {
  case latest
  case pending
  case number(UInt64)
  case hash(Felt)

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .latest:
      try container.encode("latest")
    case .pending:
      try container.encode("pending")
    case .number(let n):
      try container.encode(["block_number": n])
    case .hash(let h):
      try container.encode(["block_hash": h.hexString])
    }
  }
}

// MARK: - RPC Parameter Types

struct StarknetCallParam: Encodable, Sendable {
  let contractAddress: String
  let entryPointSelector: String
  let calldata: [String]

  enum CodingKeys: String, CodingKey {
    case contractAddress = "contract_address"
    case entryPointSelector = "entry_point_selector"
    case calldata
  }
}

struct StarknetInvokeV1Param: Encodable, Sendable {
  let type: String = "INVOKE"
  let version: String = "0x1"
  let senderAddress: String
  let calldata: [String]
  let maxFee: String
  let signature: [String]
  let nonce: String

  enum CodingKeys: String, CodingKey {
    case type, version
    case senderAddress = "sender_address"
    case calldata
    case maxFee = "max_fee"
    case signature, nonce
  }

  init(tx: StarknetInvokeV1) {
    self.senderAddress = tx.senderAddress.hexString
    self.calldata = tx.calldata.map { $0.hexString }
    self.maxFee = tx.maxFee.hexString
    self.signature = tx.signature.map { $0.hexString }
    self.nonce = tx.nonce.hexString
  }
}

struct StarknetInvokeV3Param: Encodable, Sendable {
  let type: String = "INVOKE"
  let version: String = "0x3"
  let senderAddress: String
  let calldata: [String]
  let signature: [String]
  let nonce: String
  let resourceBounds: ResourceBoundsParam
  let tip: String
  let paymasterData: [String]
  let accountDeploymentData: [String]
  let nonceDataAvailabilityMode: String
  let feeDataAvailabilityMode: String

  enum CodingKeys: String, CodingKey {
    case type, version
    case senderAddress = "sender_address"
    case calldata, signature, nonce
    case resourceBounds = "resource_bounds"
    case tip
    case paymasterData = "paymaster_data"
    case accountDeploymentData = "account_deployment_data"
    case nonceDataAvailabilityMode = "nonce_data_availability_mode"
    case feeDataAvailabilityMode = "fee_data_availability_mode"
  }

  init(tx: StarknetInvokeV3) {
    self.senderAddress = tx.senderAddress.hexString
    self.calldata = tx.calldata.map { $0.hexString }
    self.signature = tx.signature.map { $0.hexString }
    self.nonce = tx.nonce.hexString
    self.resourceBounds = ResourceBoundsParam(bounds: tx.resourceBounds)
    self.tip = "0x" + String(tx.tip, radix: 16)
    self.paymasterData = tx.paymasterData.map { $0.hexString }
    self.accountDeploymentData = tx.accountDeploymentData.map { $0.hexString }
    self.nonceDataAvailabilityMode = tx.nonceDAMode == .l1 ? "L1" : "L2"
    self.feeDataAvailabilityMode = tx.feeDAMode == .l1 ? "L1" : "L2"
  }
}

struct StarknetDeployAccountV1Param: Encodable, Sendable {
  let type: String = "DEPLOY_ACCOUNT"
  let version: String = "0x1"
  let classHash: String
  let contractAddressSalt: String
  let constructorCalldata: [String]
  let maxFee: String
  let signature: [String]
  let nonce: String

  enum CodingKeys: String, CodingKey {
    case type, version
    case classHash = "class_hash"
    case contractAddressSalt = "contract_address_salt"
    case constructorCalldata = "constructor_calldata"
    case maxFee = "max_fee"
    case signature, nonce
  }

  init(tx: StarknetDeployAccountV1) {
    self.classHash = tx.classHash.hexString
    self.contractAddressSalt = tx.contractAddressSalt.hexString
    self.constructorCalldata = tx.constructorCalldata.map { $0.hexString }
    self.maxFee = tx.maxFee.hexString
    self.signature = tx.signature.map { $0.hexString }
    self.nonce = tx.nonce.hexString
  }
}

struct StarknetDeployAccountV3Param: Encodable, Sendable {
  let type: String = "DEPLOY_ACCOUNT"
  let version: String = "0x3"
  let classHash: String
  let contractAddressSalt: String
  let constructorCalldata: [String]
  let signature: [String]
  let nonce: String
  let resourceBounds: ResourceBoundsParam
  let tip: String
  let paymasterData: [String]
  let nonceDataAvailabilityMode: String
  let feeDataAvailabilityMode: String

  enum CodingKeys: String, CodingKey {
    case type, version
    case classHash = "class_hash"
    case contractAddressSalt = "contract_address_salt"
    case constructorCalldata = "constructor_calldata"
    case signature, nonce
    case resourceBounds = "resource_bounds"
    case tip
    case paymasterData = "paymaster_data"
    case nonceDataAvailabilityMode = "nonce_data_availability_mode"
    case feeDataAvailabilityMode = "fee_data_availability_mode"
  }

  init(tx: StarknetDeployAccountV3) {
    self.classHash = tx.classHash.hexString
    self.contractAddressSalt = tx.contractAddressSalt.hexString
    self.constructorCalldata = tx.constructorCalldata.map { $0.hexString }
    self.signature = tx.signature.map { $0.hexString }
    self.nonce = tx.nonce.hexString
    self.resourceBounds = ResourceBoundsParam(bounds: tx.resourceBounds)
    self.tip = "0x" + String(tx.tip, radix: 16)
    self.paymasterData = tx.paymasterData.map { $0.hexString }
    self.nonceDataAvailabilityMode = tx.nonceDAMode == .l1 ? "L1" : "L2"
    self.feeDataAvailabilityMode = tx.feeDAMode == .l1 ? "L1" : "L2"
  }
}

// MARK: - Resource Bounds Param

struct ResourceBoundsParam: Encodable, Sendable {
  let l1Gas: ResourceBoundParam
  let l2Gas: ResourceBoundParam
  let l1DataGas: ResourceBoundParam

  enum CodingKeys: String, CodingKey {
    case l1Gas = "l1_gas"
    case l2Gas = "l2_gas"
    case l1DataGas = "l1_data_gas"
  }

  init(bounds: StarknetResourceBoundsMapping) {
    self.l1Gas = ResourceBoundParam(bound: bounds.l1Gas)
    self.l2Gas = ResourceBoundParam(bound: bounds.l2Gas)
    self.l1DataGas = ResourceBoundParam(bound: bounds.l1DataGas)
  }
}

struct ResourceBoundParam: Encodable, Sendable {
  let maxAmount: String
  let maxPricePerUnit: String

  enum CodingKeys: String, CodingKey {
    case maxAmount = "max_amount"
    case maxPricePerUnit = "max_price_per_unit"
  }

  init(bound: StarknetResourceBounds) {
    self.maxAmount = "0x" + String(bound.maxAmount, radix: 16)
    self.maxPricePerUnit = "0x" + String(bound.maxPricePerUnit, radix: 16)
  }
}

// MARK: - Event Filter

public struct StarknetEventFilter: Encodable, Sendable {
  public let fromBlock: StarknetBlockId
  public let toBlock: StarknetBlockId
  public let address: String?
  public let keys: [[String]]?
  public let chunkSize: Int
  public let continuationToken: String?

  enum CodingKeys: String, CodingKey {
    case fromBlock = "from_block"
    case toBlock = "to_block"
    case address, keys
    case chunkSize = "chunk_size"
    case continuationToken = "continuation_token"
  }

  public init(
    fromBlock: StarknetBlockId = .latest,
    toBlock: StarknetBlockId = .latest,
    address: Felt? = nil,
    keys: [[Felt]]? = nil,
    chunkSize: Int = 100,
    continuationToken: String? = nil
  ) {
    self.fromBlock = fromBlock
    self.toBlock = toBlock
    self.address = address?.hexString
    self.keys = keys?.map { $0.map { $0.hexString } }
    self.chunkSize = chunkSize
    self.continuationToken = continuationToken
  }
}

// MARK: - Fee Estimate Response

public struct StarknetFeeEstimate: Decodable, Sendable, Equatable {
  // Legacy (older RPCs)
  public let gasConsumed: String?
  public let gasPrice: String?
  public let dataGasConsumed: String?
  public let dataGasPrice: String?

  // Current Starknet spec (e.g. Infura/Alchemy): split by L1/L2
  public let l1GasConsumed: String?
  public let l1GasPrice: String?
  public let l1DataGasConsumed: String?
  public let l1DataGasPrice: String?
  public let l2GasConsumed: String?
  public let l2GasPrice: String?

  public let overallFee: String
  public let feeUnit: String

  enum CodingKeys: String, CodingKey {
    // Legacy keys
    case gasConsumed = "gas_consumed"
    case gasPrice = "gas_price"
    case dataGasConsumed = "data_gas_consumed"
    case dataGasPrice = "data_gas_price"

    // New keys
    case l1GasConsumed = "l1_gas_consumed"
    case l1GasPrice = "l1_gas_price"
    case l1DataGasConsumed = "l1_data_gas_consumed"
    case l1DataGasPrice = "l1_data_gas_price"
    case l2GasConsumed = "l2_gas_consumed"
    case l2GasPrice = "l2_gas_price"

    case overallFee = "overall_fee"

    // Some RPCs use "fee_unit", others use "unit"
    case feeUnit = "fee_unit"
    case unit
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.gasConsumed = try container.decodeIfPresent(String.self, forKey: .gasConsumed)
    self.gasPrice = try container.decodeIfPresent(String.self, forKey: .gasPrice)
    self.dataGasConsumed = try container.decodeIfPresent(String.self, forKey: .dataGasConsumed)
    self.dataGasPrice = try container.decodeIfPresent(String.self, forKey: .dataGasPrice)

    self.l1GasConsumed = try container.decodeIfPresent(String.self, forKey: .l1GasConsumed)
    self.l1GasPrice = try container.decodeIfPresent(String.self, forKey: .l1GasPrice)
    self.l1DataGasConsumed = try container.decodeIfPresent(String.self, forKey: .l1DataGasConsumed)
    self.l1DataGasPrice = try container.decodeIfPresent(String.self, forKey: .l1DataGasPrice)
    self.l2GasConsumed = try container.decodeIfPresent(String.self, forKey: .l2GasConsumed)
    self.l2GasPrice = try container.decodeIfPresent(String.self, forKey: .l2GasPrice)

    self.overallFee = try container.decode(String.self, forKey: .overallFee)

    if let feeUnit = try container.decodeIfPresent(String.self, forKey: .feeUnit) {
      self.feeUnit = feeUnit
    } else if let unit = try container.decodeIfPresent(String.self, forKey: .unit) {
      self.feeUnit = unit
    } else {
      self.feeUnit = ""
    }
  }

  /// The overall fee as a Felt value.
  public var overallFeeFelt: Felt {
    Felt(overallFee) ?? .zero
  }

  /// Prefer L1 fields (new RPCs) but fall back to legacy fields.
  public var effectiveGasConsumed: String? { l1GasConsumed ?? gasConsumed }
  public var effectiveGasPrice: String? { l1GasPrice ?? gasPrice }
  public var effectiveDataGasConsumed: String? { l1DataGasConsumed ?? dataGasConsumed }
  public var effectiveDataGasPrice: String? { l1DataGasPrice ?? dataGasPrice }

  /// Convert fee estimate to resource bounds with a safety multiplier.
  public func toResourceBounds(multiplier: Double = 1.5) -> StarknetResourceBoundsMapping {
    let l1Gas = StarknetResourceBounds(
      maxAmount: parseHexUInt64(effectiveGasConsumed, multiplier: multiplier),
      maxPricePerUnit: parseHexBigUInt(effectiveGasPrice, multiplier: multiplier)
    )
    let l1DataGas = StarknetResourceBounds(
      maxAmount: parseHexUInt64(effectiveDataGasConsumed, multiplier: multiplier),
      maxPricePerUnit: parseHexBigUInt(effectiveDataGasPrice, multiplier: multiplier)
    )
    let l2Gas = StarknetResourceBounds(
      maxAmount: parseHexUInt64(l2GasConsumed, multiplier: multiplier),
      maxPricePerUnit: parseHexBigUInt(l2GasPrice, multiplier: multiplier)
    )
    return StarknetResourceBoundsMapping(l1Gas: l1Gas, l2Gas: l2Gas, l1DataGas: l1DataGas)
  }

  private func parseHexUInt64(_ hex: String?, multiplier: Double) -> UInt64 {
    guard let hex, hex.hasPrefix("0x") else { return 0 }
    let value = UInt64(hex.dropFirst(2), radix: 16) ?? 0
    return UInt64(Double(value) * multiplier)
  }

  private func parseHexBigUInt(_ hex: String?, multiplier: Double) -> BigUInt {
    guard let hex, hex.hasPrefix("0x") else { return 0 }
    let value = BigUInt(hex.dropFirst(2), radix: 16) ?? 0
    return BigUInt(Double(value) * multiplier)
  }
}

// MARK: - Events Response

public struct StarknetEventsResponse: Decodable, Sendable {
  public let events: [StarknetEmittedEventWithContext]
  public let continuationToken: String?

  enum CodingKeys: String, CodingKey {
    case events
    case continuationToken = "continuation_token"
  }
}

public struct StarknetEmittedEventWithContext: Decodable, Sendable, Equatable {
  public let fromAddress: String
  public let keys: [String]
  public let data: [String]
  public let blockHash: String?
  public let blockNumber: UInt64?
  public let transactionHash: String

  enum CodingKeys: String, CodingKey {
    case fromAddress = "from_address"
    case keys, data
    case blockHash = "block_hash"
    case blockNumber = "block_number"
    case transactionHash = "transaction_hash"
  }

  /// Convert hex string keys to Felt array.
  public var feltKeys: [Felt] {
    keys.compactMap { Felt($0) }
  }

  /// Convert hex string data to Felt array.
  public var feltData: [Felt] {
    data.compactMap { Felt($0) }
  }
}

// MARK: - Invoke Transaction Response

public struct StarknetInvokeTransactionResponse: Decodable, Sendable, Equatable {
  public let transactionHash: String

  enum CodingKeys: String, CodingKey {
    case transactionHash = "transaction_hash"
  }

  public var transactionHashFelt: Felt {
    Felt(transactionHash) ?? .zero
  }
}
