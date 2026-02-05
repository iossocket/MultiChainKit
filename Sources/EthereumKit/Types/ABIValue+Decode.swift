//
//  ABIValue+Decode.swift
//  EthereumKit
//
//  ABI decoding implementation following Solidity ABI Specification:
//  https://docs.soliditylang.org/en/v0.8.24/abi-spec.html
//

import BigInt
import Foundation

// MARK: - ABIDecodingError

public enum ABIDecodingError: Error, Sendable {
  case insufficientData
  case invalidOffset
  case invalidLength
  case invalidUtf8
  case typeMismatch
}

// MARK: - ABI Decoding

extension ABIValue {
  /// Decode ABI encoded data given a list of types
  public static func decode(types: [ABIType], data: Data) throws -> [ABIValue] {
    var decoder = ABIDecoder(data: data)
    return try decoder.decode(types: types)
  }

  public static func decode(type: ABIType, data: Data) throws -> ABIValue {
    let results = try decode(types: [type], data: data)
    guard let first = results.first else {
      throw ABIDecodingError.insufficientData
    }
    return first
  }

  /// Decode function return values
  public static func decodeFunctionResult(
    outputTypes: [ABIType],
    data: Data
  ) throws -> [ABIValue] {
    return try decode(types: outputTypes, data: data)
  }
}

// MARK: - ABIDecoder

private struct ABIDecoder {
  let data: Data
  var offset: Int = 0

  init(data: Data) {
    self.data = data
  }

  mutating func decode(types: [ABIType]) throws -> [ABIValue] {
    var results: [ABIValue] = []

    // First pass: decode heads and collect tail offsets for dynamic types
    var headOffset = 0
    var decodingInfos: [(type: ABIType, isDynamic: Bool, tailOffset: Int?)] = []

    for type in types {
      let isDynamic = type.isDynamic
      if isDynamic {
        // Read offset to tail
        let tailOffset = try readUint256At(offset: headOffset)
        decodingInfos.append((type, true, Int(tailOffset)))
        headOffset += 32
      } else {
        decodingInfos.append((type, false, nil))
        headOffset += type.headSize
      }
    }

    // Second pass: decode values
    var currentHeadOffset = 0
    for info in decodingInfos {
      if info.isDynamic {
        // Decode from tail
        guard let tailOffset = info.tailOffset else {
          throw ABIDecodingError.invalidOffset
        }
        let value = try decodeType(info.type, at: tailOffset)
        results.append(value)
        currentHeadOffset += 32
      } else {
        // Decode from head
        let value = try decodeType(info.type, at: currentHeadOffset)
        results.append(value)
        currentHeadOffset += info.type.headSize
      }
    }

    return results
  }

  func decodeType(_ type: ABIType, at offset: Int) throws -> ABIValue {
    switch type {
    case .uint(let bits):
      let value = try readUint256At(offset: offset)
      return .uint(bits: bits, value: Wei(value))

    case .int(let bits):
      let value = try readUint256At(offset: offset)
      // For now, store as Wei (proper signed handling would need BigInt)
      return .int(bits: bits, value: Wei(value))

    case .address:
      let bytes = try readBytesAt(offset: offset, count: 32)
      // Address is in the last 20 bytes
      let addressData = Data(bytes.suffix(20))
      return .address(EthereumAddress(addressData))

    case .bool:
      let value = try readUint256At(offset: offset)
      return .bool(value != 0)

    case .fixedBytes(let size):
      let bytes = try readBytesAt(offset: offset, count: 32)
      // Fixed bytes are right-padded, take first `size` bytes
      return .fixedBytes(Data(bytes.prefix(size)))

    case .bytes:
      return try decodeDynamicBytes(at: offset)

    case .string:
      return try decodeString(at: offset)

    case .array(let elementType):
      return try decodeDynamicArray(elementType: elementType, at: offset)

    case .fixedArray(let elementType, let size):
      return try decodeFixedArray(elementType: elementType, size: size, at: offset)

    case .tuple(let componentTypes):
      return try decodeTuple(componentTypes: componentTypes, at: offset)
    }
  }

  // MARK: - Dynamic Types

  func decodeDynamicBytes(at offset: Int) throws -> ABIValue {
    let length = try readUint256At(offset: offset)
    guard length <= Int.max else {
      throw ABIDecodingError.invalidLength
    }
    let bytesOffset = offset + 32
    let bytes = try readBytesAt(offset: bytesOffset, count: Int(length))
    return .bytes(bytes)
  }

