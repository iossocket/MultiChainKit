//
//  EthereumProvider.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public final class EthereumProvider: JsonRpcProvider, @unchecked Sendable {
  public typealias C = EvmChain

  public let chain: EvmChain
  public let session: URLSession

  // MARK: - Init

  public init(chain: EvmChain, session: URLSession = .shared) {
    self.chain = chain
    self.session = session
  }

  public init(
    chainId: UInt64, name: String, url: URL, isTestnet: Bool, session: URLSession = .shared
  ) {
    self.chain = EvmChain(chainId: chainId, name: name, rpcURL: url, isTestnet: isTestnet)
    self.session = session
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

  // MARK: - Wait For Transaction

  /// Poll until a transaction is confirmed, then return the receipt.
  public func waitForTransaction(
    hash: String,
    confirmations: UInt64 = 1,
    config: PollingConfig = .default
  ) async throws -> EthereumReceipt {
    let deadline = Date().addingTimeInterval(config.timeoutSeconds)
    let sleepNanos = UInt64(config.intervalSeconds * 1_000_000_000)

    while Date() < deadline {
      let wrapper: OptionalResult<EthereumReceipt> = try await send(
        request: transactionReceiptRequest(hash: hash))

      guard let receipt = wrapper.value else {
        try await Task.sleep(nanoseconds: sleepNanos)
        continue
      }

      guard receipt.isSuccess else {
        throw ChainError.transactionFailed(reason: "status: \(receipt.status)", txHash: hash)
      }

      if confirmations <= 1 {
        return receipt
      }

      // Check confirmation depth
      let blockHex: String = try await send(request: blockNumberRequest())
      if let current = UInt64(blockHex.dropFirst(2), radix: 16),
        let receiptBlock = receipt.blockNumber,
        current >= receiptBlock + confirmations - 1
      {
        return receipt
      }

      try await Task.sleep(nanoseconds: sleepNanos)
    }

    throw ProviderError.timeout
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
