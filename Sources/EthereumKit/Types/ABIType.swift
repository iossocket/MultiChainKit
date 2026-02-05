//
//  ABIType.swift
//  EthereumKit
//
//  ABI type system for parsing and encoding Solidity types.
//  Based on Solidity ABI Specification:
//  https://docs.soliditylang.org/en/v0.8.24/abi-spec.html
//

import Foundation

// MARK: - ABIType

/// Represents a Solidity ABI type
public indirect enum ABIType: Sendable, Equatable {
  /// Unsigned integer: uint8, uint16, ..., uint256
  case uint(Int)

  /// Signed integer: int8, int16, ..., int256
  case int(Int)

  /// Address: 20 bytes
  case address

  /// Boolean
  case bool

  /// Fixed-size bytes: bytes1, bytes2, ..., bytes32
  case fixedBytes(Int)

  /// Dynamic bytes
  case bytes

  /// Dynamic string
  case string

  /// Fixed-size array: T[k]
  case fixedArray(ABIType, Int)

  /// Dynamic array: T[]
  case array(ABIType)

  /// Tuple: (T1, T2, ..., Tn)
  case tuple([ABIType])
}

// MARK: - Type Parsing

extension ABIType {
  /// Parse a type string into ABIType
  public static func parse(_ typeString: String) throws -> ABIType {
    let s = typeString.trimmingCharacters(in: .whitespaces)

    // Handle tuple
    if s.hasPrefix("(") {
      return try parseTuple(s)
    }

    // Handle arrays (must check before base types)
    if let arrayMatch = parseArraySuffix(s) {
      let (baseTypeStr, size) = arrayMatch
      let baseType = try parse(baseTypeStr)
      if let size = size {
        return .fixedArray(baseType, size)
      } else {
        return .array(baseType)
      }
    }

    // Handle base types
    return try parseBaseType(s)
  }

  private static func parseBaseType(_ s: String) throws -> ABIType {
    // uint<M>
    if s.hasPrefix("uint") {
      let bitsStr = String(s.dropFirst(4))
      if bitsStr.isEmpty {
        return .uint(256)  // uint defaults to uint256
      }
      guard let bits = Int(bitsStr), bits >= 8, bits <= 256, bits % 8 == 0 else {
        throw ABITypeError.invalidType(s)
      }
      return .uint(bits)
    }

    // int<M>
    if s.hasPrefix("int") {
      let bitsStr = String(s.dropFirst(3))
      if bitsStr.isEmpty {
        return .int(256)  // int defaults to int256
      }
      guard let bits = Int(bitsStr), bits >= 8, bits <= 256, bits % 8 == 0 else {
        throw ABITypeError.invalidType(s)
      }
      return .int(bits)
    }

    // bytes<M>
    if s.hasPrefix("bytes") {
      let sizeStr = String(s.dropFirst(5))
      if sizeStr.isEmpty {
        return .bytes  // dynamic bytes
      }
      guard let size = Int(sizeStr), size >= 1, size <= 32 else {
        throw ABITypeError.invalidType(s)
      }
      return .fixedBytes(size)
    }

    // Simple types
    switch s {
    case "address":
      return .address
    case "bool":
      return .bool
    case "string":
      return .string
    default:
      throw ABITypeError.invalidType(s)
    }
  }

  /// Parse array suffix, returns (baseType, size?) or nil if not an array
  private static func parseArraySuffix(_ s: String) -> (String, Int?)? {
    guard s.hasSuffix("]") else { return nil }

    // Find matching bracket
    var depth = 0
    var bracketStart: String.Index?

    for (i, char) in s.enumerated().reversed() {
      let index = s.index(s.startIndex, offsetBy: i)
      if char == "]" {
        depth += 1
        if depth == 1 {
          // This is the outermost ]
        }
      } else if char == "[" {
        depth -= 1
        if depth == 0 {
          bracketStart = index
          break
        }
      }
    }

    guard let start = bracketStart else { return nil }

    let baseType = String(s[..<start])
    let sizeStr = String(s[s.index(after: start)..<s.index(before: s.endIndex)])

    if sizeStr.isEmpty {
      return (baseType, nil)  // dynamic array
    } else if let size = Int(sizeStr) {
      return (baseType, size)  // fixed array
    } else {
      return nil
    }
  }

  /// Parse tuple type string
  private static func parseTuple(_ s: String) throws -> ABIType {
    guard s.hasPrefix("(") && s.hasSuffix(")") else {
      throw ABITypeError.invalidType(s)
    }

    let inner = String(s.dropFirst().dropLast())
    if inner.isEmpty {
      return .tuple([])
    }

    let components = try splitTupleComponents(inner)
    let types = try components.map { try parse($0) }
    return .tuple(types)
  }

