//
//  ABITypeTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class ABITypeTests: XCTestCase {

  // MARK: - Basic Type Parsing

  func testParseUint256() throws {
    let type = try ABIType.parse("uint256")

    if case .uint(let bits) = type {
      XCTAssertEqual(bits, 256)
    } else {
      XCTFail("Expected uint256")
    }
  }

  func testParseUint8() throws {
    let type = try ABIType.parse("uint8")

    if case .uint(let bits) = type {
      XCTAssertEqual(bits, 8)
    } else {
      XCTFail("Expected uint8")
    }
  }

  func testParseInt256() throws {
    let type = try ABIType.parse("int256")

    if case .int(let bits) = type {
      XCTAssertEqual(bits, 256)
    } else {
      XCTFail("Expected int256")
    }
  }

  func testParseAddress() throws {
    let type = try ABIType.parse("address")

    if case .address = type {
      // OK
    } else {
      XCTFail("Expected address")
    }
  }

  func testParseBool() throws {
    let type = try ABIType.parse("bool")

    if case .bool = type {
      // OK
    } else {
      XCTFail("Expected bool")
    }
  }

  func testParseBytes32() throws {
    let type = try ABIType.parse("bytes32")

    if case .fixedBytes(let size) = type {
      XCTAssertEqual(size, 32)
    } else {
      XCTFail("Expected bytes32")
    }
  }

  func testParseBytes() throws {
    let type = try ABIType.parse("bytes")

    if case .bytes = type {
      // OK
    } else {
      XCTFail("Expected bytes")
    }
  }

  func testParseString() throws {
    let type = try ABIType.parse("string")

    if case .string = type {
      // OK
    } else {
      XCTFail("Expected string")
    }
  }

  // MARK: - Array Types

  func testParseFixedArray() throws {
    let type = try ABIType.parse("uint256[3]")

    if case .fixedArray(let elementType, let size) = type {
      XCTAssertEqual(size, 3)
      if case .uint(let bits) = elementType {
        XCTAssertEqual(bits, 256)
      } else {
        XCTFail("Expected uint256 element type")
      }
    } else {
      XCTFail("Expected fixed array")
    }
  }

  func testParseDynamicArray() throws {
    let type = try ABIType.parse("address[]")

    if case .array(let elementType) = type {
      if case .address = elementType {
        // OK
      } else {
        XCTFail("Expected address element type")
      }
    } else {
      XCTFail("Expected dynamic array")
    }
  }

  func testParseNestedArray() throws {
    let type = try ABIType.parse("uint256[][]")

    if case .array(let inner) = type {
      if case .array(let elementType) = inner {
        if case .uint(let bits) = elementType {
          XCTAssertEqual(bits, 256)
        } else {
          XCTFail("Expected uint256")
        }
      } else {
        XCTFail("Expected inner array")
      }
    } else {
      XCTFail("Expected outer array")
    }
  }

  // MARK: - Tuple Types

  func testParseTuple() throws {
    let type = try ABIType.parse("(address,uint256)")

    if case .tuple(let components) = type {
      XCTAssertEqual(components.count, 2)
      if case .address = components[0] {
        // OK
      } else {
        XCTFail("Expected address")
      }
      if case .uint(256) = components[1] {
        // OK
      } else {
        XCTFail("Expected uint256")
      }
    } else {
      XCTFail("Expected tuple")
    }
  }

  func testParseNestedTuple() throws {
    let type = try ABIType.parse("(address,(uint256,bool))")

    if case .tuple(let components) = type {
      XCTAssertEqual(components.count, 2)
      if case .tuple(let inner) = components[1] {
        XCTAssertEqual(inner.count, 2)
      } else {
        XCTFail("Expected nested tuple")
      }
    } else {
      XCTFail("Expected tuple")
    }
  }

  // MARK: - Canonical Signature

  func testCanonicalSignature() throws {
    let type = try ABIType.parse("(address,uint256)")
    XCTAssertEqual(type.canonicalName, "(address,uint256)")
  }

  func testCanonicalSignatureArray() throws {
    let type = try ABIType.parse("uint256[]")
    XCTAssertEqual(type.canonicalName, "uint256[]")
  }

  // MARK: - JSON ABI Parsing

  func testParseABIFunction() throws {
    let json = """
      {
        "type": "function",
        "name": "transfer",
        "inputs": [
          {"name": "to", "type": "address"},
          {"name": "amount", "type": "uint256"}
        ],
        "outputs": [
          {"name": "", "type": "bool"}
        ],
        "stateMutability": "nonpayable"
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    XCTAssertEqual(item.type, .function)
    XCTAssertEqual(item.name, "transfer")
    XCTAssertEqual(item.inputs?.count, 2)
    XCTAssertEqual(item.outputs?.count, 1)
    XCTAssertEqual(item.stateMutability, .nonpayable)
  }

  func testParseABIConstructor() throws {
    let json = """
      {
        "type": "constructor",
        "inputs": [
          {"name": "initialOwner", "type": "address"}
        ],
        "stateMutability": "nonpayable"
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    XCTAssertEqual(item.type, .constructor)
    XCTAssertNil(item.name)
    XCTAssertEqual(item.inputs?.count, 1)
  }

  func testParseABIEvent() throws {
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

    XCTAssertEqual(item.type, .event)
    XCTAssertEqual(item.name, "Transfer")
    XCTAssertEqual(item.inputs?.count, 3)
    XCTAssertEqual(item.inputs?[0].indexed, true)
    XCTAssertEqual(item.inputs?[2].indexed, false)
  }

  func testParseABIError() throws {
    let json = """
      {
        "type": "error",
        "name": "InsufficientBalance",
        "inputs": [
          {"name": "available", "type": "uint256"},
          {"name": "required", "type": "uint256"}
        ]
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    XCTAssertEqual(item.type, .error)
    XCTAssertEqual(item.name, "InsufficientBalance")
    XCTAssertEqual(item.inputs?.count, 2)
  }

  func testParseABIWithTupleComponent() throws {
    let json = """
      {
        "type": "function",
        "name": "getPosition",
        "inputs": [
          {
            "name": "key",
            "type": "tuple",
            "components": [
              {"name": "token0", "type": "address"},
              {"name": "token1", "type": "address"},
              {"name": "fee", "type": "uint24"}
            ]
          }
        ],
        "outputs": [
          {"name": "liquidity", "type": "uint128"}
        ],
        "stateMutability": "view"
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    XCTAssertEqual(item.inputs?.count, 1)
    XCTAssertEqual(item.inputs?[0].components?.count, 3)
    XCTAssertEqual(item.inputs?[0].components?[2].type, "uint24")
  }

  // MARK: - Function Signature

  func testFunctionSignature() throws {
    let json = """
      {
        "type": "function",
        "name": "transfer",
        "inputs": [
          {"name": "to", "type": "address"},
          {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"name": "", "type": "bool"}],
        "stateMutability": "nonpayable"
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    XCTAssertEqual(item.signature, "transfer(address,uint256)")
  }

  func testFunctionSelector() throws {
    let json = """
      {
        "type": "function",
        "name": "transfer",
        "inputs": [
          {"name": "to", "type": "address"},
          {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"name": "", "type": "bool"}],
        "stateMutability": "nonpayable"
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    let selector = item.selector
    XCTAssertEqual(selector?.count, 4)
    // transfer(address,uint256) = 0xa9059cbb
    XCTAssertEqual(selector?[0], 0xa9)
    XCTAssertEqual(selector?[1], 0x05)
    XCTAssertEqual(selector?[2], 0x9c)
    XCTAssertEqual(selector?[3], 0xbb)
  }

  func testTupleFunctionSignature() throws {
    let json = """
      {
        "type": "function",
        "name": "getPosition",
        "inputs": [
          {
            "name": "key",
            "type": "tuple",
            "components": [
              {"name": "token0", "type": "address"},
              {"name": "token1", "type": "address"},
              {"name": "fee", "type": "uint24"}
            ]
          }
        ],
        "outputs": [],
        "stateMutability": "view"
      }
      """
    let data = json.data(using: .utf8)!
    let item = try JSONDecoder().decode(ABIItem.self, from: data)

    XCTAssertEqual(item.signature, "getPosition((address,address,uint24))")
  }

  // MARK: - Full Contract ABI

  func testParseFullContractABI() throws {
    let json = """
      [
        {
          "type": "constructor",
          "inputs": [{"name": "name", "type": "string"}],
          "stateMutability": "nonpayable"
        },
        {
          "type": "function",
          "name": "balanceOf",
          "inputs": [{"name": "account", "type": "address"}],
          "outputs": [{"name": "", "type": "uint256"}],
          "stateMutability": "view"
        },
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
      ]
      """
    let data = json.data(using: .utf8)!
    let abi = try JSONDecoder().decode([ABIItem].self, from: data)

    XCTAssertEqual(abi.count, 3)
    XCTAssertEqual(abi[0].type, .constructor)
    XCTAssertEqual(abi[1].type, .function)
    XCTAssertEqual(abi[2].type, .event)
  }
}
