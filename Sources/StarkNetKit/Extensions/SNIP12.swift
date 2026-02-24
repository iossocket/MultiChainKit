//
//  SNIP12.swift
//  StarknetKit
//
//  SNIP-12: Typed structured data hashing and signing for Starknet.
//  Analogous to EIP-712 on Ethereum, but uses Pedersen (v0) or Poseidon (v1).
//

import Foundation

// MARK: - SNIP12Value

/// Type-safe value for SNIP-12 typed data.
public indirect enum SNIP12Value: Sendable, Equatable {
  case felt(Felt)
  case shortString(String)
  case bool(Bool)
  case u128(Felt)
  case i128(Felt)
  case contractAddress(Felt)
  case classHash(Felt)
  case timestamp(Felt)
  case selector(String)
  case string(String)
  case `struct`([String: SNIP12Value])
  case array([SNIP12Value])
  case `enum`(variant: String, values: [SNIP12Value])
  case u256(low: Felt, high: Felt)
}

// MARK: - SNIP12Type

/// A single field in a SNIP-12 type definition.
public struct SNIP12Type: Sendable, Equatable {
  public let name: String
  public let type: String

  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }
}

// MARK: - SNIP12Revision

public enum SNIP12Revision: Sendable, Equatable {
  case v0  // Pedersen, StarkNetDomain
  case v1  // Poseidon, StarknetDomain
}

// MARK: - SNIP12Domain

/// Domain separator for SNIP-12.
public struct SNIP12Domain: Sendable, Equatable {
  public let name: String
  public let version: String
  public let chainId: String
  public let revision: SNIP12Revision

  public init(name: String, version: String, chainId: String, revision: SNIP12Revision = .v0) {
    self.name = name
    self.version = version
    self.chainId = chainId
    self.revision = revision
  }

  /// Convenience: create from Felt chainId (e.g. Starknet.mainnet.chainId).
  public init(name: String, version: String, chainId: Felt, revision: SNIP12Revision = .v0) {
    self.name = name
    self.version = version
    // For v0, store the hex string so getHex logic works (numeric parse).
    // For v1, store the short string representation.
    switch revision {
    case .v0:
      self.chainId = chainId.hexString
    case .v1:
      self.chainId = chainId.toShortString()
    }
    self.revision = revision
  }

  /// Compute the domain separator hash.
  public func separator(types: [String: [SNIP12Type]]) throws -> Felt {
    let domainTypeName: String
    let domainData: [String: SNIP12Value]

    switch revision {
    case .v0:
      domainTypeName = "StarkNetDomain"
      domainData = [
        "name": .felt(SNIP12.feltFromStringOrShortString(name)),
        "version": .felt(SNIP12.feltFromStringOrShortString(version)),
        "chainId": .felt(SNIP12.feltFromStringOrShortString(chainId)),
      ]
    case .v1:
      domainTypeName = "StarknetDomain"
      // Match starknet.js: version "1" and revision encode as integer 1 (0x1), not shortstring "1" (0x31)
      let versionFelt: SNIP12Value = (version == "1") ? .felt(Felt(1)) : .shortString(version)
      domainData = [
        "name": .shortString(name),
        "version": versionFelt,
        "chainId": .shortString(chainId),
        "revision": .felt(Felt(1)),
      ]
    }

    return try SNIP12.structHash(domainTypeName, data: domainData, types: types, revision: revision)
  }
}

// MARK: - SNIP12TypedData

/// Complete typed data structure for signing.
public struct SNIP12TypedData: Sendable, Equatable {
  public let types: [String: [SNIP12Type]]
  public let primaryType: String
  public let domain: SNIP12Domain
  public let message: [String: SNIP12Value]

  public init(
    types: [String: [SNIP12Type]],
    primaryType: String,
    domain: SNIP12Domain,
    message: [String: SNIP12Value]
  ) {
    self.types = types
    self.primaryType = primaryType
    self.domain = domain
    self.message = message
  }

