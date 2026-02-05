//
//  EthereumBlock.swift
//  EthereumKit
//

import Foundation

// MARK: - EthereumBlock

public struct EthereumBlock: Decodable, Sendable {
  public let number: String?
  public let hash: String?
  public let parentHash: String
  public let nonce: String?
  public let sha3Uncles: String
  public let logsBloom: String?
  public let transactionsRoot: String
  public let stateRoot: String
  public let receiptsRoot: String
  public let miner: String
  public let difficulty: String
  public let totalDifficulty: String?
  public let extraData: String
  public let size: String
  public let gasLimit: String
  public let gasUsed: String
  public let timestamp: String
  public let transactions: [String]?
  public let uncles: [String]

  // EIP-1559
  public let baseFeePerGas: String?
}

// MARK: - FeeHistory

public struct FeeHistory: Decodable, Sendable {
  public let oldestBlock: String
  public let baseFeePerGas: [String]
  public let gasUsedRatio: [Double]
  public let reward: [[String]]?
}
