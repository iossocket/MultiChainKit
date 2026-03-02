//
//  ABIValue+As.swift
//  EthereumKit
//

import BigInt
import Foundation

extension ABIValue {
  /// Convert ABIValue to specific Swift type
  public func `as`<T>(_ type: T.Type) -> T? {
    switch self {
    case .uint(_, let wei):
      if T.self == Wei.self { return wei as? T }

      // Convert to integer types with overflow checking
      let bigUInt = wei.bigUIntValue

      if T.self == BigUInt.self { return bigUInt as? T }

      // Try to convert to UInt64 first
      guard bigUInt.bitWidth <= 64, let uint64Value = UInt64(exactly: bigUInt) else {
        return nil
      }

      if T.self == UInt64.self { return uint64Value as? T }
      if T.self == UInt.self { return UInt(exactly: uint64Value) as? T }
      if T.self == UInt32.self { return UInt32(exactly: uint64Value) as? T }
      if T.self == UInt16.self { return UInt16(exactly: uint64Value) as? T }
      if T.self == UInt8.self { return UInt8(exactly: uint64Value) as? T }
      if T.self == Int.self { return Int(exactly: uint64Value) as? T }
      if T.self == Int64.self { return Int64(exactly: uint64Value) as? T }
      if T.self == Int32.self { return Int32(exactly: uint64Value) as? T }
      if T.self == Int16.self { return Int16(exactly: uint64Value) as? T }
      if T.self == Int8.self { return Int8(exactly: uint64Value) as? T }
      return nil

    case .int(_, let wei):
      if T.self == Wei.self { return wei as? T }

      // Convert to integer types with overflow checking (treating as unsigned for now)
      let bigUInt = wei.bigUIntValue

      if T.self == BigUInt.self { return bigUInt as? T }

      // Try to convert to UInt64 first
      guard bigUInt.bitWidth <= 64, let uint64Value = UInt64(exactly: bigUInt) else {
        return nil
      }

      if T.self == UInt64.self { return uint64Value as? T }
      if T.self == UInt.self { return UInt(exactly: uint64Value) as? T }
      if T.self == UInt32.self { return UInt32(exactly: uint64Value) as? T }
      if T.self == UInt16.self { return UInt16(exactly: uint64Value) as? T }
      if T.self == UInt8.self { return UInt8(exactly: uint64Value) as? T }
      if T.self == Int.self { return Int(exactly: uint64Value) as? T }
      if T.self == Int64.self { return Int64(exactly: uint64Value) as? T }
      if T.self == Int32.self { return Int32(exactly: uint64Value) as? T }
      if T.self == Int16.self { return Int16(exactly: uint64Value) as? T }
      if T.self == Int8.self { return Int8(exactly: uint64Value) as? T }
      return nil

    case .address(let addr):
      if T.self == EthereumAddress.self { return addr as? T }
      if T.self == String.self { return addr.checksummed as? T }
      return nil

    case .bool(let value):
      if T.self == Bool.self { return value as? T }
      return nil

    case .string(let value):
      if T.self == String.self { return value as? T }
      return nil

    case .bytes(let data), .fixedBytes(let data):
      if T.self == Data.self { return data as? T }
      return nil

    case .array(let values):
      if T.self == [ABIValue].self { return values as? T }
      return nil

    case .fixedArray(let values):
      if T.self == [ABIValue].self { return values as? T }
      return nil

    case .tuple(let values):
      if T.self == [ABIValue].self { return values as? T }
      return nil
    }
  }
}
