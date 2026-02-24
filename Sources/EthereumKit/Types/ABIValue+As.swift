//
//  ABIValue+As.swift
//  EthereumKit
//

import Foundation

extension ABIValue {
  /// Convert ABIValue to specific Swift type
  public func `as`<T>(_ type: T.Type) -> T? {
    switch self {
    case .uint(_, let wei):
      if T.self == Wei.self { return wei as? T }
      if T.self == UInt64.self { return UInt64(wei.hexString.dropFirst(2), radix: 16) as? T }
      return nil

    case .int(_, let wei):
      if T.self == Wei.self { return wei as? T }
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
