//
//  EvmChain.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public struct EvmChain: Chain, Sendable, Equatable, Hashable {
  public typealias Value = Wei
  public typealias Address = EthereumAddress
  public typealias Transaction = EthereumTransaction
  public typealias Signature = EthereumSignature
  public typealias Receipt = EthereumReceipt

  public let chainId: UInt64
  public let name: String
  public let rpcURL: URL
  public let isTestnet: Bool
  public let symbol: String
  public let decimals: Int
  public let explorerURL: URL?

  public var id: String { "evm:\(chainId)" }

  public init(
    chainId: UInt64, name: String, rpcURL: URL, isTestnet: Bool,
    symbol: String = "ETH", decimals: Int = 18, explorerURL: URL? = nil
  ) {
    self.chainId = chainId
    self.name = name
    self.rpcURL = rpcURL
    self.isTestnet = isTestnet
    self.symbol = symbol
    self.decimals = decimals
    self.explorerURL = explorerURL
  }

  public init(rpcURL: URL) {
    self.init(chainId: 0, name: "", rpcURL: rpcURL, isTestnet: true)
  }

  // MARK: - Predefined Networks

  public static let mainnet = EvmChain(
    chainId: 1, name: "Ethereum Mainnet",
    rpcURL: URL(string: "https://eth-mainnet.public.blastapi.io")!,
    isTestnet: false, symbol: "ETH", decimals: 18,
    explorerURL: URL(string: "https://etherscan.io")
  )

  public static let sepolia = EvmChain(
    chainId: 11_155_111, name: "Sepolia",
    rpcURL: URL(string: "https://sepolia.drpc.org")!,
    isTestnet: true, symbol: "ETH", decimals: 18,
    explorerURL: URL(string: "https://sepolia.etherscan.io")
  )

  public static let anvil = EvmChain(
    chainId: 31337, name: "Anvil",
    rpcURL: URL(string: "http://127.0.0.1:8545")!,
    isTestnet: true, symbol: "ETH", decimals: 18
  )

  public static let bsc = EvmChain(
    chainId: 56, name: "BNB Smart Chain",
    rpcURL: URL(string: "https://bsc-dataseed.binance.org")!,
    isTestnet: false, symbol: "BNB", decimals: 18,
    explorerURL: URL(string: "https://bscscan.com")
  )

  public static let polygon = EvmChain(
    chainId: 137, name: "Polygon",
    rpcURL: URL(string: "https://polygon-rpc.com")!,
    isTestnet: false, symbol: "POL", decimals: 18,
    explorerURL: URL(string: "https://polygonscan.com")
  )

  public static let arbitrumOne = EvmChain(
    chainId: 42161, name: "Arbitrum One",
    rpcURL: URL(string: "https://arb1.arbitrum.io/rpc")!,
    isTestnet: false, symbol: "ETH", decimals: 18,
    explorerURL: URL(string: "https://arbiscan.io")
  )

  public static let base = EvmChain(
    chainId: 8453, name: "Base",
    rpcURL: URL(string: "https://mainnet.base.org")!,
    isTestnet: false, symbol: "ETH", decimals: 18,
    explorerURL: URL(string: "https://basescan.org")
  )

  // MARK: - Equatable & Hashable (by chainId)

  public static func == (lhs: EvmChain, rhs: EvmChain) -> Bool {
    lhs.chainId == rhs.chainId
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(chainId)
  }
}
