//
//  EthereumProvider.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public final class EthereumProvider: Provider, @unchecked Sendable {
  public typealias C = Ethereum

  public let chain: Ethereum
  private let session: URLSession

  // MARK: - Init

  public init(chain: Ethereum, session: URLSession = .shared) {
    self.chain = chain
    self.session = session
  }

  public init(
    chainId: UInt64, name: String, url: URL, isTestnet: Bool, session: URLSession = .shared
  ) {
    self.chain = Ethereum(chainId: chainId, name: name, rpcURL: url, isTestnet: isTestnet)
    self.session = session
  }

  // MARK: - Provider Protocol

  public func send<R: Decodable>(request: ChainRequest) async throws -> R {
    let jsonRpc = buildJsonRpcRequest(request, id: 1)
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

    return try parseResponse(data)
  }

  public func send<R: Decodable>(requests: [ChainRequest]) async throws -> [Result<
    R, ProviderError
  >] {
    guard !requests.isEmpty else {
      throw ProviderError.emptyBatchRequest
    }

    let batch = buildBatchRequest(requests)
    let body = try JSONEncoder().encode(batch)

    var urlRequest = URLRequest(url: chain.rpcURL)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = body
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await session.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ProviderError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw ProviderError.networkError("HTTP \(httpResponse.statusCode)")
    }

    return try parseBatchResponse(data, count: requests.count)
  }

  // MARK: - JSON-RPC Building

  public func buildJsonRpcRequest(_ request: ChainRequest, id: Int) -> JsonRpcRequest {
    JsonRpcRequest(id: id, method: request.method, params: request.params)
  }

  public func buildBatchRequest(_ requests: [ChainRequest]) -> [JsonRpcRequest] {
    requests.enumerated().map { index, request in
      buildJsonRpcRequest(request, id: index)
    }
  }

  // MARK: - Response Parsing

  public func parseResponse<R: Decodable>(_ data: Data) throws -> R {
    let response: JsonRpcResponse<R>
    do {
      response = try JSONDecoder().decode(JsonRpcResponse<R>.self, from: data)
    } catch {
      throw ProviderError.decodingError(error.localizedDescription)
    }

    if let error = response.error {
      throw ProviderError.rpcError(code: error.code, message: error.message)
    }

    guard let result = response.result else {
      throw ProviderError.invalidResponse
    }

    return result
  }

  private func parseBatchResponse<R: Decodable>(_ data: Data, count: Int) throws -> [Result<
    R, ProviderError
  >] {
    let responses: [JsonRpcResponse<R>]
    do {
      responses = try JSONDecoder().decode([JsonRpcResponse<R>].self, from: data)
    } catch {
      throw ProviderError.decodingError(error.localizedDescription)
    }

    return responses.map { response in
      if let error = response.error {
        return .failure(.rpcError(code: error.code, message: error.message))
      }
      guard let result = response.result else {
        return .failure(.invalidResponse)
      }
      return .success(result)
    }
  }

  // MARK: - Convenience Requests

  public func blockNumberRequest() -> ChainRequest {
    ChainRequest(method: "eth_blockNumber")
  }

  public func chainIdRequest() -> ChainRequest {
    ChainRequest(method: "eth_chainId")
  }

  public func gasPriceRequest() -> ChainRequest {
    ChainRequest(method: "eth_gasPrice")
  }

  public func sendRawTransactionRequest(_ rawTx: String) -> ChainRequest {
    ChainRequest(method: "eth_sendRawTransaction", params: [rawTx])
  }

  public func transactionReceiptRequest(hash: String) -> ChainRequest {
    ChainRequest(method: "eth_getTransactionReceipt", params: [hash])
  }

  public func estimateGasRequest(transaction: EthereumTransaction) -> ChainRequest {
    ChainRequest(method: "eth_estimateGas", params: [transactionPreprocess(transaction)])
  }

  public func callRequest(transaction: EthereumTransaction, block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_call", params: [transactionPreprocess(transaction), block.rawValue])
  }

  // MARK: - Account State Requests

  public func getBalanceRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getBalance", params: [address.checksummed, block.rawValue])
  }

  public func getTransactionCountRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest
  {
    ChainRequest(method: "eth_getTransactionCount", params: [address.checksummed, block.rawValue])
  }

  public func getCodeRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getCode", params: [address.checksummed, block.rawValue])
  }

  public func getStorageAtRequest(address: EthereumAddress, position: String, block: BlockTag)
    -> ChainRequest
  {
    ChainRequest(
      method: "eth_getStorageAt", params: [address.checksummed, position, block.rawValue])
  }

  // MARK: - Block Requests

  public func getBlockByNumberRequest(block: BlockTag, fullTransactions: Bool) -> ChainRequest {
    ChainRequest(method: "eth_getBlockByNumber", params: [block.rawValue, fullTransactions])
  }

  public func getTransactionByHashRequest(hash: String) -> ChainRequest {
    ChainRequest(method: "eth_getTransactionByHash", params: [hash])
  }

  // MARK: - EIP-1559 Fee Requests

  public func feeHistoryRequest(blockCount: Int, newestBlock: BlockTag, rewardPercentiles: [Double])
    -> ChainRequest
  {
    ChainRequest(
      method: "eth_feeHistory",
      params: ["0x" + String(blockCount, radix: 16), newestBlock.rawValue, rewardPercentiles])
  }

  public func maxPriorityFeePerGasRequest() -> ChainRequest {
    ChainRequest(method: "eth_maxPriorityFeePerGas")
  }

  // MARK: - Private

  private func transactionPreprocess(_ tx: EthereumTransaction) -> [String: String] {
    var obj: [String: String] = [:]
    if let to = tx.to {
      obj["to"] = to.checksummed
    }
    if tx.value != .zero {
      obj["value"] = tx.value.hexString
    }
    if !tx.data.isEmpty {
      obj["data"] = "0x" + tx.data.map { String(format: "%02x", $0) }.joined()
    }
    obj["gas"] = "0x" + String(tx.gasLimit, radix: 16)
    return obj
  }
}
