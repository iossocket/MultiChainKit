//
//  CairoValue+As.swift
//  StarknetKit
//

import BigInt
import Foundation

extension CairoValue {
  /// Convert CairoValue to specific Swift type
  public func `as`<T>(_ type: T.Type) -> T? {
    switch self {
    case .felt252(let felt):
      if T.self == Felt.self { return felt as? T }
      if T.self == BigUInt.self { return felt.bigUIntValue as? T }
      if T.self == String.self { return felt.hexString as? T }
      return nil

    case .bool(let value):
      if T.self == Bool.self { return value as? T }
      return nil

    case .u8(let value):
      if T.self == UInt8.self { return value as? T }
      if T.self == UInt16.self { return UInt16(value) as? T }
      if T.self == UInt32.self { return UInt32(value) as? T }
      if T.self == UInt64.self { return UInt64(value) as? T }
      if T.self == Int.self { return Int(value) as? T }
      if T.self == BigUInt.self { return BigUInt(value) as? T }
      return nil

    case .u16(let value):
      if T.self == UInt16.self { return value as? T }
      if T.self == UInt32.self { return UInt32(value) as? T }
      if T.self == UInt64.self { return UInt64(value) as? T }
      if T.self == Int.self { return Int(value) as? T }
      if T.self == BigUInt.self { return BigUInt(value) as? T }
      return nil

    case .u32(let value):
      if T.self == UInt32.self { return value as? T }
      if T.self == UInt64.self { return UInt64(value) as? T }
      if T.self == Int.self { return Int(value) as? T }
      if T.self == BigUInt.self { return BigUInt(value) as? T }
      return nil

    case .u64(let value):
      if T.self == UInt64.self { return value as? T }
      if T.self == Int.self { return Int(exactly: value) as? T }
      if T.self == BigUInt.self { return BigUInt(value) as? T }
      return nil

    case .u128(let value):
      if T.self == BigUInt.self { return value as? T }
      if T.self == UInt64.self { return UInt64(exactly: value) as? T }
      return nil

    case .u256(let low, let high):
      let full = (high << 128) + low
      if T.self == BigUInt.self { return full as? T }
      return nil

    case .contractAddress(let felt):
      if T.self == Felt.self { return felt as? T }
      if T.self == StarknetAddress.self { return StarknetAddress(felt.hexString) as? T }
      if T.self == String.self { return felt.hexString as? T }
      return nil

    case .byteArray(let ba):
      if T.self == CairoByteArray.self { return ba as? T }
      if T.self == String.self { return ba.toString() as? T }
      return nil

    case .array(let values):
      if T.self == [CairoValue].self { return values as? T }
      return nil

    case .some(let inner):
      return inner.as(type)

    case .none:
      return nil

    case .tuple(let values):
      if T.self == [CairoValue].self { return values as? T }
      return nil

    case .enum(_, let data):
      if T.self == [CairoValue].self { return data as? T }
      return nil
    }
  }
}
