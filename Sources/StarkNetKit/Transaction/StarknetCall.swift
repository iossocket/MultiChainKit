//
//  StarknetCall.swift
//  StarknetKit
//

import Foundation

public struct StarknetCall: Sendable, Equatable {
  public let contractAddress: Felt
  public let entryPointSelector: Felt
  public let calldata: [Felt]

  public init(contractAddress: Felt, entryPointSelector: Felt, calldata: [Felt]) {
    self.contractAddress = contractAddress
    self.entryPointSelector = entryPointSelector
    self.calldata = calldata
  }

  /// Convenience: create a call using a function name string (computes selector via sn_keccak).
  public init(contractAddress: Felt, entrypoint: String, calldata: [Felt]) {
    self.contractAddress = contractAddress
    self.entryPointSelector = StarknetKeccak.functionSelector(entrypoint)
    self.calldata = calldata
  }
}

// MARK: - Multicall Encoding

extension StarknetCall {
  /// Encode multiple calls into a flat calldata array for account execute.
  /// Format: [num_calls, to1, selector1, data1_len, data1..., to2, selector2, data2_len, data2..., ...]
  public static func encodeMulticall(_ calls: [StarknetCall]) -> [Felt] {
    var results: [Felt] = [Felt(UInt64(calls.count))]
    for call in calls {
      results.append(call.contractAddress)
      results.append(call.entryPointSelector)
      results.append(Felt(UInt64(call.calldata.count)))
      results.append(contentsOf: call.calldata)
    }
    return results
  }
}
