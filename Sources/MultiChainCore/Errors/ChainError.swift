//
//  ChainError.swift
//  MultiChainCore
//

import Foundation

// MARK: - ChainError

public enum ChainError: Error, Sendable, CustomStringConvertible {
    case invalidAddress(String)
    case invalidTransaction(String)
    case invalidSignature(String)
    case transactionFailed(String)
    case encodingError(String)
    case decodingError(String)
    case valueOutOfRange(String)
    case accountNotDeployed
    case insufficientBalance
    case invalidNonce
    case other(String)

    public var description: String {
        switch self {
        case .invalidAddress(let address): return "Invalid address: \(address)"
        case .invalidTransaction(let reason): return "Invalid transaction: \(reason)"
        case .invalidSignature(let reason): return "Invalid signature: \(reason)"
        case .transactionFailed(let reason): return "Transaction failed: \(reason)"
        case .encodingError(let reason): return "Encoding error: \(reason)"
        case .decodingError(let reason): return "Decoding error: \(reason)"
        case .valueOutOfRange(let reason): return "Value out of range: \(reason)"
        case .accountNotDeployed: return "Account not deployed"
        case .insufficientBalance: return "Insufficient balance"
        case .invalidNonce: return "Invalid nonce"
        case .other(let message): return message
        }
    }
}

// MARK: - WalletError

public enum WalletError: Error, Sendable, CustomStringConvertible {
    case invalidMnemonic
    case notConnected(String)
    case unsupportedChain(String)
    case accountNotAvailable

    public var description: String {
        switch self {
        case .invalidMnemonic: return "Invalid mnemonic"
        case .notConnected(let chain): return "Not connected to \(chain)"
        case .unsupportedChain(let chain): return "Unsupported chain: \(chain)"
        case .accountNotAvailable: return "Account not available"
        }
    }
}
