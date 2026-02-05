//
//  Ethereum.swift
//  EthereumKit
//

import Foundation
import MultiChainCore

public struct Ethereum: Chain, Sendable, Equatable, Hashable {
  public typealias Value = Wei
  public typealias Address = EthereumAddress
  public typealias Transaction = EthereumTransaction
  public typealias Signature = EthereumSignature
  public typealias Receipt = EthereumReceipt

  public let chainId: UInt64
  public let name: String
  public let rpcURL: URL
  public let isTestnet: Bool

  public var id: String { "ethereum:\(chainId)" }

  public init(chainId: UInt64, name: String, rpcURL: URL, isTestnet: Bool) {
    self.chainId = chainId
    self.name = name
    self.rpcURL = rpcURL
    self.isTestnet = isTestnet
  }

  // MARK: - Predefined Networks

  public static let mainnet = Ethereum(
    chainId: 1,
    name: "Ethereum Mainnet",
    rpcURL: URL(string: "https://eth-mainnet.public.blastapi.io")!,
    isTestnet: false
  )

  public static let sepolia = Ethereum(
    chainId: 11_155_111,
    name: "Sepolia",
    rpcURL: URL(string: "https://eth-sepolia.public.blastapi.io")!,
    isTestnet: true
  )

  // MARK: - Equatable & Hashable (by chainId)

  public static func == (lhs: Ethereum, rhs: Ethereum) -> Bool {
    lhs.chainId == rhs.chainId
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(chainId)
  }
}
