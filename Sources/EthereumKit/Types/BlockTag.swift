//
//  BlockTag.swift
//  EthereumKit
//

import Foundation

/// Ethereum JSON-RPC block identifier (latest, pending, earliest, or block number).
public enum BlockTag: Sendable, Equatable {
  case latest
  case pending
  case earliest
  case number(UInt64)

  public var rawValue: String {
    switch self {
    case .latest: return "latest"
    case .pending: return "pending"
    case .earliest: return "earliest"
    case .number(let n): return "0x" + String(n, radix: 16)
    }
  }
}
