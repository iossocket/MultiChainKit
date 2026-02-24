import BigInt
import Foundation

// MARK: - EIP712Value

/// Type-safe value for EIP-712 typed data
public enum EIP712Value: Sendable, Equatable {
  case string(String)
  case uint(Wei)
  case int(Wei)
  case bool(Bool)
  case address(EthereumAddress)
  case bytes(Data)
  case fixedBytes(Data)
  case array([EIP712Value])
  case `struct`([String: EIP712Value])
}

// MARK: - EIP712Value ExpressibleBy

extension EIP712Value: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

extension EIP712Value: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: UInt64) {
    self = .uint(Wei(value))
  }
}

extension EIP712Value: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

extension EIP712Value: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: EIP712Value...) {
    self = .array(elements)
  }
}

extension EIP712Value: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, EIP712Value)...) {
    self = .struct(Dictionary(uniqueKeysWithValues: elements))
  }
}

// MARK: - EIP712Domain

public struct EIP712Domain: Sendable, Equatable {
  public let name: String?
  public let version: String?
  public let chainId: UInt64?
  public let verifyingContract: EthereumAddress?
  public let salt: Data?

  public init(
    name: String? = nil,
    version: String? = nil,
    chainId: UInt64? = nil,
    verifyingContract: EthereumAddress? = nil,
    salt: Data? = nil
  ) {
    self.name = name
    self.version = version
    self.chainId = chainId
    self.verifyingContract = verifyingContract
    self.salt = salt
  }

  public func separator() -> Data {
    // 1. Build type string with field types (not values)
    var typeFields: [String] = []
    if name != nil { typeFields.append("string name") }
    if version != nil { typeFields.append("string version") }
    if chainId != nil { typeFields.append("uint256 chainId") }
    if verifyingContract != nil { typeFields.append("address verifyingContract") }
    if salt != nil { typeFields.append("bytes32 salt") }

    let typeStr = "EIP712Domain(" + typeFields.joined(separator: ",") + ")"

    // 2. Calculate typeHash
    let typeHash = Keccak256.hash(typeStr.data(using: .utf8)!)

    // 3. Encode values
    var encodedValues = Data()
    encodedValues.append(typeHash)

    if let name = name {
      // string -> keccak256(bytes)
      encodedValues.append(Keccak256.hash(name.data(using: .utf8)!))
    }
    if let version = version {
      // string -> keccak256(bytes)
      encodedValues.append(Keccak256.hash(version.data(using: .utf8)!))
    }
    if let chainId = chainId {
      // uint256 -> 32 bytes big-endian
      encodedValues.append(ABIValue.uint256(Wei(chainId)).encode())
    }
    if let verifyingContract = verifyingContract {
      // address -> 32 bytes left-padded
      encodedValues.append(ABIValue.address(verifyingContract).encode())
    }
    if let salt = salt {
      // bytes32 -> 32 bytes, right-pad if needed
      var saltData = Data(salt.prefix(32))
      if saltData.count < 32 {
        saltData.append(Data(repeating: 0, count: 32 - saltData.count))
      }
      encodedValues.append(saltData)
    }

    // 4. Return keccak256(typeHash + encodedValues)
    return Keccak256.hash(encodedValues)
  }
}

// MARK: - EIP712Type

public struct EIP712Type: Sendable, Equatable {
  public let name: String
  public let type: String

  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }
}

// MARK: - EIP712TypedData

public struct EIP712TypedData: Sendable, Equatable {
  public let types: [String: [EIP712Type]]
  public let primaryType: String
  public let domain: EIP712Domain
  public let message: [String: EIP712Value]

  public init(
    types: [String: [EIP712Type]],
    primaryType: String,
    domain: EIP712Domain,
    message: [String: EIP712Value]
  ) {
    self.types = types
    self.primaryType = primaryType
    self.domain = domain
    self.message = message
  }

  /// Calculate the hash to sign: keccak256("\x19\x01" + domainSeparator + structHash)
  public func signHash() throws -> Data {
    let domainSeparator = domain.separator()
    let structHash = try EIP712.hashStruct(primaryType, data: message, types: types)

    var data = Data([0x19, 0x01])
    data.append(domainSeparator)
    data.append(structHash)

    return Keccak256.hash(data)
  }
}

// MARK: - EIP712

public enum EIP712 {

  /// Encode type string for a struct (includes referenced types alphabetically)
  public static func encodeType(_ primaryType: String, types: [String: [EIP712Type]]) -> String {
    var result = encodeTypeSingle(primaryType, types: types)

    // Find all referenced types
    let referencedTypes = findReferencedTypes(primaryType, types: types)
      .sorted()
      .filter { $0 != primaryType }

    for refType in referencedTypes {
      result += encodeTypeSingle(refType, types: types)
    }

    return result
  }

  /// Calculate type hash: keccak256(encodeType)
  public static func typeHash(_ primaryType: String, types: [String: [EIP712Type]]) -> Data {
    let encoded = encodeType(primaryType, types: types)
    return Keccak256.hash(encoded.data(using: .utf8)!)
  }

