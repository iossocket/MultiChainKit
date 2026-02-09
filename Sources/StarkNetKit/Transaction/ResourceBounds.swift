//
//  ResourceBounds.swift
//  StarknetKit
//

import BigInt
import Foundation

public struct StarknetResourceBounds: Sendable, Equatable, Codable {
  public let maxAmount: UInt64
  public let maxPricePerUnit: BigUInt

  public static let zero = StarknetResourceBounds(maxAmount: 0, maxPricePerUnit: 0)

  public init(maxAmount: UInt64, maxPricePerUnit: BigUInt) {
    self.maxAmount = maxAmount
    self.maxPricePerUnit = maxPricePerUnit
  }

  enum CodingKeys: String, CodingKey {
    case maxAmount = "max_amount"
    case maxPricePerUnit = "max_price_per_unit"
  }
}

public struct StarknetResourceBoundsMapping: Sendable, Equatable, Codable {
  public let l1Gas: StarknetResourceBounds
  public let l2Gas: StarknetResourceBounds
  public let l1DataGas: StarknetResourceBounds

  public static let zero = StarknetResourceBoundsMapping(
    l1Gas: .zero, l2Gas: .zero, l1DataGas: .zero
  )

  public init(
    l1Gas: StarknetResourceBounds,
    l2Gas: StarknetResourceBounds,
    l1DataGas: StarknetResourceBounds
  ) {
    self.l1Gas = l1Gas
    self.l2Gas = l2Gas
    self.l1DataGas = l1DataGas
  }

  enum CodingKeys: String, CodingKey {
    case l1Gas = "l1_gas"
    case l2Gas = "l2_gas"
    case l1DataGas = "l1_data_gas"
  }
}