  /// Compute the message hash to sign.
  /// hash = hash_array(["StarkNet Message", domainSeparator, accountAddress, messageHash])
  public func messageHash(accountAddress: Felt) throws -> Felt {
    let prefix = Felt.fromShortString("StarkNet Message")
    let domainSep = try domain.separator(types: types)
    let msgHash = try SNIP12.structHash(
      primaryType, data: message, types: types, revision: domain.revision)

    switch domain.revision {
    case .v0:
      return try Pedersen.hashMany([prefix, domainSep, accountAddress, msgHash])
    case .v1:
      return try Poseidon.hashMany([prefix, domainSep, accountAddress, msgHash])
    }
  }
}

// MARK: - SNIP12

/// Core SNIP-12 encoding and hashing functions.
public enum SNIP12 {

  /// Encode type string for a struct.
  /// v0: "TypeName(field1:Type1,field2:Type2)"
  /// v1: "\"TypeName\"(\"field1\":\"Type1\",\"field2\":\"Type2\")"
  public static func encodeType(
    _ primaryType: String,
    types: [String: [SNIP12Type]],
    revision: SNIP12Revision
  ) -> String {
    // Collect all referenced types transitively, excluding the primary type
    var referenced = Set<String>()
    var queue = [primaryType]
    while !queue.isEmpty {
      let current = queue.removeFirst()
      guard let fields = types[current] else { continue }
      for field in fields {
        let baseType = stripArray(field.type)
        if types[baseType] != nil && baseType != primaryType && !referenced.contains(baseType) {
          referenced.insert(baseType)
          queue.append(baseType)
        }
      }
    }

    // Primary type first, then referenced types sorted alphabetically
    var result = encodeSingleType(primaryType, fields: types[primaryType] ?? [], revision: revision)
    for dep in referenced.sorted() {
      result += encodeSingleType(dep, fields: types[dep] ?? [], revision: revision)
    }
    return result
  }

  /// Compute type hash: sn_keccak(encodeType).
  public static func typeHash(
    _ primaryType: String,
    types: [String: [SNIP12Type]],
    revision: SNIP12Revision
  ) -> Felt {
    let encoded = encodeType(primaryType, types: types, revision: revision)
    return StarknetKeccak.hash(Data(encoded.utf8))
  }

  /// Hash a struct: hash_array([typeHash, Enc(field1), Enc(field2), ...]).
  public static func structHash(
    _ primaryType: String,
    data: [String: SNIP12Value],
    types: [String: [SNIP12Type]],
    revision: SNIP12Revision
  ) throws -> Felt {
    guard let fields = types[primaryType] else {
      throw SNIP12Error.unknownType(primaryType)
    }

    var elements: [Felt] = [typeHash(primaryType, types: types, revision: revision)]

    for field in fields {
      guard let value = data[field.name] else {
        throw SNIP12Error.missingField(field.name)
      }
      let encoded = try encodeValue(value, type: field.type, types: types, revision: revision)
      elements.append(encoded)
    }

    switch revision {
    case .v0:
      return try Pedersen.hashMany(elements)
    case .v1:
      return try Poseidon.hashMany(elements)
    }
  }

