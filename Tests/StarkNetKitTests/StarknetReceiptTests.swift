//
//  StarknetReceiptTests.swift
//  StarknetKitTests
//

import Foundation
import Testing

@testable import StarknetKit

// MARK: - StarknetReceipt Decoding

@Suite("StarknetReceipt")
struct StarknetReceiptTests {

  // MARK: - Successful Invoke Receipt

  static let invokeSuccessJSON = """
    {
      "type": "INVOKE",
      "transaction_hash": "0x06a09ffbf590de3e2b30fca4f4f2b0e48f0e0d183e6e22f9cbaa0164f7e8c30a",
      "actual_fee": {
        "amount": "0x2386f26fc10000",
        "unit": "FRI"
      },
      "execution_status": "SUCCEEDED",
      "finality_status": "ACCEPTED_ON_L2",
      "block_hash": "0x03b2711fe29eba45f2a0250c34901d15e37b495599fac498a3d2eaa4c2225c81",
      "block_number": 123456,
      "messages_sent": [],
      "events": [
        {
          "from_address": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
          "keys": ["0x0134692b230b9e1ffa39098904722134159652b09c5bc41d88d6698779d228ff"],
          "data": ["0xabc", "0xdef", "0x100"]
        }
      ],
      "execution_resources": {
        "steps": 1234,
        "memory_holes": 56,
        "range_check_builtin_applications": 78,
        "pedersen_builtin_applications": 12,
        "data_availability": {
          "l1_gas": 0,
          "l1_data_gas": 128
        }
      }
    }
    """

