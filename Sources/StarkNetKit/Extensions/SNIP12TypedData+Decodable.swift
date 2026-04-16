import BigInt
import Foundation
import MultiChainCore

extension SNIP12Type: Decodable {
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

extension SNIP12Revision: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Int.self) {
      self = try Self.parse(number)
      return
    }
    if let string = try? container.decode(String.self) {
      self = try Self.parse(string)
      return
    }
    throw DecodingError.typeMismatch(
      SNIP12Revision.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Expected SNIP-12 revision as 0, 1, \"0\", \"1\", \"v0\", or \"v1\""
      )
    )
  }

  private static func parse(_ number: Int) throws -> SNIP12Revision {
    switch number {
    case 0: return .v0
    case 1: return .v1
    default:
      throw DecodingError.valueNotFound(
        SNIP12Revision.self,
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Invalid SNIP-12 revision: \(number)"
        )
      )
    }
  }

  private static func parse(_ string: String) throws -> SNIP12Revision {
    switch string.lowercased() {
    case "0", "v0": return .v0
    case "1", "v1": return .v1
    default:
      throw DecodingError.valueNotFound(
        SNIP12Revision.self,
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Invalid SNIP-12 revision: \(string)"
        )
      )
    }
  }
}

extension SNIP12Domain: Decodable {
  private enum CodingKeys: String, CodingKey {
    case name
    case version
    case chainId
    case revision
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decode(String.self, forKey: .name)
    let version = try container.decode(String.self, forKey: .version)
    let chainIdRaw = try container.decode(JSONValue.self, forKey: .chainId)
    let chainId = try SNIP12TypedDataDecoder.parseDomainString(chainIdRaw, field: "chainId")
    let revision = try container.decodeIfPresent(SNIP12Revision.self, forKey: .revision) ?? .v0
    self.init(name: name, version: version, chainId: chainId, revision: revision)
  }
}

extension SNIP12TypedData: Decodable {
  private enum CodingKeys: String, CodingKey {
    case types
    case primaryType
    case domain
    case message
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let types = try container.decode([String: [SNIP12Type]].self, forKey: .types)
    let primaryType = try container.decode(String.self, forKey: .primaryType)
    let domain = try container.decode(SNIP12Domain.self, forKey: .domain)
    let messageDict = try container.decode([String: JSONValue].self, forKey: .message)
    let message = try SNIP12TypedDataDecoder.parseRoot(
      messageDict,
      primaryType: primaryType,
      types: types
    )
    self.init(types: types, primaryType: primaryType, domain: domain, message: message)
  }
}

// MARK: - Private Decoder

private enum SNIP12TypedDataDecoder {
  /// DFS root: parse the top-level message object using primaryType as the schema root.
  static func parseRoot(
    _ raw: [String: JSONValue],
    primaryType: String,
    types: [String: [SNIP12Type]]
  ) throws -> [String: SNIP12Value] {
    try parseStructFields(raw, typeName: primaryType, types: types)
  }

  /// Visit a struct branch: each field is a child node described by the type registry.
  static func parseStructFields(
    _ raw: [String: JSONValue],
    typeName: String,
    types: [String: [SNIP12Type]]
  ) throws -> [String: SNIP12Value] {
    guard let fields = types[typeName] else {
      throw unknownType(typeName)
    }
    var result: [String: SNIP12Value] = [:]
    for field in fields {
      guard let rawValue = raw[field.name] else {
        throw missingField(field.name, in: typeName)
      }
      result[field.name] = try parseNode(rawValue, type: field.type, types: types)
    }
    return result
  }

  /// DFS visit function: dispatch the current JSON node by its SNIP-12 type.
  static func parseNode(
    _ raw: JSONValue,
    type: String,
    types: [String: [SNIP12Type]]
  ) throws -> SNIP12Value {
    if isArrayType(type) {
      return try parseArrayNode(raw, type: type, types: types)
    }
    if types[type] != nil {
      if isTypedEnumObject(raw, enumType: type, types: types) {
        return try parseTypedEnumNode(raw, enumType: type, types: types)
      }
      return try parseStructNode(raw, typeName: type, types: types)
    }
    return try parseLeaf(raw, type: type)
  }

