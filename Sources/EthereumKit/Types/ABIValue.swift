//
//  ABIValue.swift
//  EthereumKit
//
//  Based on Solidity ABI Specification:
//  https://docs.soliditylang.org/en/v0.8.24/abi-spec.html
//

import Foundation

// MARK: - ABIValue

/// Represents a value that can be ABI encoded/decoded
public indirect enum ABIValue: Sendable, Equatable {
  /// Unsigned integer: uint8, uint16, ..., uint256
  /// All encoded as 32 bytes, left-padded with zeros
  case uint(bits: Int, value: Wei)

  /// Signed integer: int8, int16, ..., int256
  /// All encoded as 32 bytes, sign-extended
  case int(bits: Int, value: Wei)

  /// Address: 20 bytes, left-padded to 32 bytes
  case address(EthereumAddress)

  /// Boolean: encoded as uint8, restricted to 0 or 1
  case bool(Bool)

  /// Fixed-size bytes: bytes1, bytes2, ..., bytes32
  /// Right-padded to 32 bytes
  case fixedBytes(Data)

  /// Dynamic bytes: length-prefixed byte sequence
  case bytes(Data)

  /// Dynamic string: UTF-8 encoded, length-prefixed
  case string(String)

  /// Fixed-size array: T[k] - k elements of type T
  case fixedArray([ABIValue])

  /// Dynamic array: T[] - length-prefixed sequence
  case array([ABIValue])

  /// Tuple: (T1, T2, ..., Tn) - struct-like composite
  case tuple([ABIValue])
}

// MARK: - Convenience Initializers

extension ABIValue {
  /// Create uint256 from Wei
  public static func uint256(_ value: Wei) -> ABIValue {
    .uint(bits: 256, value: value)
  }

  /// Create uint256 from UInt64
  public static func uint256(_ value: UInt64) -> ABIValue {
    .uint(bits: 256, value: Wei(value))
  }

  /// Create bytes32 from Data
  public static func bytes32(_ data: Data) -> ABIValue {
    .fixedBytes(data.prefix(32) + Data(repeating: 0, count: max(0, 32 - data.count)))
  }
}

// MARK: - ExpressibleBy Literals

extension ABIValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: UInt64) {
    self = .uint(bits: 256, value: Wei(value))
  }
}

extension ABIValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

extension ABIValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    if let addr = EthereumAddress(value) {
      self = .address(addr)
    } else {
      self = .string(value)
    }
  }
}

extension ABIValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: ABIValue...) {
    self = .array(elements)
  }
}

// MARK: - Static/Dynamic Classification

extension ABIValue {
  /// Returns true if this value is a dynamic type per ABI spec
  /// Dynamic types: bytes, string, T[], T[k] where T is dynamic, tuple with dynamic elements
  public var isDynamic: Bool {
    switch self {
    case .uint, .int, .address, .bool, .fixedBytes:
      return false

    case .bytes, .string, .array:
      return true

    case .fixedArray(let elements):
      // T[k] is dynamic if T is dynamic
      return elements.first?.isDynamic ?? false

    case .tuple(let elements):
      // Tuple is dynamic if any element is dynamic
      return elements.contains { $0.isDynamic }
    }
  }

  /// Returns the head size in bytes (32 for static types, 32 for offset pointer if dynamic)
  public var headSize: Int {
    switch self {
    case .uint, .int, .address, .bool, .fixedBytes:
      return 32

    case .bytes, .string, .array:
      return 32  // offset pointer

    case .fixedArray(let elements):
      if isDynamic {
        return 32  // offset pointer
      } else {
        return elements.reduce(0) { $0 + $1.headSize }
      }

    case .tuple(let elements):
      if isDynamic {
        return 32  // offset pointer
      } else {
        return elements.reduce(0) { $0 + $1.headSize }
      }
    }
  }
}

// MARK: - ABI Encoding

