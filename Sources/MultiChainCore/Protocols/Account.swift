//
//  Account.swift
//  MultiChainCore
//

import Foundation

/// Account that can sign transactions and messages.
public protocol Account<C>: Sendable where C: Chain {
  associatedtype C: Chain

  var address: C.Address { get }
  var publicKey: Data? { get }
  var provider: (any Provider<C>)? { get }

  func sign(hash: Data) throws -> C.Signature
  func sign(transaction: inout C.Transaction) throws
  func signMessage(_ message: Data) throws -> C.Signature
  
  func sendTransaction(_ transaction: C.Transaction) async throws -> TxHash
}

/// Account that requires on-chain deployment (e.g. Starknet account contracts).
public protocol DeployableAccount<C>: Account {
  var isDeployed: Bool { get async throws }
  var classHash: C.Value { get }
}