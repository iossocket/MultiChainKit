//
//  Chain.swift
//  MultiChainCore
//

import Foundation

// MARK: - Chain

/// A blockchain network with its associated types.
public protocol Chain: Sendable, Identifiable {
  associatedtype Value: ChainValue
  associatedtype Address: ChainAddress
  associatedtype Transaction: ChainTransaction
  associatedtype Signature: ChainSignature
  associatedtype Receipt: ChainReceipt

  var id: String { get }
  var name: String { get }
  var isTestnet: Bool { get }
  var rpcURL: URL { get }
}

// MARK: - ChainValue

/// Native currency unit (Wei, Felt, etc.)
public protocol ChainValue: Sendable, Equatable, Comparable, Hashable,
  CustomStringConvertible, Codable,
  ExpressibleByIntegerLiteral
{
  init?(_ hex: String)
  init(_ int: UInt64)
  var hexString: String { get }
  static var zero: Self { get }
}

// MARK: - ChainAddress

/// Blockchain address (account or contract identifier).
public protocol ChainAddress: Sendable, Equatable, Hashable,
  CustomStringConvertible, Codable
{
  init?(_ string: String)
  init(_ data: Data)
  var checksummed: String { get }
  var data: Data { get }
  static var zero: Self { get }
}

// MARK: - ChainTransaction

public protocol ChainTransaction: Sendable, Codable {
  associatedtype C: Chain where C.Transaction == Self

  var hash: Data? { get }
  func hashForSigning() -> Data
  func encode() -> Data
}

// MARK: - ChainSignature

public protocol ChainSignature: Sendable, Codable {
  var rawData: Data { get }
}

// MARK: - ChainReceipt

public protocol ChainReceipt: Sendable, Codable {
  var transactionHash: Data { get }
  var isSuccess: Bool { get }
  var blockNumber: UInt64? { get }
}
