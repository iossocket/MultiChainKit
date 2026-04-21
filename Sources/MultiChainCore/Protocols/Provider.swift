//
//  Provider.swift
//  MultiChainCore
//

import Foundation

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

public enum ProviderError: Error, Sendable, Equatable, CustomStringConvertible {
  case networkError(String)
  /// HTTP non-2xx response. Body is included when available for error inspection / retry decisions.
  case http(status: Int, body: Data?)
  case rpcError(code: Int, message: String)
  case decodingError(String)
  case invalidResponse
  case timeout
  /// The request was cancelled (Task cancellation or URLError.cancelled).
  case cancelled
  case emptyBatchRequest
  case emptyResult

  public var description: String {
    switch self {
    case .networkError(let msg): return "Network error: \(msg)"
    case .http(let status, _): return "HTTP \(status)"
    case .rpcError(let code, let message): return "RPC error \(code): \(message)"
    case .decodingError(let msg): return "Decoding error: \(msg)"
    case .invalidResponse: return "Invalid response"
    case .timeout: return "Timeout"
    case .cancelled: return "Cancelled"
    case .emptyBatchRequest: return "Empty batch request"
    case .emptyResult: return "Empty result"
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

public enum JSONValue: Decodable, Sendable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null
  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null; return }
    if let v = try? c.decode(Bool.self) { self = .bool(v); return }
    if let v = try? c.decode(Double.self) { self = .number(v); return }
    if let v = try? c.decode(String.self) { self = .string(v); return }
    if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
    if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
    throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
  }
}

public struct JsonRpcError: Decodable, Sendable {
  public let code: Int
  public let message: String
  public let data: JSONValue?
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

// MARK: - RetryPolicy

/// Describes how a `JsonRpcProvider` should retry failed RPC calls.
///
/// Only **idempotent** requests (`ChainRequest.isIdempotent == true`) are retried.
/// Write methods (`eth_sendRawTransaction`, `starknet_addInvokeTransaction`, ...) must never
/// be retried automatically: the node may have accepted the first submission and a retry can
/// collide on nonce or double-spend.
public struct RetryPolicy: Sendable, Equatable {
  /// Total number of attempts, including the first one. `maxAttempts == 1` means no retry.
  public let maxAttempts: Int
  /// Base delay for the exponential backoff, in seconds. Typical: 0.2s.
  public let baseDelay: TimeInterval
  /// Upper bound on a single delay, in seconds. Typical: 5s.
  public let maxDelay: TimeInterval
  /// Multiplicative jitter fraction applied to each delay, in [0, 1].
  /// e.g. `0.2` means the delay is scaled by a uniform random factor in `[0.8, 1.2]`.
  /// Prevents thundering herds when many clients retry simultaneously.
  public let jitter: Double
  /// HTTP status codes that should trigger a retry.
  /// Note: `429 Too Many Requests` is intentionally **NOT** retried by default.
  /// Rate-limit conditions are persistent (seconds to minutes) and the caller has
  /// better context to react (switch provider, back off at app layer, surface in UI).
  /// Auto-retrying just burns quota and risks further penalty from the provider.
  public let retryableHTTPStatusCodes: Set<Int>
  /// JSON-RPC error codes that should trigger a retry (node-side transient errors).
  public let retryableRPCErrorCodes: Set<Int>

  public init(
    maxAttempts: Int,
    baseDelay: TimeInterval,
    maxDelay: TimeInterval,
    jitter: Double,
    retryableHTTPStatusCodes: Set<Int>,
    retryableRPCErrorCodes: Set<Int>
  ) {
    self.maxAttempts = maxAttempts
    self.baseDelay = baseDelay
    self.maxDelay = maxDelay
    self.jitter = jitter
    self.retryableHTTPStatusCodes = retryableHTTPStatusCodes
    self.retryableRPCErrorCodes = retryableRPCErrorCodes
  }

  /// Sensible production default: 3 attempts, 200ms base, 5s cap, 20% jitter.
  public static let `default` = RetryPolicy(
    maxAttempts: 3,
    baseDelay: 0.2,
    maxDelay: 5.0,
    jitter: 0.2,
    retryableHTTPStatusCodes: [408, 500, 502, 503, 504],  // 429 intentionally omitted
    retryableRPCErrorCodes: [-32603]  // JSON-RPC internal error
  )

  /// Disables retry entirely. Useful for opt-out at call sites.
  public static let none = RetryPolicy(
    maxAttempts: 1,
    baseDelay: 0,
    maxDelay: 0,
    jitter: 0,
    retryableHTTPStatusCodes: [],
    retryableRPCErrorCodes: []
  )

