//
//  StarknetProviderTests.swift
//  StarknetKitTests
//
//  Tests for StarknetProvider request building and parameter serialization.
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

// MARK: - Request Building

@Suite("StarknetProvider Requests")
struct StarknetProviderRequestTests {

  let provider = StarknetProvider(chain: .sepolia)

  // MARK: - Chain State

  @Test("chainId request method")
  func chainIdRequest() {
    let req = provider.chainIdRequest()
    #expect(req.method == "starknet_chainId")
  }

  @Test("blockNumber request method")
  func blockNumberRequest() {
    let req = provider.blockNumberRequest()
    #expect(req.method == "starknet_blockNumber")
  }

  // MARK: - Account State

  @Test("getNonce request method and params")
  func getNonceRequest() {
    let addr = StarknetAddress("0x1234")!
    let req = provider.getNonceRequest(address: addr)
    #expect(req.method == "starknet_getNonce")
    #expect(req.params.count == 2)
  }

  @Test("getClassHashAt request method")
  func getClassHashAtRequest() {
    let addr = StarknetAddress("0x1234")!
    let req = provider.getClassHashAtRequest(address: addr)
    #expect(req.method == "starknet_getClassHashAt")
    #expect(req.params.count == 2)
  }

  // MARK: - Contract Calls

  @Test("call request method and params")
  func callRequest() {
    let call = StarknetCall(
      contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [Felt(0x3)])
    let req = provider.callRequest(call: call)
    #expect(req.method == "starknet_call")
    #expect(req.params.count == 2)
  }

  // MARK: - Transaction Queries

  @Test("getTransactionByHash request")
  func getTransactionByHash() {
    let hash = Felt(0xabc)
    let req = provider.getTransactionByHashRequest(hash: hash)
    #expect(req.method == "starknet_getTransactionByHash")
  }

  @Test("getTransactionReceipt request")
  func getTransactionReceipt() {
    let hash = Felt(0xabc)
    let req = provider.getTransactionReceiptRequest(hash: hash)
    #expect(req.method == "starknet_getTransactionReceipt")
  }

  @Test("getTransactionStatus request")
  func getTransactionStatus() {
    let hash = Felt(0xabc)
    let req = provider.getTransactionStatusRequest(hash: hash)
    #expect(req.method == "starknet_getTransactionStatus")
  }

  // MARK: - Send Transactions

  @Test("addInvokeTransaction V1 request")
  func addInvokeV1() {
    let tx = StarknetInvokeV1(
      senderAddress: Felt(0x1), calldata: [Felt(0x2)],
      maxFee: Felt(100), nonce: Felt(0),
      chainId: Felt.fromShortString("SN_SEPOLIA"),
      signature: [Felt(0xa1), Felt(0xa2)]
    )
    let req = provider.addInvokeTransactionRequest(invokeV1: tx)
    #expect(req.method == "starknet_addInvokeTransaction")
    #expect(req.params.count == 1)
  }

  @Test("addInvokeTransaction V3 request")
  func addInvokeV3() {
    let tx = StarknetInvokeV3(
      senderAddress: Felt(0x1), calldata: [Felt(0x2)],
      resourceBounds: .zero, nonce: Felt(0),
      chainId: Felt.fromShortString("SN_SEPOLIA"),
      signature: [Felt(0xa), Felt(0xb)]
    )
    let req = provider.addInvokeTransactionRequest(invokeV3: tx)
    #expect(req.method == "starknet_addInvokeTransaction")
    #expect(req.params.count == 1)
  }

  @Test("addDeployAccountTransaction V1 request")
  func addDeployAccountV1() {
    let tx = StarknetDeployAccountV1(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], maxFee: Felt(500),
      nonce: .zero, chainId: Felt.fromShortString("SN_SEPOLIA")
    )
    let req = provider.addDeployAccountTransactionRequest(deployV1: tx)
    #expect(req.method == "starknet_addDeployAccountTransaction")
    #expect(req.params.count == 1)
  }
}

// MARK: - Block ID Encoding

@Suite("StarknetBlockId")
struct BlockIdTests {

