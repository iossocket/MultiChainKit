//
//  EthereumRequestBuilder.swift
//  EthereumKit
//

import MultiChainCore

public enum EthereumRequestBuilder {
  public static func blockNumberRequest() -> ChainRequest {
    ChainRequest(method: "eth_blockNumber")
  }

  public static func chainIdRequest() -> ChainRequest {
    ChainRequest(method: "eth_chainId")
  }

  public static func gasPriceRequest() -> ChainRequest {
    ChainRequest(method: "eth_gasPrice")
  }

  public static func sendRawTransactionRequest(_ rawTx: String) -> ChainRequest {
    ChainRequest(method: "eth_sendRawTransaction", params: [rawTx])
  }

  public static func transactionReceiptRequest(hash: String) -> ChainRequest {
    ChainRequest(method: "eth_getTransactionReceipt", params: [hash])
  }

  public static func estimateGasRequest(transaction: EthereumTransaction, from: EthereumAddress? = nil) -> ChainRequest {
    ChainRequest(method: "eth_estimateGas", params: [transactionPreprocess(transaction, from: from)])
  }

  public static func callRequest(transaction: EthereumTransaction, block: BlockTag, from: EthereumAddress? = nil) -> ChainRequest {
    ChainRequest(method: "eth_call", params: [transactionPreprocess(transaction, from: from), block.rawValue])
  }

  // MARK: - Account State Requests

  public static func getBalanceRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getBalance", params: [address.checksummed, block.rawValue])
  }

  public static func getTransactionCountRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest
  {
    ChainRequest(method: "eth_getTransactionCount", params: [address.checksummed, block.rawValue])
  }

  public static func getCodeRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
    ChainRequest(method: "eth_getCode", params: [address.checksummed, block.rawValue])
  }

  public static func getStorageAtRequest(address: EthereumAddress, position: String, block: BlockTag)
    -> ChainRequest
  {
    ChainRequest(
      method: "eth_getStorageAt", params: [address.checksummed, position, block.rawValue])
  }

  // MARK: - Block Requests

  public static func getBlockByNumberRequest(block: BlockTag, fullTransactions: Bool) -> ChainRequest {
    ChainRequest(method: "eth_getBlockByNumber", params: [block.rawValue, fullTransactions])
  }

  public static func getTransactionByHashRequest(hash: String) -> ChainRequest {
    ChainRequest(method: "eth_getTransactionByHash", params: [hash])
  }

  // MARK: - EIP-1559 Fee Requests

  public static func feeHistoryRequest(blockCount: Int, newestBlock: BlockTag, rewardPercentiles: [Double])
    -> ChainRequest
  {
    ChainRequest(
      method: "eth_feeHistory",
      params: ["0x" + String(blockCount, radix: 16), newestBlock.rawValue, rewardPercentiles])
  }

  public static func maxPriorityFeePerGasRequest() -> ChainRequest {
    ChainRequest(method: "eth_maxPriorityFeePerGas")
  }

    // MARK: - Private

  private static func transactionPreprocess(_ tx: EthereumTransaction, from: EthereumAddress? = nil) -> [String: String] {
    var obj: [String: String] = [:]
    if let from = from {
      obj["from"] = from.checksummed
    }
    if let to = tx.to {
      obj["to"] = to.checksummed
    }
    if tx.value != .zero {
      obj["value"] = tx.value.hexString
    }
    if !tx.data.isEmpty {
      obj["data"] = "0x" + tx.data.map { String(format: "%02x", $0) }.joined()
    }
    if tx.gasLimit > 0 {
      obj["gas"] = "0x" + String(tx.gasLimit, radix: 16)
    }
    return obj
  }
}