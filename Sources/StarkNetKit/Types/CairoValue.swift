//
//  CairoValue.swift
//  StarknetKit
//
//  Cairo ABI value encoding/decoding for Starknet calldata.
//

import BigInt
import Foundation

// MARK: - CairoValue

/// Represents a Cairo ABI value that can be encoded/decoded to/from calldata.
public indirect enum CairoValue: Sendable, Equatable {
  /// felt252
  case felt252(Felt)

  /// Boolean
  case bool(Bool)

  /// u8
  case u8(UInt8)

  /// u16
  case u16(UInt16)

  /// u32
  case u32(UInt32)

  /// u64
  case u64(UInt64)

  /// u128
  case u128(BigUInt)

  /// u256 = (low: u128, high: u128)
  case u256(low: BigUInt, high: BigUInt)

  /// ContractAddress
  case contractAddress(Felt)

  /// ByteArray
  case byteArray(CairoByteArray)

  /// Array / Span
  case array([CairoValue])

  /// Option: Some(value) or None
  case some(CairoValue)
  case none

  /// Tuple / Struct: ordered fields
  case tuple([CairoValue])

  /// Enum: (variant_index, variant_data)
  case `enum`(variant: UInt64, data: [CairoValue])
}

// MARK: - CairoByteArray

/// Cairo ByteArray: used for strings longer than 31 bytes.
/// Encoding: [num_full_words, word0, word1, ..., pending_word, pending_word_len]
public struct CairoByteArray: Equatable, Sendable {
  public let fullWords: [Felt]
  public let pendingWord: Felt
  public let pendingWordLen: UInt8

  public init(fullWords: [Felt], pendingWord: Felt, pendingWordLen: UInt8) {
    self.fullWords = fullWords
    self.pendingWord = pendingWord
    self.pendingWordLen = pendingWordLen
  }

  /// Create from a UTF-8 string.
  public init(string: String) {
    let bytes = Array(string.utf8)
    let chunkSize = 31
    var words: [Felt] = []
    var i = 0
    while i + chunkSize <= bytes.count {
      let chunk = bytes[i..<(i + chunkSize)]
      var value = BigUInt.zero
      for byte in chunk {
        value = (value << 8) | BigUInt(byte)
      }
      words.append(Felt(value))
      i += chunkSize
    }
    let remaining = bytes[i...]
    var pendingValue = BigUInt.zero
    for byte in remaining {
      pendingValue = (pendingValue << 8) | BigUInt(byte)
    }
    self.fullWords = words
    self.pendingWord = Felt(pendingValue)
    self.pendingWordLen = UInt8(remaining.count)
  }

  /// Convert back to a UTF-8 string.
  public func toString() -> String {
    var bytes: [UInt8] = []
    let chunkSize = 31
    for word in fullWords {
      var value = word.bigUIntValue
      var chunk: [UInt8] = []
      for _ in 0..<chunkSize {
        chunk.append(UInt8(value & 0xFF))
        value >>= 8
      }
      bytes.append(contentsOf: chunk.reversed())
    }
    if pendingWordLen > 0 {
      var value = pendingWord.bigUIntValue
      var chunk: [UInt8] = []
      for _ in 0..<pendingWordLen {
        chunk.append(UInt8(value & 0xFF))
        value >>= 8
      }
      bytes.append(contentsOf: chunk.reversed())
    }
    return String(bytes: bytes, encoding: .utf8) ?? ""
  }
}

// MARK: - Convenience Initializers

extension CairoValue {
  /// Create u256 from a single BigUInt, splitting into low/high.
  public static func u256(_ value: BigUInt) -> CairoValue {
    let mask = (BigUInt(1) << 128) - 1
    return .u256(low: value & mask, high: value >> 128)
  }

  /// Create u256 from UInt64.
  public static func u256(_ value: UInt64) -> CairoValue {
    .u256(low: BigUInt(value), high: .zero)
  }

  /// The reconstructed u256 BigUInt value (only valid for .u256 case).
  public var u256Value: BigUInt? {
    guard case .u256(let low, let high) = self else { return nil }
    return (high << 128) + low
  }
}

// MARK: - Encoding

extension CairoValue {
  /// Encode this value into a flat array of Felt (Cairo calldata).
  public func encode() -> [Felt] {
    switch self {
    case .felt252(let val):
      return [val]
    case .bool(let val):
      return [val ? Felt(1) : Felt.zero]
    case .u8(let val):
      return [Felt(UInt64(val))]
    case .u16(let val):
      return [Felt(UInt64(val))]
    case .u32(let val):
      return [Felt(UInt64(val))]
    case .u64(let val):
      return [Felt(val)]
    case .u128(let val):
      return [Felt(val)]
    case .u256(let low, let high):
      return [Felt(low), Felt(high)]
    case .contractAddress(let val):
      return [val]
    case .byteArray(let ba):
      // [num_full_words, word0, ..., pending_word, pending_word_len]
      var result: [Felt] = [Felt(UInt64(ba.fullWords.count))]
      result.append(contentsOf: ba.fullWords)
      result.append(ba.pendingWord)
      result.append(Felt(UInt64(ba.pendingWordLen)))
      return result
    case .array(let elements):
      var result: [Felt] = [Felt(UInt64(elements.count))]
      for element in elements {
        result.append(contentsOf: element.encode())
      }
      return result
    case .some(let inner):
      return [.zero] + inner.encode()
    case .none:
      return [Felt(1)]
    case .tuple(let fields):
      var result: [Felt] = []
      for field in fields {
        result.append(contentsOf: field.encode())
      }
      return result
    case .enum(let variant, let data):
      var result: [Felt] = [Felt(variant)]
      for d in data {
        result.append(contentsOf: d.encode())
      }
      return result
    }
  }