  @Test("latest encodes as string")
  func latestEncoding() throws {
    let data = try JSONEncoder().encode(StarknetBlockId.latest)
    let str = String(data: data, encoding: .utf8)!
    #expect(str == "\"latest\"")
  }

  @Test("pending encodes as string")
  func pendingEncoding() throws {
    let data = try JSONEncoder().encode(StarknetBlockId.pending)
    let str = String(data: data, encoding: .utf8)!
    #expect(str == "\"pending\"")
  }

  @Test("number encodes as object")
  func numberEncoding() throws {
    let data = try JSONEncoder().encode(StarknetBlockId.number(12345))
    let str = String(data: data, encoding: .utf8)!
    #expect(str.contains("block_number"))
    #expect(str.contains("12345"))
  }

  @Test("hash encodes as object")
  func hashEncoding() throws {
    let data = try JSONEncoder().encode(StarknetBlockId.hash(Felt(0xabc)))
    let str = String(data: data, encoding: .utf8)!
    #expect(str.contains("block_hash"))
    #expect(str.contains("abc"))
  }
}

// MARK: - RPC Param Serialization

@Suite("RPC Param Serialization")
struct RpcParamSerializationTests {

  @Test("InvokeV1Param serializes correctly")
  func invokeV1Param() throws {
    let tx = StarknetInvokeV1(
      senderAddress: Felt(0xabc), calldata: [Felt(1), Felt(2)],
      maxFee: Felt(1000), nonce: Felt(5),
      chainId: Felt.fromShortString("SN_SEPOLIA"),
      signature: [Felt(0x11), Felt(0x22)]
    )
    let param = StarknetInvokeV1Param(tx: tx)
    let data = try JSONEncoder().encode(param)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["type"] as? String == "INVOKE")
    #expect(json["version"] as? String == "0x1")
    #expect(json["sender_address"] as? String == Felt(0xabc).hexString)
    #expect((json["calldata"] as? [String])?.count == 2)
    #expect((json["signature"] as? [String])?.count == 2)
    #expect(json["nonce"] as? String == Felt(5).hexString)
  }

  @Test("InvokeV3Param serializes DA modes")
  func invokeV3ParamDAModes() throws {
    let tx = StarknetInvokeV3(
      senderAddress: Felt(0x1), calldata: [],
      resourceBounds: .zero, nonce: Felt(0),
      nonceDAMode: .l2, feeDAMode: .l1,
      chainId: Felt.fromShortString("SN_SEPOLIA")
    )
    let param = StarknetInvokeV3Param(tx: tx)
    let data = try JSONEncoder().encode(param)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["version"] as? String == "0x3")
    #expect(json["nonce_data_availability_mode"] as? String == "L2")
    #expect(json["fee_data_availability_mode"] as? String == "L1")
  }

  @Test("InvokeV3Param serializes resource bounds")
  func invokeV3ParamResourceBounds() throws {
    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: 1000, maxPricePerUnit: BigUInt(500)),
      l2Gas: .zero,
      l1DataGas: .zero
    )
    let tx = StarknetInvokeV3(
      senderAddress: Felt(0x1), calldata: [],
      resourceBounds: bounds, nonce: Felt(0),
      chainId: Felt.fromShortString("SN_SEPOLIA")
    )
    let param = StarknetInvokeV3Param(tx: tx)
    let data = try JSONEncoder().encode(param)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    let rb = json["resource_bounds"] as! [String: Any]
    let l1Gas = rb["l1_gas"] as! [String: Any]
    #expect(l1Gas["max_amount"] as? String == "0x3e8")
    #expect(l1Gas["max_price_per_unit"] as? String == "0x1f4")
  }

  @Test("DeployAccountV1Param serializes correctly")
  func deployAccountV1Param() throws {
    let tx = StarknetDeployAccountV1(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], maxFee: Felt(500),
      nonce: .zero, chainId: Felt.fromShortString("SN_SEPOLIA")
    )
    let param = StarknetDeployAccountV1Param(tx: tx)
    let data = try JSONEncoder().encode(param)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["type"] as? String == "DEPLOY_ACCOUNT")
    #expect(json["version"] as? String == "0x1")
    #expect(json["class_hash"] as? String == Felt(0x111).hexString)
    #expect(json["contract_address_salt"] as? String == Felt(0x222).hexString)
    #expect((json["constructor_calldata"] as? [String])?.count == 1)
  }
}