  func decodeString(at offset: Int) throws -> ABIValue {
    let length = try readUint256At(offset: offset)
    guard length <= Int.max else {
      throw ABIDecodingError.invalidLength
    }
    let bytesOffset = offset + 32
    let bytes = try readBytesAt(offset: bytesOffset, count: Int(length))
    guard let string = String(data: bytes, encoding: .utf8) else {
      throw ABIDecodingError.invalidUtf8
    }
    return .string(string)
  }

  func decodeDynamicArray(elementType: ABIType, at offset: Int) throws -> ABIValue {
    let length = try readUint256At(offset: offset)
    guard length <= Int.max else {
      throw ABIDecodingError.invalidLength
    }

    let count = Int(length)
    let elementsOffset = offset + 32

    var elements: [ABIValue] = []
    if elementType.isDynamic {
      // Each element has an offset pointer
      for i in 0..<count {
        let elementOffsetPtr = elementsOffset + i * 32
        let elementOffset = try readUint256At(offset: elementOffsetPtr)
        let element = try decodeType(elementType, at: elementsOffset + Int(elementOffset))
        elements.append(element)
      }
    } else {
      // Elements are packed sequentially
      let elementSize = elementType.headSize
      for i in 0..<count {
        let elementOffset = elementsOffset + i * elementSize
        let element = try decodeType(elementType, at: elementOffset)
        elements.append(element)
      }
    }

    return .array(elements)
  }

  func decodeFixedArray(elementType: ABIType, size: Int, at offset: Int) throws -> ABIValue {
    var elements: [ABIValue] = []

    if elementType.isDynamic {
      // Each element has an offset pointer
      for i in 0..<size {
        let elementOffsetPtr = offset + i * 32
        let elementOffset = try readUint256At(offset: elementOffsetPtr)
        let element = try decodeType(elementType, at: offset + Int(elementOffset))
        elements.append(element)
      }
    } else {
      // Elements are packed sequentially
      let elementSize = elementType.headSize
      for i in 0..<size {
        let elementOffset = offset + i * elementSize
        let element = try decodeType(elementType, at: elementOffset)
        elements.append(element)
      }
    }

    return .fixedArray(elements)
  }

  func decodeTuple(componentTypes: [ABIType], at offset: Int) throws -> ABIValue {
    let tupleIsDynamic = componentTypes.contains { $0.isDynamic }

    var elements: [ABIValue] = []
    var currentOffset = offset

    if tupleIsDynamic {
      // Head/tail encoding
      var headOffset = offset

      for componentType in componentTypes {
        if componentType.isDynamic {
          // Read offset to tail (relative to tuple start)
          let tailOffset = try readUint256At(offset: headOffset)
          let element = try decodeType(componentType, at: offset + Int(tailOffset))
          elements.append(element)
          headOffset += 32
        } else {
          let element = try decodeType(componentType, at: headOffset)
          elements.append(element)
          headOffset += componentType.headSize
        }
      }
    } else {
      // All static - just decode sequentially
      for componentType in componentTypes {
        let element = try decodeType(componentType, at: currentOffset)
        elements.append(element)
        currentOffset += componentType.headSize
      }
    }

    return .tuple(elements)
  }

  // MARK: - Helpers

  func readUint256At(offset: Int) throws -> BigUInt {
    let bytes = try readBytesAt(offset: offset, count: 32)
    return BigUInt(Data(bytes))
  }

  func readBytesAt(offset: Int, count: Int) throws -> Data {
    guard offset >= 0, offset + count <= data.count else {
      throw ABIDecodingError.insufficientData
    }
    return data[offset..<(offset + count)]
  }
}

// MARK: - ABIType Extensions

extension ABIType {
  /// Returns true if this type is dynamic
  var isDynamic: Bool {
    switch self {
    case .uint, .int, .address, .bool, .fixedBytes:
      return false
    case .bytes, .string, .array:
      return true
    case .fixedArray(let elementType, _):
      return elementType.isDynamic
    case .tuple(let components):
      return components.contains { $0.isDynamic }
    }
  }

  /// Returns the head size in bytes
  var headSize: Int {
    switch self {
    case .uint, .int, .address, .bool, .fixedBytes:
      return 32
    case .bytes, .string, .array:
      return 32  // offset pointer
    case .fixedArray(let elementType, let size):
      if isDynamic {
        return 32  // offset pointer
      } else {
        return elementType.headSize * size
      }
    case .tuple(let components):
      if isDynamic {
        return 32  // offset pointer
      } else {
        return components.reduce(0) { $0 + $1.headSize }
      }
    }
  }
}
