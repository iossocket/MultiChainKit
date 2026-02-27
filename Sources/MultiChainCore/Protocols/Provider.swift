//
//  Provider.swift
//  MultiChainCore
//

import Foundation

// MARK: - ChainRequest

/// RPC request to a blockchain node.
public struct ChainRequest: Sendable {
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
  func send<R: Decodable>(request: ChainRequest) async throws -> R
  func send<R: Decodable>(requests: [ChainRequest]) async throws -> [Swift.Result<
    R, ProviderError
  >]
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

/// Wrapper for JSON-RPC results that may be null (e.g. pending receipt).
public struct OptionalResult<T: Decodable>: Decodable {
  public let value: T?

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self.value = nil
    } else {
      self.value = try container.decode(T.self)
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

// MARK: - PollingConfig

public struct PollingConfig: Sendable {
  public let intervalSeconds: TimeInterval
  public let timeoutSeconds: TimeInterval

  public init(intervalSeconds: TimeInterval = 3.0, timeoutSeconds: TimeInterval = 60.0) {
    self.intervalSeconds = intervalSeconds
    self.timeoutSeconds = timeoutSeconds
  }

  public static let `default` = PollingConfig()
}

// MARK: - Provider Extension

extension Provider {
  public func send<R: Decodable>(
    requests: ChainRequest...
  ) async throws -> [Swift.Result<R, ProviderError>] {
    try await send(requests: Array(requests))
  }
}

// MARK: - JsonRpcProvider

/// A Provider backed by a JSON-RPC HTTP transport.
/// Conforming types get default `send` implementations for free.
public protocol JsonRpcProvider: Provider {
  var session: URLSession { get }
}

extension JsonRpcProvider {
  public func send<R: Decodable>(request: ChainRequest) async throws -> R {
    let jsonRpc = JsonRpcRequest(id: 1, method: request.method, params: request.params)
    let body = try JSONEncoder().encode(jsonRpc)

    var urlRequest = URLRequest(url: chain.rpcURL)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = body
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await session.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ProviderError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw ProviderError.networkError("HTTP \(httpResponse.statusCode)")
    }

    return try parseJsonRpcResponse(data)
  }

  public func send<R: Decodable>(requests: [ChainRequest]) async throws -> [Swift.Result<
    R, ProviderError
  >] {
    guard !requests.isEmpty else {
      throw ProviderError.emptyBatchRequest
    }

    let batch = requests.enumerated().map { i, req in
      JsonRpcRequest(id: i, method: req.method, params: req.params)
    }
    let body = try JSONEncoder().encode(batch)

    var urlRequest = URLRequest(url: chain.rpcURL)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = body
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await session.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ProviderError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw ProviderError.networkError("HTTP \(httpResponse.statusCode)")
    }

    let responses: [JsonRpcResponse<R>]
    do {
      responses = try JSONDecoder().decode([JsonRpcResponse<R>].self, from: data)
    } catch {
      throw ProviderError.decodingError(error.localizedDescription)
    }

    return responses.map { resp in
      if let error = resp.error {
        return .failure(.rpcError(code: error.code, message: error.message))
      }
      guard let result = resp.result else {
        return .failure(.invalidResponse)
      }
      return .success(result)
    }
  }

  /// Parse a single JSON-RPC response.
  public func parseJsonRpcResponse<R: Decodable>(_ data: Data) throws -> R {
    let response: JsonRpcResponse<R>
    do {
      response = try JSONDecoder().decode(JsonRpcResponse<R>.self, from: data)
    } catch {
      throw ProviderError.decodingError(error.localizedDescription)
    }

    if let error = response.error {
      throw ProviderError.rpcError(code: error.code, message: error.message)
    }
    if let result = response.result {
      return result
    }
    // Result key missing or null (e.g. pending receipt) — decode R from "null".
    // OptionalResult decodes null as value: nil; other types will fail with decodingError.
    let nullData = Data("null".utf8)
    return try JSONDecoder().decode(R.self, from: nullData)
  }
}