  @Test("Decode successful invoke receipt")
  func decodeInvokeSuccess() throws {
    let data = StarknetReceiptTests.invokeSuccessJSON.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.type == "INVOKE")
    #expect(receipt.transactionHashHex == "0x06a09ffbf590de3e2b30fca4f4f2b0e48f0e0d183e6e22f9cbaa0164f7e8c30a")
    #expect(receipt.isSuccess)
    #expect(!receipt.isReverted)
    #expect(receipt.blockNumber == 123456)
    #expect(!receipt.isPending)
    #expect(!receipt.isAcceptedOnL1)
    #expect(receipt.revertReason == nil)
    #expect(receipt.contractAddress == nil)
    #expect(receipt.messageHash == nil)
  }

  @Test("ChainReceipt protocol fields")
  func chainReceiptProtocol() throws {
    let data = StarknetReceiptTests.invokeSuccessJSON.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.transactionHash.count == 32)
    #expect(receipt.isSuccess == true)
    #expect(receipt.blockNumber == 123456)
  }

  @Test("Actual fee parsing")
  func actualFee() throws {
    let data = StarknetReceiptTests.invokeSuccessJSON.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.actualFee.unit == "FRI")
    #expect(receipt.actualFee.amountFelt != .zero)
    #expect(receipt.actualFee.amount == "0x2386f26fc10000")
  }

  @Test("Events decoding")
  func events() throws {
    let data = StarknetReceiptTests.invokeSuccessJSON.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.events.count == 1)
    let event = receipt.events[0]
    #expect(event.feltKeys.count == 1)
    #expect(event.feltData.count == 3)
    #expect(event.fromAddress == "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")
  }

  @Test("Execution resources decoding")
  func executionResources() throws {
    let data = StarknetReceiptTests.invokeSuccessJSON.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    let res = receipt.executionResources
    #expect(res.steps == 1234)
    #expect(res.memoryHoles == 56)
    #expect(res.rangeCheckBuiltinApplications == 78)
    #expect(res.pedersenBuiltinApplications == 12)
    #expect(res.poseidonBuiltinApplications == nil)
    #expect(res.ecOpBuiltinApplications == nil)
    #expect(res.dataAvailability.l1Gas == 0)
    #expect(res.dataAvailability.l1DataGas == 128)
  }

  // MARK: - Reverted Receipt

  @Test("Decode reverted receipt with revert reason")
  func decodeReverted() throws {
    let json = """
      {
        "type": "INVOKE",
        "transaction_hash": "0x0123",
        "actual_fee": { "amount": "0x0", "unit": "FRI" },
        "execution_status": "REVERTED",
        "finality_status": "ACCEPTED_ON_L2",
        "revert_reason": "Error in the called contract (0x1): Entry point not found",
        "block_hash": "0xaaa",
        "block_number": 100,
        "messages_sent": [],
        "events": [],
        "execution_resources": {
          "steps": 0,
          "data_availability": { "l1_gas": 0, "l1_data_gas": 0 }
        }
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(!receipt.isSuccess)
    #expect(receipt.isReverted)
    #expect(receipt.revertReason == "Error in the called contract (0x1): Entry point not found")
  }

  // MARK: - Pending Receipt

  @Test("Decode pending receipt (no block info)")
  func decodePending() throws {
    let json = """
      {
        "type": "INVOKE",
        "transaction_hash": "0x0456",
        "actual_fee": { "amount": "0x100", "unit": "WEI" },
        "execution_status": "SUCCEEDED",
        "finality_status": "ACCEPTED_ON_L2",
        "messages_sent": [],
        "events": [],
        "execution_resources": {
          "steps": 500,
          "data_availability": { "l1_gas": 10, "l1_data_gas": 0 }
        }
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.isPending)
    #expect(receipt.blockNumber == nil)
    #expect(receipt.blockHash == nil)
    #expect(receipt.isSuccess)
    #expect(receipt.actualFee.unit == "WEI")
  }

  // MARK: - Deploy Account Receipt

  @Test("Decode deploy account receipt with contract_address")
  func decodeDeployAccount() throws {
    let json = """
      {
        "type": "DEPLOY_ACCOUNT",
        "transaction_hash": "0x0789",
        "actual_fee": { "amount": "0x500", "unit": "FRI" },
        "execution_status": "SUCCEEDED",
        "finality_status": "ACCEPTED_ON_L1",
        "block_hash": "0xbbb",
        "block_number": 200,
        "messages_sent": [],
        "events": [],
        "execution_resources": {
          "steps": 800,
          "data_availability": { "l1_gas": 0, "l1_data_gas": 64 }
        },
        "contract_address": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.type == "DEPLOY_ACCOUNT")
    #expect(receipt.contractAddress == "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d")
    #expect(receipt.isAcceptedOnL1)
  }

  // MARK: - L1 Handler Receipt

  @Test("Decode L1 handler receipt with message_hash")
  func decodeL1Handler() throws {
    let json = """
      {
        "type": "L1_HANDLER",
        "transaction_hash": "0x0abc",
        "actual_fee": { "amount": "0x0", "unit": "WEI" },
        "execution_status": "SUCCEEDED",
        "finality_status": "ACCEPTED_ON_L2",
        "block_hash": "0xccc",
        "block_number": 300,
        "messages_sent": [],
        "events": [],
        "execution_resources": {
          "steps": 100,
          "data_availability": { "l1_gas": 0, "l1_data_gas": 0 }
        },
        "message_hash": "0xdeadbeefdeadbeefdeadbeefdeadbeef"
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.type == "L1_HANDLER")
    #expect(receipt.messageHash == "0xdeadbeefdeadbeefdeadbeefdeadbeef")
  }

  // MARK: - Messages Sent

  @Test("Decode receipt with L2-to-L1 messages")
  func decodeMessagesSent() throws {
    let json = """
      {
        "type": "INVOKE",
        "transaction_hash": "0x0def",
        "actual_fee": { "amount": "0x200", "unit": "FRI" },
        "execution_status": "SUCCEEDED",
        "finality_status": "ACCEPTED_ON_L2",
        "block_hash": "0xddd",
        "block_number": 400,
        "messages_sent": [
          {
            "from_address": "0x01",
            "to_address": "0x02",
            "payload": ["0x100", "0x200"]
          }
        ],
        "events": [],
        "execution_resources": {
          "steps": 300,
          "data_availability": { "l1_gas": 5, "l1_data_gas": 10 }
        }
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.messagesSent.count == 1)
    let msg = receipt.messagesSent[0]
    #expect(msg.fromAddress == "0x01")
    #expect(msg.toAddress == "0x02")
    #expect(msg.payloadFelts.count == 2)
  }

  // MARK: - transactionHashFelt convenience

  @Test("transactionHashFelt returns correct Felt")
  func transactionHashFelt() throws {
    let json = """
      {
        "type": "INVOKE",
        "transaction_hash": "0x0abc",
        "actual_fee": { "amount": "0x0", "unit": "FRI" },
        "execution_status": "SUCCEEDED",
        "finality_status": "ACCEPTED_ON_L2",
        "block_hash": "0xeee",
        "block_number": 1,
        "messages_sent": [],
        "events": [],
        "execution_resources": {
          "steps": 1,
          "data_availability": { "l1_gas": 0, "l1_data_gas": 0 }
        }
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: data)

    #expect(receipt.transactionHashFelt == Felt(0x0abc))
  }
}
