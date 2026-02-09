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

  public var id: String { "starknet:\(chainId.hexString)" }

  public init(chainId: Felt, name: String, rpcURL: URL, isTestnet: Bool) {
    self.chainId = chainId
    self.name = name
    self.rpcURL = rpcURL
    self.isTestnet = isTestnet
  }

  // MARK: - Predefined Networks

  public static let mainnet = Starknet(
    chainId: Felt.fromShortString("SN_MAIN"),
    name: "StarkNet Mainnet",
    rpcURL: URL(string: "https://starknet-mainnet.public.blastapi.io")!,
    isTestnet: false
  )

  public static let sepolia = Starknet(
    chainId: Felt.fromShortString("SN_SEPOLIA"),
    name: "StarkNet Sepolia",
    rpcURL: URL(string: "https://starknet-sepolia.public.blastapi.io")!,
    isTestnet: true
  )

  // MARK: - Equatable & Hashable

  public static func == (lhs: Starknet, rhs: Starknet) -> Bool {
    lhs.chainId == rhs.chainId
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(chainId)
  }
}