  /// Encode multiple values into a flat calldata array.
  public static func encodeCalldata(_ values: CairoValue...) -> [Felt] {
    encodeCalldata(values)
  }

  /// Encode multiple values into a flat calldata array.
  public static func encodeCalldata(_ values: [CairoValue]) -> [Felt] {
    var result: [Felt] = []
    for value in values {
      result.append(contentsOf: value.encode())
    }
    return result
  }
}

// MARK: - Decoding

extension CairoValue {
  /// Decode a value of the given type from calldata at the specified offset.
  /// Returns the decoded value and the number of felts consumed.
  public static func decode(type: CairoType, from calldata: [Felt], at offset: Int = 0) throws -> (
    CairoValue, Int
  ) {
    func requireFields(_ count: Int) throws {
      guard count + offset <= calldata.count else {
        throw CairoABIError.outOfBounds(expected: count, available: calldata.count - offset)
      }
    }

    switch type {
    case .felt252:
      try requireFields(1)
      return (.felt252(calldata[offset]), 1)
    case .bool:
      try requireFields(1)
      let felt = calldata[offset]
      if felt == Felt(1) {
        return (.bool(true), 1)
      } else if felt == Felt.zero {
        return (.bool(false), 1)
      }
      throw CairoABIError.invalidBool(felt)
    case .u8:
      try requireFields(1)
      return (.u8(UInt8(calldata[offset].bigUIntValue)), 1)
    case .u16:
      try requireFields(1)
      return (.u16(UInt16(calldata[offset].bigUIntValue)), 1)
    case .u32:
      try requireFields(1)
      return (.u32(UInt32(calldata[offset].bigUIntValue)), 1)
    case .u64:
      try requireFields(1)
      return (.u64(UInt64(calldata[offset].bigUIntValue)), 1)
    case .u128:
      try requireFields(1)
      return (.u128(calldata[offset].bigUIntValue), 1)
    case .u256:
      try requireFields(2)
      return (.u256(low: calldata[offset].bigUIntValue, high: calldata[offset + 1].bigUIntValue), 2)
    case .contractAddress:
      try requireFields(1)
      return (.contractAddress(calldata[offset]), 1)
    case .byteArray:
      // [num_full_words, word0, ..., pending_word, pending_word_len]
      try requireFields(1)
      let numFullWords = Int(calldata[offset].bigUIntValue)
      let totalNeeded = 1 + numFullWords + 2
      try requireFields(totalNeeded)
      var fullWords: [Felt] = []
      for i in 0..<numFullWords {
        fullWords.append(calldata[offset + 1 + i])
      }
      let pendingWord = calldata[offset + 1 + numFullWords]
      let pendingWordLen = UInt8(calldata[offset + 1 + numFullWords + 1].bigUIntValue)
      let ba = CairoByteArray(
        fullWords: fullWords, pendingWord: pendingWord, pendingWordLen: pendingWordLen)
      return (.byteArray(ba), totalNeeded)
    case .array(let elementType):
      try requireFields(1)
      let length = Int(calldata[offset].bigUIntValue)
      var elements: [CairoValue] = []
      var consumed = 1
      for _ in 0..<length {
        let (element, n) = try decode(type: elementType, from: calldata, at: offset + consumed)
        elements.append(element)
        consumed += n
      }
      return (.array(elements), consumed)
    case .option(let innerType):
      try requireFields(1)
      let variant = calldata[offset].bigUIntValue
      if variant == 0 {
        let (inner, n) = try decode(type: innerType, from: calldata, at: offset + 1)
        return (.some(inner), 1 + n)
      } else if variant == 1 {
        return (.none, 1)
      }
      throw CairoABIError.invalidOptionVariant(calldata[offset])
    case .tuple(let fieldTypes):
      var fields: [CairoValue] = []
      var consumed = 0
      for fieldType in fieldTypes {
        let (field, n) = try decode(type: fieldType, from: calldata, at: offset + consumed)
        fields.append(field)
        consumed += n
      }
      return (.tuple(fields), consumed)
    case .enum(let variantTypes):
      try requireFields(1)
      let variantIndex = Int(calldata[offset].bigUIntValue)
      guard variantIndex < variantTypes.count else {
        throw CairoABIError.outOfBounds(expected: variantIndex, available: variantTypes.count)
      }
      let (data, n) = try decode(type: variantTypes[variantIndex], from: calldata, at: offset + 1)
      return (.enum(variant: UInt64(variantIndex), data: [data]), 1 + n)
    }
  }
}