  /// Split tuple components respecting nested parentheses
  private static func splitTupleComponents(_ s: String) throws -> [String] {
    var components: [String] = []
    var current = ""
    var depth = 0

    for char in s {
      if char == "(" {
        depth += 1
        current.append(char)
      } else if char == ")" {
        depth -= 1
        current.append(char)
      } else if char == "," && depth == 0 {
        components.append(current.trimmingCharacters(in: .whitespaces))
        current = ""
      } else {
        current.append(char)
      }
    }

    if !current.isEmpty {
      components.append(current.trimmingCharacters(in: .whitespaces))
    }

    return components
  }
}

// MARK: - Canonical Name

extension ABIType {
  /// Returns the canonical type name for signature generation
  public var canonicalName: String {
    switch self {
    case .uint(let bits):
      return "uint\(bits)"
    case .int(let bits):
      return "int\(bits)"
    case .address:
      return "address"
    case .bool:
      return "bool"
    case .fixedBytes(let size):
      return "bytes\(size)"
    case .bytes:
      return "bytes"
    case .string:
      return "string"
    case .fixedArray(let elementType, let size):
      return "\(elementType.canonicalName)[\(size)]"
    case .array(let elementType):
      return "\(elementType.canonicalName)[]"
    case .tuple(let components):
      let inner = components.map { $0.canonicalName }.joined(separator: ",")
      return "(\(inner))"
    }
  }
}

// MARK: - ABITypeError

public enum ABITypeError: Error, Sendable {
  case invalidType(String)
  case invalidTuple(String)
}

// MARK: - ABIItem

/// Represents an item in a contract ABI (function, event, error, constructor)
public struct ABIItem: Codable, Sendable {
  public let type: ABIItemType
  public let name: String?
  public let inputs: [ABIParameter]?
  public let outputs: [ABIParameter]?
  public let stateMutability: StateMutability?
  public let anonymous: Bool?

  public init(
    type: ABIItemType,
    name: String? = nil,
    inputs: [ABIParameter]? = nil,
    outputs: [ABIParameter]? = nil,
    stateMutability: StateMutability? = nil,
    anonymous: Bool? = nil
  ) {
    self.type = type
    self.name = name
    self.inputs = inputs
    self.outputs = outputs
    self.stateMutability = stateMutability
    self.anonymous = anonymous
  }
}

// MARK: - ABIItemType

public enum ABIItemType: String, Codable, Sendable {
  case function
  case constructor
  case receive
  case fallback
  case event
  case error
}

// MARK: - StateMutability

public enum StateMutability: String, Codable, Sendable {
  case pure
  case view
  case nonpayable
  case payable
}

// MARK: - ABIParameter

public struct ABIParameter: Codable, Sendable {
  public let name: String
  public let type: String
  public let indexed: Bool?
  public let components: [ABIParameter]?

  public init(
    name: String,
    type: String,
    indexed: Bool? = nil,
    components: [ABIParameter]? = nil
  ) {
    self.name = name
    self.type = type
    self.indexed = indexed
    self.components = components
  }
}

// MARK: - ABIItem Extensions

extension ABIItem {
  /// Returns the function/event/error signature
  public var signature: String? {
    guard let name = name else { return nil }
    let params = inputs ?? []
    let paramTypes = params.map { parameterTypeString($0) }.joined(separator: ",")
    return "\(name)(\(paramTypes))"
  }

  /// Returns the 4-byte function selector
  public var selector: Data? {
    guard let sig = signature else { return nil }
    return ABIValue.functionSelector(sig)
  }

  /// Returns the 32-byte event topic
  public var topic: Data? {
    guard type == .event, let sig = signature else { return nil }
    return Keccak256.hash(sig.data(using: .utf8)!)
  }

  private func parameterTypeString(_ param: ABIParameter) -> String {
    if param.type == "tuple", let components = param.components {
      let inner = components.map { parameterTypeString($0) }.joined(separator: ",")
      return "(\(inner))"
    }

    // Handle tuple arrays like "tuple[]"
    if param.type.hasPrefix("tuple["), let components = param.components {
      let inner = components.map { parameterTypeString($0) }.joined(separator: ",")
      let suffix = String(param.type.dropFirst(5))  // Remove "tuple"
      return "(\(inner))\(suffix)"
    }

    return param.type
  }
}
