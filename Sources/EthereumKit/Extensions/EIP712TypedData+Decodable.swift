import BigInt
import Foundation
import MultiChainCore

extension EIP712Type: Decodable {
  private enum CodingKeys: String, CodingKey {
    case name
    case type
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decode(String.self, forKey: .name)
    let type = try container.decode(String.self, forKey: .type)
    self.init(name: name, type: type)
  }
}

extension EIP712Domain: Decodable {
  private enum CodingKeys: String, CodingKey {
    case name
    case version
    case chainId
    case verifyingContract
    case salt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decodeIfPresent(String.self, forKey: .name)
    let version = try container.decodeIfPresent(String.self, forKey: .version)

    var chainId: UInt64? = nil
    if container.contains(.chainId), try !container.decodeNil(forKey: .chainId) {
      let rawChainId = try container.decode(JSONValue.self, forKey: .chainId)
      chainId = try EIP712TypedDataDecoder.parseUInt64(rawChainId)
    }

    let verifyingContract = try container.decodeIfPresent(EthereumAddress.self, forKey: .verifyingContract)

    var salt: Data? = nil
    if let saltString = try container.decodeIfPresent(String.self, forKey: .salt) {
      var hex = saltString
      if hex.hasPrefix("0x") || hex.hasPrefix("0X") { hex = String(hex.dropFirst(2)) }
      guard hex.count == 64 else {
        throw DecodingError.dataCorruptedError(forKey: .salt, in: container, debugDescription: "Salt must be 32 bytes (64 hex chars), got \(hex.count) chars")
      }
      guard hex.count % 2 == 0 else {
        throw DecodingError.dataCorruptedError(forKey: .salt, in: container, debugDescription: "Invalid hex salt: odd length")
      }
      var data = Data()
      var index = hex.startIndex
      while index < hex.endIndex {
        let nextIndex = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
          throw DecodingError.dataCorruptedError(forKey: .salt, in: container, debugDescription: "Invalid hex salt: non-hex character")
        }
        data.append(byte)
        index = nextIndex
      }
      salt = data
    }

    self.init(name: name, version: version, chainId: chainId, verifyingContract: verifyingContract, salt: salt)
  }
}


extension EIP712TypedData: Decodable {
  private enum CodingKeys: String, CodingKey {
    case types
    case primaryType
    case domain
    case message
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let types = try container.decode([String: [EIP712Type]].self, forKey: .types)
    let primaryType = try container.decode(String.self, forKey: .primaryType)
    let domain = try container.decode(EIP712Domain.self, forKey: .domain)
    let messageDict = try container.decode([String: JSONValue].self, forKey: .message)
    let message = try EIP712TypedDataDecoder.parseRoot(
      messageDict,
      primaryType: primaryType,
      types: types
    )
    self.init(types: types, primaryType: primaryType, domain: domain, message: message)
  }
}

// MARK: - Private Decoder

private enum EIP712TypedDataDecoder {
  /// DFS root: parse the top-level message object using primaryType as the schema root.
  static func parseRoot(
    _ raw: [String: JSONValue],
    primaryType: String,
    types: [String: [EIP712Type]]
  ) throws -> [String: EIP712Value] {
    try parseStructFields(raw, typeName: primaryType, types: types)
  }

  /// Visit a struct branch: each field is a child node described by the type registry.
  static func parseStructFields(
    _ raw: [String: JSONValue],
    typeName: String,
    types: [String: [EIP712Type]]
  ) throws -> [String: EIP712Value] {
    guard let fields = types[typeName] else {
      throw unknownType(typeName)
    }
    var result: [String: EIP712Value] = [:]
    for field in fields {
      guard let rawValue = raw[field.name] else {
        throw missingField(field.name, in: typeName)
      }
      result[field.name] = try parseNode(rawValue, type: field.type, types: types)
    }
    return result
  }

  /// DFS visit function: dispatch the current JSON node by its EIP-712 type.
  static func parseNode(
    _ raw: JSONValue,
    type: String,
    types: [String: [EIP712Type]]
  ) throws -> EIP712Value {
    if isArrayType(type) {
      return try parseArrayNode(raw, type: type, types: types)
    }
    if types[type] != nil {
      return try parseStructNode(raw, typeName: type, types: types)
    }
    return try parseLeaf(raw, type: type)
  }