  /// Visit a struct node value and wrap its parsed children as `.struct`.
  static func parseStructNode(
    _ raw: JSONValue,
    typeName: String,
    types: [String: [SNIP12Type]]
  ) throws -> SNIP12Value {
    guard case .object(let object) = raw else {
      throw typeMismatch(expected: typeName, got: raw)
    }
    return .struct(try parseStructFields(object, typeName: typeName, types: types))
  }

  /// Visit an array branch: every element is a child node with the element type.
  static func parseArrayNode(
    _ raw: JSONValue,
    type: String,
    types: [String: [SNIP12Type]]
  ) throws -> SNIP12Value {
    guard case .array(let elements) = raw else {
      throw typeMismatch(expected: type, got: raw)
    }
    let elementType = try arrayElementType(from: type)
    let parsed = try elements.map { try parseNode($0, type: elementType, types: types) }
    return .array(parsed)
  }

  /// Visit a typed enum branch using the selected variant's type list as child schemas.
  static func parseTypedEnumNode(
    _ raw: JSONValue,
    enumType: String,
    types: [String: [SNIP12Type]]
  ) throws -> SNIP12Value {
    guard case .object(let object) = raw else {
      throw typeMismatch(expected: enumType, got: raw)
    }
    let variant = try parseEnumVariant(object, enumType: enumType)
    guard let variantType = types[enumType]?.first(where: { $0.name == variant })?.type else {
      throw invalidValue("Unknown enum variant \(variant) for \(enumType)")
    }
    let values = try parseEnumValues(object)
    let valueTypes = try enumValueTypes(from: variantType)
    guard values.count == valueTypes.count else {
      throw invalidValue(
        "Enum variant \(variant) expects \(valueTypes.count) value(s), got \(values.count)"
      )
    }
    let parsed = try zip(values, valueTypes).map { rawValue, valueType in
      try parseNode(rawValue, type: valueType, types: types)
    }
    return .enum(variant: variant, values: parsed)
  }

  /// Visit a primitive leaf node and convert it to the matching `SNIP12Value`.
  static func parseLeaf(
    _ raw: JSONValue,
    type: String
  ) throws -> SNIP12Value {
    switch type {
    case "felt":
      return .felt(try parseFelt(raw, allowShortString: true))
    case "bool":
      return .bool(try parseBool(raw))
    case "shortstring":
      return .shortString(try parseShortString(raw))
    case "u128":
      return .u128(try parseUint(raw, bitWidth: 128, type: type))
    case "i128":
      return .i128(try parseInt(raw, bitWidth: 128, type: type))
    case "ContractAddress":
      return .contractAddress(try parseFelt(raw))
    case "ClassHash":
      return .classHash(try parseFelt(raw))
    case "timestamp":
      return .timestamp(try parseFelt(raw))
    case "selector":
      return .selector(try parseString(raw))
    case "string":
      return .string(try parseString(raw))
    case "u256":
      let parts = try parseU256(raw)
      return .u256(low: parts.low, high: parts.high)
    case "enum":
      return try parseUntypedEnum(raw)
    default:
      throw unknownType(type)
    }
  }
}

// MARK: - Type Helpers

private extension SNIP12TypedDataDecoder {
  static func isArrayType(_ type: String) -> Bool {
    type.hasSuffix("*")
  }

  static func arrayElementType(from type: String) throws -> String {
    guard isArrayType(type), type.count > 1 else {
      throw invalidValue("Type \(type) is not an array type")
    }
    return String(type.dropLast())
  }