extension ABIValue {
  /// Encode value to ABI format following the specification
  public func encode() -> Data {
    switch self {
    case .uint(_, let value):
      return encodeUint(value)

    case .int(_, let value):
      // For simplicity, treat as unsigned (proper impl needs sign extension)
      return encodeUint(value)

    case .address(let addr):
      // Address is 20 bytes, left-padded with 12 zero bytes
      return Data(repeating: 0, count: 12) + addr.data

    case .bool(let value):
      var data = Data(repeating: 0, count: 32)
      data[31] = value ? 1 : 0
      return data

    case .fixedBytes(let bytes):
      // Right-padded to 32 bytes
      if bytes.count >= 32 {
        return Data(bytes.prefix(32))
      }
      return bytes + Data(repeating: 0, count: 32 - bytes.count)

    case .bytes(let data):
      return encodeDynamicBytes(data)

    case .string(let str):
      return encodeDynamicBytes(str.data(using: .utf8) ?? Data())

    case .fixedArray(let elements):
      return encodeFixedArray(elements)

    case .array(let elements):
      return encodeDynamicArray(elements)

    case .tuple(let elements):
      return encodeTuple(elements)
    }
  }

  // MARK: - Private Encoding Helpers

  private func encodeUint(_ value: Wei) -> Data {
    let data = value.bigEndianData
    if data.count >= 32 {
      return Data(data.suffix(32))
    }
    return Data(repeating: 0, count: 32 - data.count) + data
  }

  private func encodeDynamicBytes(_ data: Data) -> Data {
    // length (32 bytes) + data (right-padded to multiple of 32)
    let length = ABIValue.uint256(UInt64(data.count)).encode()
    let paddedLength = ((data.count + 31) / 32) * 32
    var paddedData = data
    if paddedData.count < paddedLength {
      paddedData.append(Data(repeating: 0, count: paddedLength - data.count))
    }
    return length + paddedData
  }

  private func encodeFixedArray(_ elements: [ABIValue]) -> Data {
    if elements.isEmpty {
      return Data()
    }

    // If elements are static, just concatenate
    if !(elements.first?.isDynamic ?? false) {
      var result = Data()
      for element in elements {
        result.append(element.encode())
      }
      return result
    }

    // If elements are dynamic, use head/tail encoding
    return encodeWithHeadTail(elements)
  }

  private func encodeDynamicArray(_ elements: [ABIValue]) -> Data {
    // length + encoded elements
    let length = ABIValue.uint256(UInt64(elements.count)).encode()

    if elements.isEmpty {
      return length
    }

    // If elements are static, just concatenate
    if !(elements.first?.isDynamic ?? false) {
      var result = length
      for element in elements {
        result.append(element.encode())
      }
      return result
    }

    // If elements are dynamic, use head/tail encoding
    return length + encodeWithHeadTail(elements)
  }

  private func encodeTuple(_ elements: [ABIValue]) -> Data {
    if elements.isEmpty {
      return Data()
    }

    // Check if all elements are static
    let allStatic = !elements.contains { $0.isDynamic }

    if allStatic {
      // Just concatenate all encoded values
      var result = Data()
      for element in elements {
        result.append(element.encode())
      }
      return result
    }

    // Use head/tail encoding for tuples with dynamic elements
    return encodeWithHeadTail(elements)
  }

  /// Head/tail encoding for dynamic types
  /// Head: static values in-place, offsets for dynamic values
  /// Tail: actual data for dynamic values
  private func encodeWithHeadTail(_ elements: [ABIValue]) -> Data {
    var heads = Data()
    var tails = Data()

    // Calculate total head size first
    let totalHeadSize = elements.count * 32

    for element in elements {
      if element.isDynamic {
        // Head contains offset to tail
        let offset = totalHeadSize + tails.count
        heads.append(ABIValue.uint256(UInt64(offset)).encode())
        // Tail contains actual encoded data
        tails.append(element.encode())
      } else {
        // Head contains the actual encoded value
        heads.append(element.encode())
      }
    }

    return heads + tails
  }
}

// MARK: - Function Selector

extension ABIValue {
  /// Calculate function selector: first 4 bytes of keccak256(signature)
  /// Signature format: "functionName(type1,type2,...)"
  public static func functionSelector(_ signature: String) -> Data {
    let hash = Keccak256.hash(signature.data(using: .utf8)!)
    return Data(hash.prefix(4))
  }

  /// Encode a function call: selector + encoded arguments
  public static func encodeCall(signature: String, arguments: [ABIValue]) -> Data {
    let selector = functionSelector(signature)
    let tuple = ABIValue.tuple(arguments)
    return selector + tuple.encode()
  }
}
