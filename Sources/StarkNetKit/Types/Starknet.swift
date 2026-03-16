//
//  Starknet.swift
//  StarknetKit
//
//  StarkNet chain definition conforming to Chain protocol.
//

import Foundation
import MultiChainCore

public struct Starknet: Chain, Sendable, Equatable, Hashable {
  public typealias Value = Felt
  public typealias Address = StarknetAddress
  public typealias Transaction = StarknetTransaction
  public typealias Signature = StarknetSignature
  public typealias Receipt = StarknetReceipt

  public let chainId: Felt
  public let name: String
  public let rpcURL: URL
  public let isTestnet: Bool
  public let symbol: String
  public let decimals: Int
  public let explorerURL: URL?

  public var id: String { "starknet:\(chainId.hexString)" }

  public init(
    chainId: Felt, name: String, rpcURL: URL, isTestnet: Bool, 
    symbol: String = "STRK", decimals: Int = 18, explorerURL: URL? = nil
  ) {
    self.chainId = chainId
    self.name = name
    self.rpcURL = rpcURL
    self.isTestnet = isTestnet
    self.symbol = symbol
    self.decimals = decimals
    self.explorerURL = explorerURL
  }

  // MARK: - Predefined Networks

  public static let mainnet = Starknet(
    chainId: Felt.fromShortString("SN_MAIN"),
    name: "StarkNet Mainnet",
    rpcURL: URL(string: "https://starknet-mainnet.public.blastapi.io")!,
    isTestnet: false,
    symbol: "STRK",
    decimals: 18,
    explorerURL: URL(string: "https://voyager.online")!,
  )

  public static let sepolia = Starknet(
    chainId: Felt.fromShortString("SN_SEPOLIA"),
    name: "StarkNet Sepolia",
    rpcURL: URL(string: "https://starknet-sepolia.public.blastapi.io")!,
    isTestnet: false,
    symbol: "STRK",
    decimals: 18,
    explorerURL: URL(string: "https://sepolia.voyager.online")!,
  )

  public static let devnet = Starknet(
    chainId: Felt.fromShortString("SN_SEPOLIA"),
    name: "StarkNet Devnet",
    rpcURL: URL(string: "http://127.0.0.1:5050")!,
    isTestnet: true,
  )

  // MARK: - Equatable & Hashable

  public static func == (lhs: Starknet, rhs: Starknet) -> Bool {
    lhs.chainId == rhs.chainId
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(chainId)
  }
}

// MARK: - Native Token Addresses

extension Starknet {
  public enum Token {
    public static let ETH = Felt(
      "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    public static let STRK = Felt(
      "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab072018f4287c938d")!
  }
}