  /// Hash a struct: keccak256(typeHash + encodeData)
  public static func hashStruct(
    _ primaryType: String,
    data: [String: EIP712Value],
    types: [String: [EIP712Type]]
  ) throws -> Data {
    let typeHashData = typeHash(primaryType, types: types)
    let encodedData = try encodeData(primaryType, data: data, types: types)

    var combined = Data()
    combined.append(typeHashData)
    combined.append(encodedData)

    return Keccak256.hash(combined)
  }

  // MARK: - Private Helpers

  private static func encodeTypeSingle(_ typeName: String, types: [String: [EIP712Type]]) -> String
  {
    guard let fields = types[typeName] else { return "" }
    let params = fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")
    return "\(typeName)(\(params))"
  }

  private static func findReferencedTypes(
    _ typeName: String,
    types: [String: [EIP712Type]],
    found: inout Set<String>
  ) {
    guard let fields = types[typeName], !found.contains(typeName) else { return }
    found.insert(typeName)

    for field in fields {
      let baseType = extractBaseType(field.type)
      if types[baseType] != nil {
        findReferencedTypes(baseType, types: types, found: &found)
      }
    }
  }

  private static func findReferencedTypes(_ typeName: String, types: [String: [EIP712Type]]) -> Set<
    String
  > {
    var found = Set<String>()
    findReferencedTypes(typeName, types: types, found: &found)
    return found
  }

  private static func extractBaseType(_ type: String) -> String {
    // Remove array suffix: "uint256[]" -> "uint256", "Person[2]" -> "Person"
    if let bracketIndex = type.firstIndex(of: "[") {
      return String(type[..<bracketIndex])
    }
    return type
  }

  private static func encodeData(
    _ primaryType: String,
    data: [String: EIP712Value],
    types: [String: [EIP712Type]]
  ) throws -> Data {
    guard let fields = types[primaryType] else {
      throw EIP712Error.unknownType(primaryType)
    }

    var encoded = Data()

    for field in fields {
      guard let value = data[field.name] else {
        throw EIP712Error.missingField(field.name)
      }
      let encodedValue = try encodeValue(value, type: field.type, types: types)
      encoded.append(encodedValue)
    }

    return encoded
  }

  private static func encodeValue(
    _ value: EIP712Value,
    type: String,
    types: [String: [EIP712Type]]
  ) throws -> Data {
    // Handle arrays
    if type.hasSuffix("[]") {
      let baseType = String(type.dropLast(2))
      guard case .array(let array) = value else {
        throw EIP712Error.typeMismatch(expected: type, got: "\(value)")
      }
      var arrayData = Data()
      for item in array {
        let itemEncoded = try encodeValue(item, type: baseType, types: types)
        arrayData.append(itemEncoded)
      }
      return Keccak256.hash(arrayData)
    }

    // Handle fixed-size arrays
    if let bracketIndex = type.firstIndex(of: "["), type.hasSuffix("]") {
      let baseType = String(type[..<bracketIndex])
      guard case .array(let array) = value else {
        throw EIP712Error.typeMismatch(expected: type, got: "\(value)")
      }
      var arrayData = Data()
      for item in array {
        let itemEncoded = try encodeValue(item, type: baseType, types: types)
        arrayData.append(itemEncoded)
      }
      return Keccak256.hash(arrayData)
    }

    // Handle struct types (custom types defined in types dict)
    if types[type] != nil {
      guard case .struct(let structData) = value else {
        throw EIP712Error.typeMismatch(expected: type, got: "\(value)")
      }
      return try hashStruct(type, data: structData, types: types)
    }

    // Handle primitive types
    return try encodePrimitiveValue(value, type: type)
  }

  private static func encodePrimitiveValue(_ value: EIP712Value, type: String) throws -> Data {
    switch (type, value) {
    case ("string", .string(let str)):
      return Keccak256.hash(str.data(using: .utf8)!)

    case ("bytes", .bytes(let data)):
      return Keccak256.hash(data)

    case ("bool", .bool(let bool)):
      return ABIValue.bool(bool).encode()

    case ("address", .address(let addr)):
      return ABIValue.address(addr).encode()

    default:
      // Handle uint/int types
      if type.hasPrefix("uint") || type.hasPrefix("int") {
        let bits = Int(type.dropFirst(type.hasPrefix("uint") ? 4 : 3)) ?? 256
        if case .uint(let wei) = value {
          return ABIValue.uint(bits: bits, value: wei).encode()
        }
        if case .int(let wei) = value {
          return ABIValue.uint(bits: bits, value: wei).encode()
        }
        throw EIP712Error.typeMismatch(expected: type, got: "\(value)")
      }

      // Handle bytes1-bytes32
      if type.hasPrefix("bytes"), let size = Int(type.dropFirst(5)), size >= 1, size <= 32 {
        if case .fixedBytes(let data) = value {
          return ABIValue.fixedBytes(data.prefix(size)).encode()
        }
        throw EIP712Error.typeMismatch(expected: type, got: "\(value)")
      }

      throw EIP712Error.unsupportedType(type)
    }
  }
}

// MARK: - EIP712Error

public enum EIP712Error: Error, Sendable {
  case unknownType(String)
  case missingField(String)
  case typeMismatch(expected: String, got: String)
  case unsupportedType(String)
}
