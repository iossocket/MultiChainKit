//
//  StarknetTransaction.swift
//  StarknetKit
//

import Foundation
import MultiChainCore

public struct StarknetTransaction: ChainTransaction, Sendable {
  public typealias C = Starknet

  public let hash: Data?

  public func hashForSigning() -> Data {
    fatalError("TODO: implement later")
  }

  public func encode() -> Data {
    fatalError("TODO: implement later")
  }
}