  /// Visit a struct node value and wrap its parsed children as `.struct`.
  static func parseStructNode(
    _ raw: JSONValue,
    typeName: String,
    types: [String: [EIP712Type]]
  ) throws -> EIP712Value {
    guard case .object(let object) = raw else {
      throw typeMismatch(expected: typeName, got: raw)
    }
    return .struct(try parseStructFields(object, typeName: typeName, types: types))
  }

  /// Visit an array branch: every element is a child node with the element type.
  static func parseArrayNode(
    _ raw: JSONValue,
    type: String,
    types: [String: [EIP712Type]]
  ) throws -> EIP712Value {
    guard case .array(let elements) = raw else {
      throw typeMismatch(expected: type, got: raw)
    }
    if let expectedCount = try fixedArrayLength(from: type), elements.count != expectedCount {
      throw invalidValue("Fixed array size mismatch for \(type): expected \(expectedCount), got \(elements.count)")
    }
    let elementType = try self.arrayElementType(from: type)
    let parsed = try elements.map { try parseNode($0, type: elementType, types: types) }
    return .array(parsed)
  }

  /// Visit a primitive leaf node and convert it to the matching `EIP712Value`.
  static func parseLeaf(
    _ raw: JSONValue,
    type: String
  ) throws -> EIP712Value {
    switch type {
    case "string":
      return .string(try parseString(raw))
    case "bool":
      return .bool(try parseBool(raw))
    case "address":
      return .address(try parseAddress(raw))
    case "bytes":
      return .bytes(try parseBytes(raw))
    default:
      if type.hasPrefix("bytes"), type != "bytes" {
        if let size = fixedBytesLength(from: type) {
          return .fixedBytes(try parseFixedBytes(raw, size: size))
        }
      }
      if let _ = uintBitWidth(from: type) {
        return .uint(try parseWei(raw))
      }
      if let _ = intBitWidth(from: type) {
        return .int(try parseWei(raw))
      }
      throw unknownType(type)
    }
  }
}

// MARK: - Type Helpers

private extension EIP712TypedDataDecoder {
  static func isArrayType(_ type: String) -> Bool {
    type.contains("[") && type.hasSuffix("]")
  }

  static func arrayElementType(from type: String) throws -> String {
    guard let lastBracketIndex = type.lastIndex(of: "[") else {
      throw invalidValue("Type \(type) is not an array type")
    }
    return String(type[..<lastBracketIndex])
  }

  static func fixedArrayLength(from type: String) throws -> Int? {
    guard let start = type.lastIndex(of: "["), type.hasSuffix("]") else {
      throw invalidValue("Type \(type) is not an array type")
    }
    let end = type.index(before: type.endIndex)
    let lengthString = String(type[type.index(after: start)..<end])
    if lengthString.isEmpty { return nil }
    guard let length = Int(lengthString), length >= 0 else {
      throw invalidValue("Invalid fixed array length in type \(type)")
    }
    return length
  }

  static func fixedBytesLength(from type: String) -> Int? {
    guard type.hasPrefix("bytes"), type.count > 5 else { return nil }
    let numStr = String(type.dropFirst(5))
    guard let size = Int(numStr), size >= 1, size <= 32 else { return nil }
    return size
  }

  static func uintBitWidth(from type: String) -> Int? {
    guard type.hasPrefix("uint") else { return nil }
    if type == "uint" { return 256 }
    let numStr = String(type.dropFirst(4))
    guard let bits = Int(numStr), bits >= 8, bits <= 256, bits.isMultiple(of: 8) else {
      return nil
    }
    return bits
  }

  static func intBitWidth(from type: String) -> Int? {
    guard type.hasPrefix("int") else { return nil }
    if type == "int" { return 256 }
    let numStr = String(type.dropFirst(3))
    guard let bits = Int(numStr), bits >= 8, bits <= 256, bits.isMultiple(of: 8) else {
      return nil
    }
    return bits
  }
}

// MARK: - Primitive Helpers

private extension EIP712TypedDataDecoder {
  static func parseString(_ raw: JSONValue) throws -> String {
    guard case .string(let value) = raw else {
      throw typeMismatch(expected: "string", got: raw)
    }
    return value
  }

