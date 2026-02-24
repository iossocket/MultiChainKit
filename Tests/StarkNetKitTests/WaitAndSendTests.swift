//
//  WaitAndSendTests.swift
//  StarknetKitTests
//
//  Tests for StarknetTransactionStatus, waitForTransaction, executeV3, and Contract.invoke.
//

import BigInt
import Foundation
import MultiChainCore
import Testing

@testable import StarknetKit

// MARK: - StarknetTransactionStatus Decode

@Suite("StarknetTransactionStatus")
struct StarknetTransactionStatusTests {

  @Test("decode accepted on L2")
  func decodeAcceptedL2() throws {
    let json = """
      {"finality_status":"ACCEPTED_ON_L2","execution_status":"SUCCEEDED"}
      """
    let status = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    #expect(status.finalityStatus == "ACCEPTED_ON_L2")
    #expect(status.executionStatus == "SUCCEEDED")
    #expect(status.failureReason == nil)
    #expect(status.isAccepted)
    #expect(!status.isRejected)
    #expect(!status.isReverted)
  }

  @Test("decode accepted on L1")
  func decodeAcceptedL1() throws {
    let json = """
      {"finality_status":"ACCEPTED_ON_L1","execution_status":"SUCCEEDED"}
      """
    let status = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    #expect(status.isAccepted)
  }

  @Test("decode rejected")
  func decodeRejected() throws {
    let json = """
      {"finality_status":"REJECTED"}
      """
    let status = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    #expect(status.isRejected)
    #expect(!status.isAccepted)
    #expect(status.executionStatus == nil)
  }

  @Test("decode reverted with failure reason")
  func decodeReverted() throws {
    let json = """
      {"finality_status":"ACCEPTED_ON_L2","execution_status":"REVERTED","failure_reason":"out of gas"}
      """
    let status = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    #expect(status.isReverted)
    #expect(status.failureReason == "out of gas")
    #expect(status.isAccepted)
  }

  @Test("decode received (not yet accepted)")
  func decodeReceived() throws {
    let json = """
      {"finality_status":"RECEIVED"}
      """
    let status = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    #expect(!status.isAccepted)
    #expect(!status.isRejected)
    #expect(!status.isReverted)
  }

  @Test("equatable")
  func equatable() throws {
    let json = """
      {"finality_status":"ACCEPTED_ON_L2","execution_status":"SUCCEEDED"}
      """
    let a = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    let b = try JSONDecoder().decode(
      StarknetTransactionStatus.self, from: json.data(using: .utf8)!)
    #expect(a == b)
  }
}

// MARK: - waitForTransaction Signature

@Suite("StarknetProvider.waitForTransaction")
struct StarknetWaitForTransactionTests {

  @Test("method signature compiles")
  func methodExists() {
    let provider = StarknetProvider(chain: .sepolia)
    _ = type(of: provider).waitForTransaction
  }

  @Test("getTransactionStatus request exists")
  func statusRequest() {
    let provider = StarknetProvider(chain: .sepolia)
    let req = provider.getTransactionStatusRequest(hash: Felt(0xabc))
    #expect(req.method == "starknet_getTransactionStatus")
  }
}

// MARK: - executeV3 Signature

@Suite("StarknetAccount.executeV3")
struct StarknetExecuteV3Tests {

  @Test("method signature compiles")
  func methodExists() throws {
    let signer = try StarknetSigner(
      privateKey: Felt(0x1234).bigEndianData)
    let account = StarknetAccount(
      signer: signer,
      address: StarknetAddress("0x1")!,
      chain: .sepolia
    )
    _ = type(of: account).executeV3
  }
}

// MARK: - Contract.invoke Signature

@Suite("StarknetContract.invoke")
struct StarknetContractInvokeTests {

  @Test("method signature compiles")
  func methodExists() {
    let provider = StarknetProvider(chain: .sepolia)
    let abi: [StarknetABIItem] = [
      .function(
        StarknetABIFunction(
          name: "transfer",
          inputs: [
            StarknetABIParam(name: "recipient", type: "core::felt252"),
            StarknetABIParam(name: "amount", type: "core::integer::u256"),
          ],
          outputs: [],
          stateMutability: "external"
        ))
    ]
    let contract = StarknetContract(
      address: Felt(0x1),
      abi: abi,
      provider: provider
    )
    _ = type(of: contract).invoke
  }
}