// MARK: - Devnet Integration Tests

/// Integration tests against local starknet-devnet (started with `starknet-devnet --seed 0`).
/// These tests are skipped on CI or if devnet is not running.
@Suite(
  "StarknetProvider Devnet Integration",
  .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
struct StarknetProviderDevnetTests {

  let provider: StarknetProvider = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 3
    return StarknetProvider(chain: .devnet, session: URLSession(configuration: config))
  }()

  // Predeployed account #0 from `starknet-devnet --seed 0`
  let account0Address = StarknetAddress(
    "0x064b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691")!
  let account0PrivateKey = Felt("0x71d7bb07b9a64f6f78ac4c816aff4da9")!

  /// Check if devnet is reachable; skip test if not.
  func requireDevnet() async throws {
    let reachable: Bool
    do {
      let _: String = try await provider.send(request: provider.chainIdRequest())
      reachable = true
    } catch {
      reachable = false
    }
    try #require(reachable, "starknet-devnet not running at \(provider.chain.rpcURL)")
  }

  @Test("starknet_chainId returns SN_SEPOLIA")
  func chainId() async throws {
    try await requireDevnet()
    let result: String = try await provider.send(request: provider.chainIdRequest())
    // "SN_SEPOLIA" encoded as hex
    #expect(result == "0x534e5f5345504f4c4941")
  }

  @Test("starknet_blockNumber returns a number")
  func blockNumber() async throws {
    try await requireDevnet()
    let result: Int = try await provider.send(request: provider.blockNumberRequest())
    #expect(result >= 0)
  }

  @Test("starknet_getNonce for predeployed account")
  func getNonce() async throws {
    try await requireDevnet()
    let result: String = try await provider.send(
      request: provider.getNonceRequest(address: account0Address))
    // Nonce should be a hex string like "0x0"
    #expect(result.hasPrefix("0x"))
  }

  @Test("starknet_call: read ETH balance of predeployed account")
  func callBalanceOf() async throws {
    try await requireDevnet()
    // ETH token on devnet (same as Sepolia)
    let ethToken = Felt("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    let balanceOfSelector = StarknetKeccak.functionSelector("balanceOf")
    let call = StarknetCall(
      contractAddress: ethToken,
      entryPointSelector: balanceOfSelector,
      calldata: [Felt(account0Address.data)]  // account address as felt
    )
    let result: [String] = try await provider.send(
      request: provider.callRequest(call: call))
    // Should return [low, high] for u256 balance
    #expect(result.count >= 1)
    // Predeployed account has 1000000000000000000000 WEI initial balance
    let low = Felt(result[0])!
    #expect(low != .zero)
  }

  @Test("starknet_getClassHashAt for predeployed account")
  func getClassHashAt() async throws {
    try await requireDevnet()
    let result: String = try await provider.send(
      request: provider.getClassHashAtRequest(address: account0Address))
    #expect(result.hasPrefix("0x"))
    // Should be the custom class hash from devnet
    #expect(result == "0x5b4b537eaa2399e3aa99c4e2e0208ebd6c71bc1467938cd52c798c601e43564")
  }
}

// MARK: - StarknetInvokeTransactionResponse

@Suite("StarknetInvokeTransactionResponse")
struct StarknetInvokeTransactionResponseTests {

  @Test("decode from JSON")
  func decodeFromJson() throws {
    let json = """
      {"transaction_hash":"0xabc123"}
      """
    let response = try JSONDecoder().decode(
      StarknetInvokeTransactionResponse.self, from: json.data(using: .utf8)!)
    #expect(response.transactionHash == "0xabc123")
    #expect(response.transactionHashFelt == Felt("0xabc123")!)
  }

  @Test("equatable")
  func equatable() throws {
    let json = """
      {"transaction_hash":"0x1"}
      """
    let a = try JSONDecoder().decode(
      StarknetInvokeTransactionResponse.self, from: json.data(using: .utf8)!)
    let b = try JSONDecoder().decode(
      StarknetInvokeTransactionResponse.self, from: json.data(using: .utf8)!)
    #expect(a == b)
  }
}