  static func parseBool(_ raw: JSONValue) throws -> Bool {
    guard case .bool(let value) = raw else {
      throw typeMismatch(expected: "bool", got: raw)
    }
    return value
  }

  static func parseAddress(_ raw: JSONValue) throws -> EthereumAddress {
    let addrString = try parseString(raw)
    guard let address = EthereumAddress(addrString) else {
      throw invalidValue("Invalid address: \(addrString)")
    }
    return address
  }

  static func parseBytes(_ raw: JSONValue) throws -> Data {
    var hexString = try parseString(raw)
    if hexString.hasPrefix("0x") || hexString.hasPrefix("0X") {
      hexString = String(hexString.dropFirst(2))
    }
    guard hexString.count % 2 == 0 else {
      throw invalidValue("Invalid hex string: odd length")
    }
    var data = Data()
    var index = hexString.startIndex
    while index < hexString.endIndex {
      let nextIndex = hexString.index(index, offsetBy: 2)
      let byteStr = String(hexString[index..<nextIndex])
      guard let byte = UInt8(byteStr, radix: 16) else {
        throw invalidValue("Invalid hex byte: \(byteStr)")
      }
      data.append(byte)
      index = nextIndex
    }
    return data
  }

  static func parseFixedBytes(_ raw: JSONValue, size: Int) throws -> Data {
    let data = try parseBytes(raw)
    guard data.count == size else {
      throw invalidValue("FixedBytes size mismatch: expected \(size), got \(data.count)")
    }
    return data
  }

  static func parseWei(_ raw: JSONValue) throws -> Wei {
    switch raw {
    case .string(let str):
      if str.hasPrefix("0x") || str.hasPrefix("0X") {
        guard let wei = Wei(str) else {
          throw invalidValue("Invalid hex Wei: \(str)")
        }
        return wei
      } else {
        guard let value = BigUInt(str) else {
          throw invalidValue("Invalid decimal Wei: \(str)")
        }
        return Wei(value)
      }
    case .number(let num):
      let value = try parseFiniteUInt64Number(num, expected: "uint/int")
      return Wei(value)
    default:
      throw typeMismatch(expected: "uint/int", got: raw)
    }
  }

  static func parseUInt64(_ raw: JSONValue) throws -> UInt64 {
    switch raw {
    case .string(let str):
      if str.hasPrefix("0x") || str.hasPrefix("0X") {
        guard let value = UInt64(str.dropFirst(2), radix: 16) else {
          throw invalidValue("Invalid hex UInt64: \(str)")
        }
        return value
      } else {
        guard let value = UInt64(str) else {
          throw invalidValue("Invalid decimal UInt64: \(str)")
        }
        return value
      }
    case .number(let num):
      return try parseFiniteUInt64Number(num, expected: "UInt64")
    default:
      throw typeMismatch(expected: "UInt64", got: raw)
    }
  }

  static func parseFiniteUInt64Number(_ num: Double, expected: String) throws -> UInt64 {
    let maxSafeInteger = 9_007_199_254_740_991.0
    guard num.isFinite, num >= 0, num.rounded(.towardZero) == num, num <= maxSafeInteger else {
      throw invalidValue("Invalid \(expected) number: \(num)")
    }
    return UInt64(num)
  }
}

// MARK: - Error Helpers

private extension EIP712TypedDataDecoder {
  static func unknownType(_ type: String) -> DecodingError {
    DecodingError.typeMismatch(
      EIP712Value.self,
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Unknown EIP712 type: \(type)"
      )
    )
  }

  static func missingField(_ field: String, in typeName: String) -> DecodingError {
    struct StringCodingKey: CodingKey {
      var stringValue: String
      var intValue: Int? { nil }
      init(stringValue: String) { self.stringValue = stringValue }
      init?(intValue: Int) { nil }
    }
    return DecodingError.keyNotFound(
      StringCodingKey(stringValue: field),
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Missing field '\(field)' in type '\(typeName)'"
      )
    )
  }

  static func typeMismatch(expected: String, got raw: JSONValue) -> DecodingError {
    DecodingError.typeMismatch(
      EIP712Value.self,
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Expected \(expected), got \(raw)"
      )
    )
  }

  static func invalidValue(_ message: String) -> DecodingError {
    DecodingError.valueNotFound(
      EIP712Value.self,
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Invalid value: \(message)"
      )
    )
  }
}
