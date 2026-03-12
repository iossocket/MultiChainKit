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
        request: EthereumRequestBuilder.transactionReceiptRequest(hash: hash))

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
      let blockHex: String = try await send(request: EthereumRequestBuilder.blockNumberRequest())
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
}