  /// Encode a single value according to its SNIP-12 type.
  public static func encodeValue(
    _ value: SNIP12Value,
    type: String,
    types: [String: [SNIP12Type]],
    revision: SNIP12Revision
  ) throws -> Felt {
    // Array type: "T*"
    if type.hasSuffix("*") {
      guard case .array(let elements) = value else {
        throw SNIP12Error.typeMismatch(expected: type, got: "non-array")
      }
      let elementType = String(type.dropLast())
      let encoded = try elements.map {
        try encodeValue($0, type: elementType, types: types, revision: revision)
      }
      switch revision {
      case .v0:
        return try Pedersen.hashMany(encoded)
      case .v1:
        return try Poseidon.hashMany(encoded)
      }
    }

    // Struct type (defined in types registry)
    if types[type] != nil {
      guard case .struct(let fields) = value else {
        throw SNIP12Error.typeMismatch(expected: type, got: "non-struct")
      }
      return try structHash(type, data: fields, types: types, revision: revision)
    }

    // Primitive types
    switch type {
    case "felt":
      return extractFelt(value)
    case "bool":
      if case .bool(let b) = value { return b ? Felt.one : Felt.zero }
      return extractFelt(value)
    case "shortstring":
      if case .shortString(let s) = value { return Felt.fromShortString(s) }
      return extractFelt(value)
    case "u128":
      return extractFelt(value)
    case "i128":
      return extractFelt(value)
    case "ContractAddress":
      return extractFelt(value)
    case "ClassHash":
      return extractFelt(value)
    case "timestamp":
      return extractFelt(value)
    case "selector":
      if case .selector(let name) = value { return StarknetKeccak.functionSelector(name) }
      return extractFelt(value)
    case "u256":
      if case .u256(let low, let high) = value {
        // u256 is encoded as two felts hashed together
        switch revision {
        case .v0:
          return try Pedersen.hashMany([low, high])
        case .v1:
          return try Poseidon.hashMany([low, high])
        }
      }
      return extractFelt(value)
    case "string":
      if case .string(let s) = value {
        // Long string: hash the ByteArray encoding
        let bytes = Array(s.utf8)
        var felts: [Felt] = []
        var offset = 0
        while offset + 31 <= bytes.count {
          let chunk = Data(bytes[offset..<offset + 31])
          felts.append(Felt(chunk))
          offset += 31
        }
        let pending = Data(bytes[offset...])
        felts.append(Felt(pending))
        felts.append(Felt(UInt64(bytes.count % 31)))
        switch revision {
        case .v0:
          return try Pedersen.hashMany(felts)
        case .v1:
          return try Poseidon.hashMany(felts)
        }
      }
      return extractFelt(value)
    default:
      throw SNIP12Error.unsupportedType(type)
    }
  }

  // MARK: - Private Helpers

  /// Strip array suffix ("felt*" -> "felt")
  private static func stripArray(_ type: String) -> String {
    type.hasSuffix("*") ? String(type.dropLast()) : type
  }

  /// Encode a single type definition string.
  private static func encodeSingleType(
    _ name: String, fields: [SNIP12Type], revision: SNIP12Revision
  ) -> String {
    let fieldStrings = fields.map { field in
      switch revision {
      case .v0:
        return "\(field.name):\(field.type)"
      case .v1:
        return "\"\(field.name)\":\"\(field.type)\""
      }
    }
    let joined = fieldStrings.joined(separator: ",")
    switch revision {
    case .v0:
      return "\(name)(\(joined))"
    case .v1:
      return "\"\(name)\"(\(joined))"
    }
  }

  /// Extract a Felt from any SNIP12Value variant that wraps a Felt.
  private static func extractFelt(_ value: SNIP12Value) -> Felt {
    switch value {
    case .felt(let f): return f
    case .u128(let f): return f
    case .i128(let f): return f
    case .contractAddress(let f): return f
    case .classHash(let f): return f
    case .timestamp(let f): return f
    case .shortString(let s): return Felt.fromShortString(s)
    case .bool(let b): return b ? Felt.one : Felt.zero
    default: return Felt.zero
    }
  }

  /// Mimic starknet.js `getHex`: try numeric parse first, fall back to shortString.
  /// "1" → Felt(1), "StarkNet Mail" → Felt.fromShortString("StarkNet Mail")
  static func feltFromStringOrShortString(_ string: String) -> Felt {
    if let felt = Felt(string) {
      return felt
    }
    if let num = UInt64(string) {
      return Felt(num)
    }
    return Felt.fromShortString(string)
  }
}

// MARK: - SNIP12Error

public enum SNIP12Error: Error, Sendable, Equatable {
  case unknownType(String)
  case missingField(String)
  case typeMismatch(expected: String, got: String)
  case unsupportedType(String)
  case stringTooLong
}
