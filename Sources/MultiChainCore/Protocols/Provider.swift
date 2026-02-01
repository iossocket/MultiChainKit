//
//  Provider.swift
//  MultiChainCore
//

import Foundation

// MARK: - ChainRequest

/// RPC request to a blockchain node.
public struct ChainRequest<C: Chain, Result: Decodable>: Sendable {
    public let method: String
    public let params: [AnyEncodable]

    public init(method: String, params: [any Encodable & Sendable] = []) {
        self.method = method
        self.params = params.map { AnyEncodable($0) }
    }
}

// MARK: - Provider

/// Handles JSON-RPC communication with blockchain nodes.
public protocol Provider<C>: Sendable where C: Chain {
    associatedtype C: Chain

    var chain: C { get }
    func send<R: Decodable>(request: ChainRequest<C, R>) async throws -> R
    func send<R: Decodable>(requests: [ChainRequest<C, R>]) async throws -> [Swift.Result<R, ProviderError>]
}

// MARK: - ProviderError

public enum ProviderError: Error, Sendable, CustomStringConvertible {
    case networkError(String)
    case rpcError(code: Int, message: String)
    case decodingError(String)
    case invalidResponse
    case timeout
    case emptyBatchRequest

    public var description: String {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .rpcError(let code, let message): return "RPC error \(code): \(message)"
        case .decodingError(let message): return "Decoding error: \(message)"
        case .invalidResponse: return "Invalid response"
        case .timeout: return "Request timed out"
        case .emptyBatchRequest: return "Empty batch request"
        }
    }
}

// MARK: - JSON-RPC

public struct JsonRpcRequest: Encodable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: Int
    public let method: String
    public let params: [AnyEncodable]

    public init(id: Int = 1, method: String, params: [AnyEncodable] = []) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JsonRpcResponse<T: Decodable>: Decodable, Sendable where T: Sendable {
    public let jsonrpc: String
    public let id: Int
    public let result: T?
    public let error: JsonRpcError?
}

public struct JsonRpcError: Decodable, Sendable {
    public let code: Int
    public let message: String
    public let data: String?
}

// MARK: - AnyEncodable

/// Type-erased Encodable for heterogeneous parameter arrays.
public struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    public init<T: Encodable & Sendable>(_ value: T) {
        self._encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Provider Extension

extension Provider {
    public func send<R: Decodable>(
        requests: ChainRequest<C, R>...
    ) async throws -> [Swift.Result<R, ProviderError>] {
        try await send(requests: Array(requests))
    }
}