  /// Returns the delay to wait **before** `attempt` (1-based).
  /// `attempt == 1` is the first retry (i.e. after the initial try failed).
  /// Implementation should compute `min(baseDelay * 2^(attempt-1), maxDelay)` and apply jitter.
  public func delay(forAttempt attempt: Int) -> TimeInterval {
    let exponential = baseDelay * pow(2.0, Double(attempt - 1))
    let clamped = min(exponential, maxDelay)
    let factor = Double.random(in: (1 - jitter)...(1 + jitter))
    return clamped * factor
  }

  /// Whether the given error is eligible for retry under this policy.
  /// `.cancelled` must never retry. Network transport errors (connection dropped, DNS, timeout)
  /// are generally retryable. `.http` / `.rpcError` consult the whitelist sets.
  public func shouldRetry(_ error: ProviderError) -> Bool {
    switch error {
    case .cancelled, .decodingError, .invalidResponse,
         .emptyBatchRequest, .emptyResult:
      return false
    case .http(let status, _):
      return retryableHTTPStatusCodes.contains(status)
    case .rpcError(let code, _):
      return retryableRPCErrorCodes.contains(code)
    case .networkError, .timeout:
      return maxAttempts > 1   // 传输层故障只要 policy 允许重试就重试
    }
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
    do {
      try Task.checkCancellation()
    } catch {
      throw ProviderError.cancelled
    }

    let jsonRpc = JsonRpcRequest(id: 1, method: request.method, params: request.params)
    let body = try JSONEncoder().encode(jsonRpc)

    var urlRequest = URLRequest(url: chain.rpcURL)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = body
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: urlRequest)
    } catch let urlError as URLError where urlError.code == .cancelled {
      throw ProviderError.cancelled
    } catch is CancellationError {
      throw ProviderError.cancelled
    } catch {
      throw ProviderError.networkError(error.localizedDescription)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ProviderError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw ProviderError.http(status: httpResponse.statusCode, body: data)
    }

    return try parseJsonRpcResponse(data)
  }

  public func send<R: Decodable>(requests: [ChainRequest]) async throws -> [Swift.Result<
    R, ProviderError
  >] {
    guard !requests.isEmpty else {
      throw ProviderError.emptyBatchRequest
    }
    do {
      try Task.checkCancellation()
    } catch {
      throw ProviderError.cancelled
    }

    let batch = requests.enumerated().map { i, req in
      JsonRpcRequest(id: i, method: req.method, params: req.params)
    }
    let body = try JSONEncoder().encode(batch)

    var urlRequest = URLRequest(url: chain.rpcURL)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = body
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: urlRequest)
    } catch let urlError as URLError where urlError.code == .cancelled {
      throw ProviderError.cancelled
    } catch is CancellationError {
      throw ProviderError.cancelled
    } catch {
      throw ProviderError.networkError(error.localizedDescription)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ProviderError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw ProviderError.http(status: httpResponse.statusCode, body: data)
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

  // MARK: - Retry Overloads

  /// Send a single request with an explicit retry policy.
  ///
  /// - If `request.isIdempotent == false`, the policy is ignored and the request is attempted once.
  /// - Between attempts, sleeps for `policy.delay(forAttempt:)`.
  /// - Task cancellation during a backoff sleep maps to `ProviderError.cancelled`.
  public func send<R: Decodable>(
    request: ChainRequest,
    retryPolicy policy: RetryPolicy
  ) async throws -> R {
    if !request.isIdempotent {
      return try await self.send(request: request)
    }
    return try await performWithRetry(policy: policy) {
      try await self.send(request: request)
    }
  }

  /// Batch variant with the same retry semantics as the single-request overload.
  /// The batch is retried as a whole only when **every** request in it is idempotent.
  public func send<R: Decodable>(
    requests: [ChainRequest],
    retryPolicy policy: RetryPolicy
  ) async throws -> [Swift.Result<R, ProviderError>] {
    guard requests.allSatisfy(\.isIdempotent) else {
      return try await send(requests: requests)
    }
    return try await performWithRetry(policy: policy) {
      try await self.send(requests: requests)
    }
  }

  private func performWithRetry<T>(
    policy: RetryPolicy,
    operation: () async throws -> T
  ) async throws -> T {
    for i in 0..<policy.maxAttempts {
      do {
        return try await operation()
      } catch {
        if let providerError = error as? ProviderError, !policy.shouldRetry(providerError) {
          throw error
        }
        if i < policy.maxAttempts - 1 {
          do {
            try await Task.sleep(for: .seconds(policy.delay(forAttempt: i + 1)))
          } catch {
            throw ProviderError.cancelled
          }
        } else {
          throw error
        }
      }
    }
    preconditionFailure("unreachable: loop must have returned or thrown")
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
    // Result key missing or null (e.g. pending receipt).
    // Decode R from "null" so OptionalResult decodes as value: nil.
    // If R cannot represent null, treat this as an invalid response instead of leaking DecodingError.
    let nullData = Data("null".utf8)
    do {
      return try JSONDecoder().decode(R.self, from: nullData)
    } catch {
      throw ProviderError.invalidResponse
    }
  }
}
