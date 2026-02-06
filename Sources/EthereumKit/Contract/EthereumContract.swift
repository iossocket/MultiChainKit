//
//  EthereumContract.swift
//  EthereumKit
//
//  High-level contract interaction API similar to viem's readContract/writeContract
//

import Foundation
import MultiChainCore

// MARK: - EthereumContract

public struct EthereumContract: Sendable {
  public let address: EthereumAddress
  public let abi: [ABIItem]
  public let provider: EthereumProvider

  // MARK: - Init

  public init(address: EthereumAddress, abi: [ABIItem], provider: EthereumProvider) {
    self.address = address
    self.abi = abi
    self.provider = provider
  }

  /// Initialize from JSON ABI string
  public init(address: EthereumAddress, abiJson: String, provider: EthereumProvider) throws {
    guard let data = abiJson.data(using: .utf8) else {
      throw ContractError.invalidABI("Invalid UTF-8 string")
    }
    let items = try JSONDecoder().decode([ABIItem].self, from: data)
    self.init(address: address, abi: items, provider: provider)
  }

  // MARK: - Read Contract (eth_call)

  /// Read contract state (eth_call)
  public func read(
    functionName: String,
    args: [ABIValue] = [],
    block: BlockTag = .latest
  ) async throws -> [ABIValue] {
    let function = try findFunction(name: functionName)
    let calldata = try encodeFunction(function, args: args)

    let tx = EthereumTransaction(
      chainId: provider.chain.chainId,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 0,
      to: address,
      value: .zero,
      data: calldata
    )

    let request = provider.callRequest(transaction: tx, block: block)
    let result: String = try await provider.send(request: request)
    let resultData = Data(hex: String(result.dropFirst(2)))

    return try decodeResult(function, data: resultData)
  }

  /// Read contract and return single value
  public func readSingle<T>(
    functionName: String,
    args: [ABIValue] = [],
    block: BlockTag = .latest
  ) async throws -> T {
    let results = try await read(functionName: functionName, args: args, block: block)
    guard let first = results.first else {
      throw ContractError.emptyResult
    }
    guard let value = first.as(T.self) else {
      throw ContractError.typeMismatch("Cannot convert result to \(T.self)")
    }
    return value
  }

  // MARK: - Encode Write

  /// Encode function call data for write operations
  public func encodeWrite(
    functionName: String,
    args: [ABIValue] = []
  ) throws -> Data {
    let function = try findFunction(name: functionName)
    return try encodeFunction(function, args: args)
  }

  // MARK: - Estimate Gas

  /// Estimate gas for a function call
  public func estimateGas(
    functionName: String,
    args: [ABIValue] = [],
    from: EthereumAddress,
    value: Wei = .zero
  ) async throws -> Wei {
    let calldata = try encodeWrite(functionName: functionName, args: args)

    let tx = EthereumTransaction(
      chainId: provider.chain.chainId,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 0,
      to: address,
      value: value,
      data: calldata
    )

    let request = provider.estimateGasRequest(transaction: tx)
    return try await provider.send(request: request)
  }

  // MARK: - Events

  /// Get and decode event logs
  public func getLogs(
    eventName: String,
    fromBlock: BlockTag = .earliest,
    toBlock: BlockTag = .latest,
    filter: [ABIValue?]? = nil
  ) async throws -> [DecodedLog] {
    let event = try findEvent(name: eventName)

    // Build topics filter
    var topics: [Data?] = [event.topic]
    if let filterValues = filter {
      let encodedTopics = event.encodeTopics(values: filterValues)
      topics.append(contentsOf: encodedTopics.dropFirst())
    }

    let request = getLogsRequest(
      address: address,
      topics: topics,
      fromBlock: fromBlock,
      toBlock: toBlock
    )

    let logs: [EthereumLog] = try await provider.send(request: request)

    return try logs.map { log in
      let topicsData = log.topics.map { Data(hex: String($0.dropFirst(2))) }
      let logData = Data(hex: String(log.data.dropFirst(2)))
      let args = try event.decodeLog(topics: topicsData, data: logData)
      return DecodedLog(log: log, event: event, args: args)
    }
  }

  // MARK: - Private Helpers

  private func findFunction(name: String) throws -> ABIItem {
    guard let function = abi.first(where: { $0.type == .function && $0.name == name }) else {
      throw ContractError.functionNotFound(name)
    }
    return function
  }

  private func findEvent(name: String) throws -> ABIEvent {
    guard let item = abi.first(where: { $0.type == .event && $0.name == name }),
          let event = item.asEvent() else {
      throw ContractError.eventNotFound(name)
    }
    return event
  }

  private func encodeFunction(_ function: ABIItem, args: [ABIValue]) throws -> Data {
    let inputs = function.inputs ?? []

    guard args.count == inputs.count else {
      throw ContractError.argumentCountMismatch(expected: inputs.count, got: args.count)
    }

    guard let selector = function.selector else {
      throw ContractError.invalidABI("Cannot compute function selector")
    }

    let encoded = ABIValue.tuple(args).encode()
    return selector + encoded
  }

  private func decodeResult(_ function: ABIItem, data: Data) throws -> [ABIValue] {
    let outputs = function.outputs ?? []

    if outputs.isEmpty {
      return []
    }

    let types = try outputs.map { param -> ABIType in
      guard let type = try? ABIType.parse(param.type) else {
        throw ContractError.invalidType(param.type)
      }
      return type
    }

    return try ABIValue.decode(types: types, data: data)
  }

  private func getLogsRequest(
    address: EthereumAddress,
    topics: [Data?],
    fromBlock: BlockTag,
    toBlock: BlockTag
  ) -> ChainRequest {
    let topicsArray: [String?] = topics.map { topic in
      topic.map { "0x" + $0.map { String(format: "%02x", $0) }.joined() }
    }

    let filter: [String: Any] = [
      "address": address.checksummed,
      "fromBlock": fromBlock.rawValue,
      "toBlock": toBlock.rawValue,
      "topics": topicsArray
    ]

    return ChainRequest(method: "eth_getLogs", params: [AnyEncodableDict(filter)])
  }
}

// MARK: - AnyEncodableDict

struct AnyEncodableDict: Encodable, @unchecked Sendable {
  private let dict: [String: Any]

  init(_ dict: [String: Any]) {
    self.dict = dict
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (key, value) in dict {
      let codingKey = DynamicCodingKey(stringValue: key)!
      if let str = value as? String {
        try container.encode(str, forKey: codingKey)
      } else if let arr = value as? [String?] {
        try container.encode(arr, forKey: codingKey)
      } else if let bool = value as? Bool {
        try container.encode(bool, forKey: codingKey)
      } else if let int = value as? Int {
        try container.encode(int, forKey: codingKey)
      }
    }
  }
}

struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

// MARK: - DecodedLog

public struct DecodedLog: Sendable {
  public let log: EthereumLog
  public let event: ABIEvent
  public let args: [String: ABIValue]

  public init(log: EthereumLog, event: ABIEvent, args: [String: ABIValue]) {
    self.log = log
    self.event = event
    self.args = args
  }
}

// MARK: - ContractError

public enum ContractError: Error, Sendable {
  case invalidABI(String)
  case functionNotFound(String)
  case eventNotFound(String)
  case argumentCountMismatch(expected: Int, got: Int)
  case invalidType(String)
  case emptyResult
  case typeMismatch(String)
}
