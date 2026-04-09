//
//  StarknetRequestBuilder.swift
//  StarknetKit
//

import MultiChainCore

public enum StarknetRequestBuilder {

  // MARK: - Chain State

  public static func chainIdRequest() -> ChainRequest {
    ChainRequest(method: "starknet_chainId")
  }

  public static func blockNumberRequest() -> ChainRequest {
    ChainRequest(method: "starknet_blockNumber")
  }

  public static func blockHashAndNumberRequest() -> ChainRequest {
    ChainRequest(method: "starknet_blockHashAndNumber")
  }

  public static func syncing() -> ChainRequest {
    ChainRequest(method: "starknet_syncing")
  }

  // MARK: - Account State

  public static func getNonceRequest(address: StarknetAddress, block: StarknetBlockId = .latest)
    -> ChainRequest
  {
    ChainRequest(method: "starknet_getNonce", params: [block, address.checksummed])
  }

  public static func getClassHashAtRequest(address: StarknetAddress, block: StarknetBlockId = .latest)
    -> ChainRequest
  {
    ChainRequest(method: "starknet_getClassHashAt", params: [block, address.checksummed])
  }

  // MARK: - Contract Calls

  public static func callRequest(call: StarknetCall, block: StarknetBlockId = .latest) -> ChainRequest {
    let callObj = StarknetCallParam(
      contractAddress: call.contractAddress.hexString,
      entryPointSelector: call.entryPointSelector.hexString,
      calldata: call.calldata.map { $0.hexString }
    )
    return ChainRequest(method: "starknet_call", params: [callObj, block])
  }

  // MARK: - Fee Estimation

  public static func estimateFeeRequest(
    invokeV1: StarknetInvokeV1,
    block: StarknetBlockId = .latest
  ) -> ChainRequest {
    let tx = StarknetInvokeV1Param(tx: invokeV1)
    let txArray = [tx] as [StarknetInvokeV1Param]
    let simFlags = ["SKIP_VALIDATE"] as [String]
    return ChainRequest(method: "starknet_estimateFee", params: [txArray, simFlags, block])
  }

  public static func estimateFeeRequest(
    invokeV3: StarknetInvokeV3,
    block: StarknetBlockId = .latest
  ) -> ChainRequest {
    let tx = StarknetInvokeV3Param(tx: invokeV3)
    let txArray = [tx] as [StarknetInvokeV3Param]
    let simFlags = ["SKIP_VALIDATE"] as [String]
    return ChainRequest(method: "starknet_estimateFee", params: [txArray, simFlags, block])
  }

  public static func estimateFeeRequest(
    deployV3: StarknetDeployAccountV3,
    block: StarknetBlockId = .latest
  ) -> ChainRequest {
    let tx = StarknetDeployAccountV3Param(tx: deployV3)
    let txArray = [tx] as [StarknetDeployAccountV3Param]
    let simFlags = ["SKIP_VALIDATE"] as [String]
    return ChainRequest(method: "starknet_estimateFee", params: [txArray, simFlags, block])
  }

  // MARK: - Send Transactions

  public static func addInvokeTransactionRequest(invokeV1: StarknetInvokeV1) -> ChainRequest {
    let tx = StarknetInvokeV1Param(tx: invokeV1)
    return ChainRequest(method: "starknet_addInvokeTransaction", params: [tx])
  }

  public static func addInvokeTransactionRequest(invokeV3: StarknetInvokeV3) -> ChainRequest {
    let tx = StarknetInvokeV3Param(tx: invokeV3)
    return ChainRequest(method: "starknet_addInvokeTransaction", params: [tx])
  }

  public static func addDeployAccountTransactionRequest(deployV1: StarknetDeployAccountV1) -> ChainRequest {
    let tx = StarknetDeployAccountV1Param(tx: deployV1)
    return ChainRequest(method: "starknet_addDeployAccountTransaction", params: [tx])
  }

  public static func addDeployAccountTransactionRequest(deployV3: StarknetDeployAccountV3) -> ChainRequest {
    let tx = StarknetDeployAccountV3Param(tx: deployV3)
    return ChainRequest(method: "starknet_addDeployAccountTransaction", params: [tx])
  }

  // MARK: - Events

  public static func getEventsRequest(filter: StarknetEventFilter) -> ChainRequest {
    ChainRequest(method: "starknet_getEvents", params: [filter])
  }

  // MARK: - Transaction Queries

  public static func getTransactionByHashRequest(hash: Felt) -> ChainRequest {
    ChainRequest(method: "starknet_getTransactionByHash", params: [hash.hexString])
  }

  public static func getTransactionReceiptRequest(hash: Felt) -> ChainRequest {
    ChainRequest(method: "starknet_getTransactionReceipt", params: [hash.hexString])
  }

  public static func getTransactionStatusRequest(hash: Felt) -> ChainRequest {
    ChainRequest(method: "starknet_getTransactionStatus", params: [hash.hexString])
  }
}
