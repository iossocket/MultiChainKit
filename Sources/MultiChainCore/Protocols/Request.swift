//
//  Request.swift
//  MultiChainCore
//

/// RPC request to a blockchain node.
public struct ChainRequest: Sendable {
  public let method: String
  public let params: [AnyEncodable]

  public init(method: String, params: [any Encodable & Sendable] = []) {
    self.method = method
    self.params = params.map { AnyEncodable($0) }
  }
}