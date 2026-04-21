//
//  Request.swift
//  MultiChainCore
//

/// RPC request to a blockchain node.
public struct ChainRequest: Sendable {
  public let method: String
  public let params: [AnyEncodable]
  /// Whether this request is safe to retry automatically.
  /// Read methods (eth_call, starknet_getNonce, ...) are idempotent.
  /// Write methods (eth_sendRawTransaction, starknet_addInvokeTransaction, ...) are NOT —
  /// retrying them after a successful submission can double-spend or collide on nonce.
  public let isIdempotent: Bool

  public init(
    method: String,
    params: [any Encodable & Sendable] = [],
    isIdempotent: Bool = true
  ) {
    self.method = method
    self.params = params.map { AnyEncodable($0) }
    self.isIdempotent = isIdempotent
  }
}