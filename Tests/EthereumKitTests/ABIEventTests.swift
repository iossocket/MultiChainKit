//
//  ABIEventTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class ABIEventTests: XCTestCase {

  // MARK: - Event Topic Calculation

  func testTransferEventTopic() throws {
    let event = ABIEvent(
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    // keccak256("Transfer(address,address,uint256)")
    let expectedTopic = Data(hex: "ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
    XCTAssertEqual(event.topic, expectedTopic)
  }

  func testApprovalEventTopic() throws {
    let event = ABIEvent(
      name: "Approval",
      inputs: [
        ABIParameter(name: "owner", type: "address", indexed: true),
        ABIParameter(name: "spender", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    // keccak256("Approval(address,address,uint256)")
    let expectedTopic = Data(hex: "8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925")
    XCTAssertEqual(event.topic, expectedTopic)
  }

  func testEventSignature() {
    let event = ABIEvent(
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    XCTAssertEqual(event.signature, "Transfer(address,address,uint256)")
  }

  // MARK: - Event from ABIItem

  func testEventFromABIItem() throws {
    let json = """
      {
        "type": "event",
        "name": "Transfer",
        "inputs": [
          {"name": "from", "type": "address", "indexed": true},
          {"name": "to", "type": "address", "indexed": true},
          {"name": "value", "type": "uint256", "indexed": false}
        ],
        "anonymous": false
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    let event = item.asEvent()
    XCTAssertNotNil(event)
    XCTAssertEqual(event?.name, "Transfer")
    XCTAssertEqual(event?.inputs.count, 3)
    XCTAssertEqual(event?.anonymous, false)
  }

  // MARK: - Encode Topics

  func testEncodeTopicsForTransfer() throws {
    let event = ABIEvent(
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    let from = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let to = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

    let topics = event.encodeTopics(values: [.address(from), .address(to)])

    XCTAssertEqual(topics.count, 3)  // topic0 + 2 indexed params

    // topic0 = event signature hash
    XCTAssertEqual(topics[0], event.topic)

    // topic1 = from address (left-padded to 32 bytes)
    XCTAssertEqual(topics[1]?.count, 32)
    XCTAssertEqual(topics[1]?.suffix(20), from.data)

    // topic2 = to address (left-padded to 32 bytes)
    XCTAssertEqual(topics[2]?.count, 32)
    XCTAssertEqual(topics[2]?.suffix(20), to.data)
  }

  func testEncodeTopicsWithWildcard() throws {
    let event = ABIEvent(
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    let to = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

    // nil = wildcard (match any)
    let topics = event.encodeTopics(values: [nil, .address(to)])

    XCTAssertEqual(topics.count, 3)
    XCTAssertEqual(topics[0], event.topic)
    XCTAssertNil(topics[1])  // wildcard
    XCTAssertNotNil(topics[2])
  }

  // MARK: - Decode Event Log

  func testDecodeTransferLog() throws {
    let event = ABIEvent(
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    // Simulated log data
    let topic0 = event.topic
    let topic1 = Data(hex: "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    let topic2 = Data(hex: "00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8")
    let logData = Data(hex: "0000000000000000000000000000000000000000000000000de0b6b3a7640000")  // 1 ETH

    let decoded = try event.decodeLog(topics: [topic0, topic1, topic2], data: logData)

    XCTAssertEqual(decoded.count, 3)

    // Check from address
    if case .address(let from) = decoded["from"] {
      XCTAssertEqual(from.checksummed.lowercased(), "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    } else {
      XCTFail("Expected address for 'from'")
    }

    // Check to address
    if case .address(let to) = decoded["to"] {
      XCTAssertEqual(to.checksummed.lowercased(), "0x70997970c51812dc3a010c7d01b50e0d17dc79c8")
    } else {
      XCTFail("Expected address for 'to'")
    }

    // Check value
    if case .uint(bits: 256, value: let value) = decoded["value"] {
      XCTAssertEqual(value, Wei.fromEther(1))
    } else {
      XCTFail("Expected uint256 for 'value'")
    }
  }

  func testDecodeApprovalLog() throws {
    let event = ABIEvent(
      name: "Approval",
      inputs: [
        ABIParameter(name: "owner", type: "address", indexed: true),
        ABIParameter(name: "spender", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    let topic0 = event.topic
    let topic1 = Data(hex: "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    let topic2 = Data(hex: "00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8")
    // Max uint256
    let logData = Data(hex: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

    let decoded = try event.decodeLog(topics: [topic0, topic1, topic2], data: logData)

    XCTAssertEqual(decoded.count, 3)

    if case .address(let owner) = decoded["owner"] {
      XCTAssertEqual(owner.checksummed.lowercased(), "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    } else {
      XCTFail("Expected address for 'owner'")
    }
  }

  // MARK: - Complex Event with Non-Indexed Dynamic Type

  func testDecodeEventWithStringData() throws {
    // event Message(address indexed sender, string message)
    let event = ABIEvent(
      name: "Message",
      inputs: [
        ABIParameter(name: "sender", type: "address", indexed: true),
        ABIParameter(name: "message", type: "string", indexed: false)
      ],
      anonymous: false
    )

    let topic0 = event.topic
    let topic1 = Data(hex: "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266")

    // ABI encoded string "Hello"
    let logData = Data(hex:
      "0000000000000000000000000000000000000000000000000000000000000020" +  // offset
      "0000000000000000000000000000000000000000000000000000000000000005" +  // length
      "48656c6c6f000000000000000000000000000000000000000000000000000000"    // "Hello"
    )

    let decoded = try event.decodeLog(topics: [topic0, topic1], data: logData)

    XCTAssertEqual(decoded.count, 2)

    if case .string(let message) = decoded["message"] {
      XCTAssertEqual(message, "Hello")
    } else {
      XCTFail("Expected string for 'message'")
    }
  }

  // MARK: - EthereumLog Extension

  func testEthereumLogDecode() throws {
    let event = ABIEvent(
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: false
    )

    let log = EthereumLog(
      address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      topics: [
        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
        "0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8"
      ],
      data: "0x0000000000000000000000000000000000000000000000000000000005f5e100",  // 100000000 (100 USDC)
      blockNumber: "0x100",
      transactionHash: "0xabc",
      transactionIndex: "0x0",
      blockHash: "0xdef",
      logIndex: "0x0",
      removed: false
    )

    let decoded = try log.decode(event: event)

    XCTAssertEqual(decoded.count, 3)

    if case .uint(bits: 256, value: let value) = decoded["value"] {
      XCTAssertEqual(value, Wei(100_000_000))
    } else {
      XCTFail("Expected uint256 for 'value'")
    }
  }

  // MARK: - Anonymous Event

  func testAnonymousEvent() {
    let event = ABIEvent(
      name: "AnonymousTransfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false)
      ],
      anonymous: true
    )

    // Anonymous events don't include topic0
    let from = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let to = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

    let topics = event.encodeTopics(values: [.address(from), .address(to)])

    // Only 2 topics (no topic0 for anonymous)
    XCTAssertEqual(topics.count, 2)
  }

  // MARK: - Indexed Bytes32

  func testIndexedBytes32() throws {
    // event HashStored(bytes32 indexed hash, address indexed sender)
    let event = ABIEvent(
      name: "HashStored",
      inputs: [
        ABIParameter(name: "hash", type: "bytes32", indexed: true),
        ABIParameter(name: "sender", type: "address", indexed: true)
      ],
      anonymous: false
    )

    let hashValue = Data(repeating: 0xab, count: 32)
    let sender = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!

    let topics = event.encodeTopics(values: [.fixedBytes(hashValue), .address(sender)])

    XCTAssertEqual(topics.count, 3)
    XCTAssertEqual(topics[1], hashValue)
  }
}
