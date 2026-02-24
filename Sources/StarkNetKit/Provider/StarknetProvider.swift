//
//  StarknetProvider.swift
//  StarknetKit
//

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

  // MARK: - Chain State

  public func chainIdRequest() -> ChainRequest {
    ChainRequest(method: "starknet_chainId")
  }

  public func blockNumberRequest() -> ChainRequest {
    ChainRequest(method: "starknet_blockNumber")
  }

  public func blockHashAndNumberRequest() -> ChainRequest {
    ChainRequest(method: "starknet_blockHashAndNumber")
  }

  public func syncing() -> ChainRequest {
    ChainRequest(method: "starknet_syncing")
  }

  // MARK: - Account State

  public func getNonceRequest(address: StarknetAddress, block: StarknetBlockId = .latest)
    -> ChainRequest
  {
    ChainRequest(method: "starknet_getNonce", params: [block, address.checksummed])
  }

  public func getClassHashAtRequest(address: StarknetAddress, block: StarknetBlockId = .latest)
    -> ChainRequest
  {
    ChainRequest(method: "starknet_getClassHashAt", params: [block, address.checksummed])
  }

  // MARK: - Contract Calls

  public func callRequest(call: StarknetCall, block: StarknetBlockId = .latest) -> ChainRequest {
    let callObj = StarknetCallParam(
      contractAddress: call.contractAddress.hexString,
      entryPointSelector: call.entryPointSelector.hexString,
      calldata: call.calldata.map { $0.hexString }
    )
    return ChainRequest(method: "starknet_call", params: [callObj, block])
  }

  // MARK: - Fee Estimation

  public func estimateFeeRequest(invokeV1: StarknetInvokeV1) -> ChainRequest {
    let tx = StarknetInvokeV1Param(tx: invokeV1)
    let txArray = [tx] as [StarknetInvokeV1Param]
    let simFlags = ["SKIP_VALIDATE"] as [String]
    return ChainRequest(method: "starknet_estimateFee", params: [txArray, simFlags])
  }

  public func estimateFeeRequest(invokeV3: StarknetInvokeV3) -> ChainRequest {
    let tx = StarknetInvokeV3Param(tx: invokeV3)
    let txArray = [tx] as [StarknetInvokeV3Param]
    let simFlags = ["SKIP_VALIDATE"] as [String]
    return ChainRequest(method: "starknet_estimateFee", params: [txArray, simFlags])
  }

  // MARK: - Send Transactions

  public func addInvokeTransactionRequest(invokeV1: StarknetInvokeV1) -> ChainRequest {
    let tx = StarknetInvokeV1Param(tx: invokeV1)
    return ChainRequest(method: "starknet_addInvokeTransaction", params: [tx])
  }

  public func addInvokeTransactionRequest(invokeV3: StarknetInvokeV3) -> ChainRequest {
    let tx = StarknetInvokeV3Param(tx: invokeV3)
    return ChainRequest(method: "starknet_addInvokeTransaction", params: [tx])
  }

  public func addDeployAccountTransactionRequest(deployV1: StarknetDeployAccountV1) -> ChainRequest
  {
    let tx = StarknetDeployAccountV1Param(tx: deployV1)
    return ChainRequest(method: "starknet_addDeployAccountTransaction", params: [tx])
  }

  public func addDeployAccountTransactionRequest(deployV3: StarknetDeployAccountV3) -> ChainRequest
  {
    let tx = StarknetDeployAccountV3Param(tx: deployV3)
    return ChainRequest(method: "starknet_addDeployAccountTransaction", params: [tx])
  }

  // MARK: - Events

  public func getEventsRequest(filter: StarknetEventFilter) -> ChainRequest {
    ChainRequest(method: "starknet_getEvents", params: [filter])
  }

  // MARK: - Transaction Queries

  public func getTransactionByHashRequest(hash: Felt) -> ChainRequest {
    ChainRequest(method: "starknet_getTransactionByHash", params: [hash.hexString])
  }

  public func getTransactionReceiptRequest(hash: Felt) -> ChainRequest {
    ChainRequest(method: "starknet_getTransactionReceipt", params: [hash.hexString])
  }

  public func getTransactionStatusRequest(hash: Felt) -> ChainRequest {
    ChainRequest(method: "starknet_getTransactionStatus", params: [hash.hexString])
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
        status = try await send(request: getTransactionStatusRequest(hash: hash))
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
        return try await send(request: getTransactionReceiptRequest(hash: hash))
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
  public let gasConsumed: String
  public let gasPrice: String
  public let dataGasConsumed: String
  public let dataGasPrice: String
  public let overallFee: String
  public let feeUnit: String

  enum CodingKeys: String, CodingKey {
    case gasConsumed = "gas_consumed"
    case gasPrice = "gas_price"
    case dataGasConsumed = "data_gas_consumed"
    case dataGasPrice = "data_gas_price"
    case overallFee = "overall_fee"
    case feeUnit = "fee_unit"
  }

  /// The overall fee as a Felt value.
  public var overallFeeFelt: Felt {
    Felt(overallFee) ?? .zero
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
