//
//  ChainError.swift
//  MultiChainCore
//

import Foundation

public enum ChainError: Error, Sendable, Equatable, CustomStringConvertible {
  case invalidAddress
  case invalidTransaction(String)
  case invalidSignature(String)
  case transactionFailed(reason: String, txHash: String)
  case encodingError
  case decodingError
  case valueOutOfRange
  case accountNotDeployed
  case insufficientBalance
  case invalidNonce
  case noProvider
  case other

  public var description: String {
    switch self {
    case .invalidAddress: return "Invalid address"
    case .invalidTransaction(let msg): return "Invalid transaction: \(msg)"
    case .invalidSignature(let msg): return "Invalid signature: \(msg)"
    case .transactionFailed(let reason, let txHash): return "Transaction failed (\(reason)), txHash: \(txHash)"
    case .encodingError: return "Encoding error"
    case .decodingError: return "Decoding error"
    case .valueOutOfRange: return "Value out of range"
    case .accountNotDeployed: return "Account not deployed"
    case .insufficientBalance: return "Insufficient balance"
    case .invalidNonce: return "Invalid nonce"
    case .noProvider: return "No provider"
    case .other: return "Other error"
    }
  }
}
