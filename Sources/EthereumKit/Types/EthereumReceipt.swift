//
//  EthereumReceipt.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

// MARK: - EthereumReceipt

public struct EthereumReceipt: ChainReceipt, Codable, Sendable {
  public let transactionHashHex: String
  public let transactionIndex: String
  public let blockHash: String
  public let blockNumberHex: String
  public let from: String
  public let to: String?
  public let cumulativeGasUsed: String
  public let effectiveGasPrice: String
  public let gasUsed: String
  public let contractAddress: String?
  public let logs: [EthereumLog]
  public let logsBloom: String
  public let type: String
  public let status: String  // "0x1" success, "0x0" failure

  enum CodingKeys: String, CodingKey {
    case transactionHashHex = "transactionHash"
    case transactionIndex
    case blockHash
    case blockNumberHex = "blockNumber"
    case from, to
    case cumulativeGasUsed, effectiveGasPrice, gasUsed
    case contractAddress, logs, logsBloom, type, status
  }

  // MARK: - ChainReceipt

  public var transactionHash: Data {
    Data(hex: transactionHashHex)
  }

  public var isSuccess: Bool {
    status == "0x1"
  }

  public var blockNumber: UInt64? {
    guard blockNumberHex.hasPrefix("0x") else { return nil }
    return UInt64(blockNumberHex.dropFirst(2), radix: 16)
  }

  public var gasUsedValue: UInt64? {
    guard gasUsed.hasPrefix("0x") else { return nil }
    return UInt64(gasUsed.dropFirst(2), radix: 16)
  }
}

// MARK: - EthereumLog

public struct EthereumLog: Codable, Sendable {
  public let address: String
  public let topics: [String]
  public let data: String
  public let blockNumber: String
  public let transactionHash: String
  public let transactionIndex: String
  public let blockHash: String
  public let logIndex: String
  public let removed: Bool
}

// MARK: - TransactionResponse

public struct EthereumTransactionResponse: Decodable, Sendable {
  public let hash: String
  public let nonce: String
  public let blockHash: String?
  public let blockNumber: String?
  public let transactionIndex: String?
  public let from: String
  public let to: String?
  public let value: String
  public let gasPrice: String?
  public let gas: String
  public let input: String
  public let type: String?

  // EIP-1559
  public let maxFeePerGas: String?
  public let maxPriorityFeePerGas: String?

  // EIP-2930
  public let accessList: [AccessListEntry]?

  public struct AccessListEntry: Decodable, Sendable {
    public let address: String
    public let storageKeys: [String]
  }

  public var isPending: Bool {
    blockHash == nil
  }
}
