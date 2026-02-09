//
//  StarknetReceipt.swift
//  StarknetKit
//

import Foundation
import MultiChainCore

public struct StarknetReceipt: ChainReceipt, Sendable {
  public let transactionHash: Data
  public let isSuccess: Bool
  public let blockNumber: UInt64?
}