  static func isEnumObject(_ raw: JSONValue) -> Bool {
    guard case .object(let object) = raw else { return false }
    return object["variant"] != nil && (object["values"] != nil || object["value"] != nil)
  }

  static func isTypedEnumObject(
    _ raw: JSONValue,
    enumType: String,
    types: [String: [SNIP12Type]]
  ) -> Bool {
    guard case .object(let object) = raw,
      let rawVariant = object["variant"],
      case .string(let variant) = rawVariant,
      let variantType = types[enumType]?.first(where: { $0.name == variant })?.type
    else {
      return false
    }
    return variantType == "()" || object["values"] != nil || object["value"] != nil
  }

  static func enumValueTypes(from type: String) throws -> [String] {
    if type == "()" { return [] }
    if type.hasPrefix("("), type.hasSuffix(")") {
      let start = type.index(after: type.startIndex)
      let end = type.index(before: type.endIndex)
      let inner = String(type[start..<end])
      if inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
      return inner.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    return [type]
  }
}

// MARK: - Primitive Helpers

private extension SNIP12TypedDataDecoder {
  static func parseString(_ raw: JSONValue) throws -> String {
    guard case .string(let value) = raw else {
      throw typeMismatch(expected: "string", got: raw)
    }
    return value
  }

  static func parseShortString(_ raw: JSONValue) throws -> String {
    let value = try parseString(raw)
    guard value.utf8.count <= 31 else {
      throw invalidValue("Shortstring must be at most 31 bytes")
    }
    return value
  }

  static func parseBool(_ raw: JSONValue) throws -> Bool {
    guard case .bool(let value) = raw else {
      throw typeMismatch(expected: "bool", got: raw)
    }
    return value
  }

  static func parseFelt(_ raw: JSONValue, allowShortString: Bool = false) throws -> Felt {
    if case .string(let string) = raw, allowShortString, !isNumericString(string) {
      return Felt.fromShortString(try parseShortString(raw))
    }
    return Felt(try parseFeltBigUInt(raw))
  }

  static func parseUint(_ raw: JSONValue, bitWidth: Int, type: String) throws -> Felt {
    let value = try parseFeltBigUInt(raw)
    let upperBound = BigUInt(1) << bitWidth
    guard value < upperBound else {
      throw invalidValue("\(type) out of range")
    }
    return Felt(value)
  }

  static func parseInt(_ raw: JSONValue, bitWidth: Int, type: String) throws -> Felt {
    let value = try parseFeltBigUInt(raw)
    let upperBound = BigUInt(1) << (bitWidth - 1)
    guard value < upperBound else {
      throw invalidValue("\(type) out of range")
    }
    return Felt(value)
  }

  static func parseU256(_ raw: JSONValue) throws -> (low: Felt, high: Felt) {
    switch raw {
    case .object(let object):
      guard let low = object["low"] else {
        throw missingField("low", in: "u256")
      }
      guard let high = object["high"] else {
        throw missingField("high", in: "u256")
      }
      return (
        low: try parseUint(low, bitWidth: 128, type: "u256.low"),
        high: try parseUint(high, bitWidth: 128, type: "u256.high")
      )
    case .array(let values):
      guard values.count == 2 else {
        throw invalidValue("u256 array must contain [low, high]")
      }
      return (
        low: try parseUint(values[0], bitWidth: 128, type: "u256.low"),
        high: try parseUint(values[1], bitWidth: 128, type: "u256.high")
      )
    default:
      throw typeMismatch(expected: "u256", got: raw)
    }
  }

  static func parseDomainString(_ raw: JSONValue, field: String) throws -> String {
    switch raw {
    case .string(let value):
      return value
    case .number(let number):
      return String(try parseFiniteUInt64Number(number, expected: field))
    default:
      throw typeMismatch(expected: field, got: raw)
    }
  }

