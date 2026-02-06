//
//  ABIEvent.swift
//  EthereumKit
//
//  Event encoding and decoding for Ethereum logs.
//

import Foundation

// MARK: - ABIEvent

public struct ABIEvent: Sendable {
  public let name: String
  public let inputs: [ABIParameter]
  public let anonymous: Bool

  public init(name: String, inputs: [ABIParameter], anonymous: Bool = false) {
    self.name = name
    self.inputs = inputs
    self.anonymous = anonymous
  }

  /// Event signature string: "Transfer(address,address,uint256)"
  public var signature: String {
    let paramTypes = inputs.map { parameterTypeString($0) }.joined(separator: ",")
    return "\(name)(\(paramTypes))"
  }

  /// Event topic (keccak256 of signature)
  public var topic: Data {
    Keccak256.hash(signature.data(using: .utf8)!)
  }

  /// Encode indexed parameter values as topics for filtering
  /// - Parameter values: Array of values for indexed parameters (nil = wildcard)
  /// - Returns: Array of topics including topic0 (unless anonymous)
  public func encodeTopics(values: [ABIValue?]) -> [Data?] {
    var topics: [Data?] = []

    // Add topic0 (event signature) unless anonymous
    if !anonymous {
      topics.append(topic)
    }

    // Get indexed parameters
    let indexedParams = inputs.filter { $0.indexed == true }

    // Encode each indexed parameter
    for (i, param) in indexedParams.enumerated() {
      if i < values.count, let value = values[i] {
        let encoded = encodeIndexedValue(value, type: param.type)
        topics.append(encoded)
      } else {
        topics.append(nil)  // wildcard
      }
    }

    return topics
  }

  /// Decode event log data
  /// - Parameters:
  ///   - topics: Log topics array
  ///   - data: Log data (non-indexed parameters)
  /// - Returns: Dictionary of parameter name to decoded value
  public func decodeLog(topics: [Data], data: Data) throws -> [String: ABIValue] {
    var result: [String: ABIValue] = [:]

    // Skip topic0 if not anonymous
    var topicIndex = anonymous ? 0 : 1

    // Separate indexed and non-indexed parameters
    var nonIndexedTypes: [ABIType] = []
    var nonIndexedNames: [String] = []

    for param in inputs {
      if param.indexed == true {
        // Decode from topics
        if topicIndex < topics.count {
          let topicData = topics[topicIndex]
          let value = try decodeIndexedValue(topicData, type: param.type)
          result[param.name] = value
          topicIndex += 1
        }
      } else {
        // Collect for batch decoding from data
        if let abiType = try? ABIType.parse(param.type) {
          nonIndexedTypes.append(abiType)
          nonIndexedNames.append(param.name)
        }
      }
    }

    // Decode non-indexed parameters from data
    if !nonIndexedTypes.isEmpty && !data.isEmpty {
      let decodedValues = try ABIValue.decode(types: nonIndexedTypes, data: data)
      for (i, value) in decodedValues.enumerated() {
        if i < nonIndexedNames.count {
          result[nonIndexedNames[i]] = value
        }
      }
    }

    return result
  }

  // MARK: - Private Helpers

  private func parameterTypeString(_ param: ABIParameter) -> String {
    if param.type == "tuple", let components = param.components {
      let inner = components.map { parameterTypeString($0) }.joined(separator: ",")
      return "(\(inner))"
    }
    if param.type.hasPrefix("tuple["), let components = param.components {
      let inner = components.map { parameterTypeString($0) }.joined(separator: ",")
      let suffix = String(param.type.dropFirst(5))
      return "(\(inner))\(suffix)"
    }
    return param.type
  }

  private func encodeIndexedValue(_ value: ABIValue, type: String) -> Data {
    // For indexed parameters, dynamic types are hashed
    switch value {
    case .string(let str):
      // Indexed strings are keccak256 hashed
      return Keccak256.hash(str.data(using: .utf8) ?? Data())

    case .bytes(let data):
      // Indexed bytes are keccak256 hashed
      return Keccak256.hash(data)

    case .array, .tuple:
      // Indexed arrays/tuples are keccak256 hashed
      return Keccak256.hash(value.encode())

    default:
      // Static types are encoded normally (32 bytes)
      return value.encode()
    }
  }

  private func decodeIndexedValue(_ data: Data, type: String) throws -> ABIValue {
    guard let abiType = try? ABIType.parse(type) else {
      throw ABIDecodingError.typeMismatch
    }

    // For indexed dynamic types, we only have the hash
    switch abiType {
    case .string, .bytes, .array, .tuple:
      // Return the hash as bytes32 since we can't recover the original
      return .fixedBytes(data)

    default:
      // Decode static types normally
      let decoded = try ABIValue.decode(types: [abiType], data: data)
      return decoded.first ?? .fixedBytes(data)
    }
  }
}

// MARK: - ABIItem Extension

extension ABIItem {
  /// Convert ABIItem to ABIEvent if it's an event type
  public func asEvent() -> ABIEvent? {
    guard type == .event, let name = name, let inputs = inputs else {
      return nil
    }
    return ABIEvent(name: name, inputs: inputs, anonymous: anonymous ?? false)
  }
}

// MARK: - EthereumLog Extension

extension EthereumLog {
  /// Decode log using an ABIEvent definition
  public func decode(event: ABIEvent) throws -> [String: ABIValue] {
    // Convert hex topics to Data
    let topicsData = topics.compactMap { topic -> Data? in
      var hex = topic
      if hex.hasPrefix("0x") {
        hex = String(hex.dropFirst(2))
      }
      return Data(hex: hex)
    }

    // Convert hex data to Data
    var logData = data
    if logData.hasPrefix("0x") {
      logData = String(logData.dropFirst(2))
    }
    let dataBytes = Data(hex: logData)

    return try event.decodeLog(topics: topicsData, data: dataBytes)
  }
}
