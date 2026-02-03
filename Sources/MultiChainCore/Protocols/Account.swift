//
//  Account.swift
//  MultiChainCore
//

import Foundation

// MARK: - Account

/// Blockchain account that can hold assets and query balances.
public protocol Account<C>: Sendable where C: Chain {
  associatedtype C: Chain

  var address: C.Address { get }
  func balanceRequest() -> ChainRequest
}

// MARK: - SignableAccount

/// Account that can sign transactions and messages.
public protocol SignableAccount<C>: Account {
  associatedtype S: Signer where S.C == C

  var signer: S { get }
  func sign(transaction: inout C.Transaction) throws
  func signMessage(_ message: Data) throws -> C.Signature
  func sendTransactionRequest(_ transaction: C.Transaction) -> ChainRequest
}

// MARK: - DeployableAccount

/// Account that requires on-chain deployment (e.g. StarkNet account contracts).
public protocol DeployableAccount<C>: SignableAccount {
  var isDeployed: Bool { get async throws }
  func deployRequest() throws -> ChainRequest
  var classHash: C.Value { get }
}

// MARK: - AccountFactory

/// Creates accounts from private keys or mnemonics.
public protocol AccountFactory<C> where C: Chain {
  associatedtype C: Chain
  associatedtype A: SignableAccount where A.C == C

  static func fromPrivateKey(_ privateKey: Data) throws -> A
  static func fromMnemonic(_ mnemonic: String, path: DerivationPath?) throws -> A
}