  static func parseFeltBigUInt(_ raw: JSONValue) throws -> BigUInt {
    let value: BigUInt
    switch raw {
    case .string(let string):
      value = try parseBigUIntString(string)
    case .number(let number):
      value = BigUInt(try parseFiniteUInt64Number(number, expected: "felt"))
    default:
      throw typeMismatch(expected: "felt", got: raw)
    }
    guard value < Felt.PRIME else {
      throw invalidValue("Felt is out of field range")
    }
    return value
  }

  static func parseBigUIntString(_ string: String) throws -> BigUInt {
    if string.hasPrefix("0x") || string.hasPrefix("0X") {
      guard let value = BigUInt(String(string.dropFirst(2)), radix: 16) else {
        throw invalidValue("Invalid hex integer: \(string)")
      }
      return value
    }
    guard let value = BigUInt(string, radix: 10) else {
      throw invalidValue("Invalid decimal integer: \(string)")
    }
    return value
  }

  static func parseFiniteUInt64Number(_ number: Double, expected: String) throws -> UInt64 {
    let maxSafeInteger = 9_007_199_254_740_991.0
    guard number.isFinite, number >= 0, number.rounded(.towardZero) == number,
      number <= maxSafeInteger
    else {
      throw invalidValue("Invalid \(expected) number: \(number)")
    }
    return UInt64(number)
  }

  static func isNumericString(_ string: String) -> Bool {
    if string.hasPrefix("0x") || string.hasPrefix("0X") {
      return BigUInt(String(string.dropFirst(2)), radix: 16) != nil
    }
    return BigUInt(string, radix: 10) != nil
  }
}

// MARK: - Enum Helpers

private extension SNIP12TypedDataDecoder {
  static func parseUntypedEnum(_ raw: JSONValue) throws -> SNIP12Value {
    guard case .object(let object) = raw else {
      throw typeMismatch(expected: "enum", got: raw)
    }
    let variant = try parseEnumVariant(object, enumType: "enum")
    let values = try parseEnumValues(object)
    return .enum(variant: variant, values: try values.map(parseUntypedEnumValue))
  }

  static func parseEnumVariant(_ object: [String: JSONValue], enumType: String) throws -> String {
    guard let rawVariant = object["variant"] else {
      throw missingField("variant", in: enumType)
    }
    return try parseString(rawVariant)
  }

  static func parseEnumValues(_ object: [String: JSONValue]) throws -> [JSONValue] {
    if let values = object["values"] {
      guard case .array(let array) = values else {
        throw typeMismatch(expected: "enum values", got: values)
      }
      return array
    }
    if let value = object["value"] {
      return [value]
    }
    return []
  }

  static func parseUntypedEnumValue(_ raw: JSONValue) throws -> SNIP12Value {
    switch raw {
    case .string(let value):
      if isNumericString(value) {
        return .felt(try parseFelt(raw))
      }
      return .shortString(try parseShortString(raw))
    case .number:
      return .felt(try parseFelt(raw))
    case .bool(let value):
      return .bool(value)
    case .array(let values):
      return .array(try values.map(parseUntypedEnumValue))
    case .object(let object):
      if isEnumObject(raw) {
        return try parseUntypedEnum(raw)
      }
      var result: [String: SNIP12Value] = [:]
      for (key, value) in object {
        result[key] = try parseUntypedEnumValue(value)
      }
      return .struct(result)
    case .null:
      throw invalidValue("Enum values cannot contain null")
    }
  }
}

// MARK: - Error Helpers

private extension SNIP12TypedDataDecoder {
  static func unknownType(_ type: String) -> DecodingError {
    DecodingError.typeMismatch(
      SNIP12Value.self,
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Unknown SNIP12 type: \(type)"
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
      SNIP12Value.self,
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Expected \(expected), got \(raw)"
      )
    )
  }

  static func invalidValue(_ message: String) -> DecodingError {
    DecodingError.valueNotFound(
      SNIP12Value.self,
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Invalid value: \(message)"
      )
    )
  }
}
