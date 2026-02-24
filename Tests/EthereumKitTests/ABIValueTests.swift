//
//  ABIValueTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class ABIValueTests: XCTestCase {

  // MARK: - Basic Types

  func testUint256FromWei() {
    let value = ABIValue.uint256(Wei(1000))

    if case .uint(bits: 256, value: let wei) = value {
      XCTAssertEqual(wei, Wei(1000))
    } else {
      XCTFail("Expected uint256")
    }
  }

  func testAddress() {
    let addr = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let value = ABIValue.address(addr)

    if case .address(let a) = value {
      XCTAssertEqual(a, addr)
    } else {
      XCTFail("Expected address")
    }
  }

  func testBool() {
    let trueValue = ABIValue.bool(true)
    let falseValue = ABIValue.bool(false)

    if case .bool(let b) = trueValue {
      XCTAssertTrue(b)
    } else {
      XCTFail("Expected bool")
    }

    if case .bool(let b) = falseValue {
      XCTAssertFalse(b)
    } else {
      XCTFail("Expected bool")
    }
  }

  func testBytes32() {
    let data = Data(repeating: 0xab, count: 32)
    let value = ABIValue.bytes32(data)

    if case .fixedBytes(let d) = value {
      XCTAssertEqual(d, data)
      XCTAssertEqual(d.count, 32)
    } else {
      XCTFail("Expected fixedBytes")
    }
  }

  func testString() {
    let value = ABIValue.string("Hello, Ethereum!")

    if case .string(let s) = value {
      XCTAssertEqual(s, "Hello, Ethereum!")
    } else {
      XCTFail("Expected string")
    }
  }

  func testBytes() {
    let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
    let value = ABIValue.bytes(data)

    if case .bytes(let d) = value {
      XCTAssertEqual(d, data)
    } else {
      XCTFail("Expected bytes")
    }
  }

  // MARK: - Array Types

  func testArray() {
    let values: [ABIValue] = [.uint256(Wei(1)), .uint256(Wei(2)), .uint256(Wei(3))]
    let value = ABIValue.array(values)

    if case .array(let arr) = value {
      XCTAssertEqual(arr.count, 3)
    } else {
      XCTFail("Expected array")
    }
  }

  func testTuple() {
    let addr = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let tuple = ABIValue.tuple([
      .address(addr),
      .uint256(Wei.fromEther(1)),
      .bool(true),
    ])

    if case .tuple(let elements) = tuple {
      XCTAssertEqual(elements.count, 3)
    } else {
      XCTFail("Expected tuple")
    }
  }

  // MARK: - ExpressibleByIntegerLiteral

  func testIntegerLiteral() {
    let value: ABIValue = 42

    if case .uint(bits: 256, value: let wei) = value {
      XCTAssertEqual(wei, Wei(42))
    } else {
      XCTFail("Expected uint256")
    }
  }

  func testLargeIntegerLiteral() {
    let value: ABIValue = 1_000_000_000_000_000_000  // 1 ETH in wei

    if case .uint(bits: 256, value: let wei) = value {
      XCTAssertEqual(wei, Wei.fromEther(1))
    } else {
      XCTFail("Expected uint256")
    }
  }

  // MARK: - ExpressibleByBooleanLiteral

  func testBooleanLiteral() {
    let trueValue: ABIValue = true
    let falseValue: ABIValue = false

    if case .bool(let b) = trueValue {
      XCTAssertTrue(b)
    } else {
      XCTFail("Expected bool")
    }

    if case .bool(let b) = falseValue {
      XCTAssertFalse(b)
    } else {
      XCTFail("Expected bool")
    }
  }

  // MARK: - ExpressibleByStringLiteral

  func testStringLiteralAsAddress() {
    let value: ABIValue = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

    if case .address(let addr) = value {
      XCTAssertEqual(addr.checksummed, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
    } else {
      XCTFail("Expected address, got \(value)")
    }
  }

  func testStringLiteralAsString() {
    let value: ABIValue = "Hello, World!"

    if case .string(let s) = value {
      XCTAssertEqual(s, "Hello, World!")
    } else {
      XCTFail("Expected string")
    }
  }

  // MARK: - ExpressibleByArrayLiteral

  func testArrayLiteral() {
    let value: ABIValue = [1, 2, 3]

    if case .array(let arr) = value {
      XCTAssertEqual(arr.count, 3)
      if case .uint(bits: 256, value: let first) = arr[0] {
        XCTAssertEqual(first, Wei(1))
      }
    } else {
      XCTFail("Expected array")
    }
  }

  func testMixedArrayLiteral() {
    let addr = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let value: ABIValue = [.address(addr), true, 100]

    if case .array(let arr) = value {
      XCTAssertEqual(arr.count, 3)
    } else {
      XCTFail("Expected array")
    }
  }

  // MARK: - Equatable

  func testEquatable() {
    let a: ABIValue = 100
    let b: ABIValue = 100
    let c: ABIValue = 200

    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, c)
  }

  func testEquatableAddress() {
    let addr1 = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let addr2 = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!

    XCTAssertEqual(ABIValue.address(addr1), ABIValue.address(addr2))
  }

  // MARK: - ABI Encoding

  func testEncodeUint256() {
    let value: ABIValue = .uint256(Wei(256))
    let encoded = value.encode()

    XCTAssertEqual(encoded.count, 32)
    // 256 = 0x100
    XCTAssertEqual(encoded[31], 0x00)
    XCTAssertEqual(encoded[30], 0x01)
  }

  func testEncodeAddress() {
    let addr = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let value = ABIValue.address(addr)
    let encoded = value.encode()

    XCTAssertEqual(encoded.count, 32)
    // Address is right-padded to 32 bytes (12 zero bytes + 20 address bytes)
    XCTAssertEqual(encoded.prefix(12), Data(repeating: 0, count: 12))
  }

  func testEncodeBool() {
    let trueEncoded = ABIValue.bool(true).encode()
    let falseEncoded = ABIValue.bool(false).encode()

    XCTAssertEqual(trueEncoded.count, 32)
    XCTAssertEqual(falseEncoded.count, 32)
    XCTAssertEqual(trueEncoded[31], 1)
    XCTAssertEqual(falseEncoded[31], 0)
  }

  func testEncodeBytes32() {
    let data = Data(repeating: 0xab, count: 32)
    let encoded = ABIValue.bytes32(data).encode()

    XCTAssertEqual(encoded.count, 32)
    XCTAssertEqual(encoded, data)
  }

  // MARK: - Dynamic Type Encoding

  func testEncodeDynamicBytes() {
    // bytes with 5 bytes of data
    let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
    let encoded = ABIValue.bytes(data).encode()

    // Should be: 32 bytes length + 32 bytes padded data
    XCTAssertEqual(encoded.count, 64)

    // First 32 bytes = length (5)
    XCTAssertEqual(encoded[31], 5)

    // Next 32 bytes = data right-padded
    XCTAssertEqual(encoded[32], 0x01)
    XCTAssertEqual(encoded[33], 0x02)
    XCTAssertEqual(encoded[34], 0x03)
    XCTAssertEqual(encoded[35], 0x04)
    XCTAssertEqual(encoded[36], 0x05)
    // Rest should be zeros
    XCTAssertEqual(encoded[37], 0x00)
  }

  func testEncodeString() {
    let encoded = ABIValue.string("Hello").encode()

    // Should be: 32 bytes length + 32 bytes padded data
    XCTAssertEqual(encoded.count, 64)

    // First 32 bytes = length (5)
    XCTAssertEqual(encoded[31], 5)

    // "Hello" = 0x48656c6c6f
    XCTAssertEqual(encoded[32], 0x48)  // H
    XCTAssertEqual(encoded[33], 0x65)  // e
    XCTAssertEqual(encoded[34], 0x6c)  // l
    XCTAssertEqual(encoded[35], 0x6c)  // l
    XCTAssertEqual(encoded[36], 0x6f)  // o
  }

  // MARK: - Static/Dynamic Classification

  func testIsDynamic() {
    // Static types
    XCTAssertFalse(ABIValue.uint256(Wei(1)).isDynamic)
    XCTAssertFalse(ABIValue.bool(true).isDynamic)
    XCTAssertFalse(
      ABIValue.address(EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!).isDynamic)
    XCTAssertFalse(ABIValue.bytes32(Data(repeating: 0, count: 32)).isDynamic)

    // Dynamic types
    XCTAssertTrue(ABIValue.bytes(Data([1, 2, 3])).isDynamic)
    XCTAssertTrue(ABIValue.string("hello").isDynamic)
    XCTAssertTrue(ABIValue.array([.uint256(Wei(1))]).isDynamic)

    // Fixed array of static types is static
    XCTAssertFalse(ABIValue.fixedArray([.uint256(Wei(1)), .uint256(Wei(2))]).isDynamic)

    // Fixed array of dynamic types is dynamic
    XCTAssertTrue(ABIValue.fixedArray([.string("a"), .string("b")]).isDynamic)

    // Tuple with all static is static
    XCTAssertFalse(ABIValue.tuple([.uint256(Wei(1)), .bool(true)]).isDynamic)

    // Tuple with any dynamic is dynamic
    XCTAssertTrue(ABIValue.tuple([.uint256(Wei(1)), .string("hello")]).isDynamic)
  }

  // MARK: - Array Encoding

  func testEncodeStaticArray() {
    // uint256[3] with values [1, 2, 3]
    let arr = ABIValue.fixedArray([
      .uint256(Wei(1)),
      .uint256(Wei(2)),
      .uint256(Wei(3)),
    ])
    let encoded = arr.encode()

    // 3 * 32 bytes = 96 bytes
    XCTAssertEqual(encoded.count, 96)

    // Check values
    XCTAssertEqual(encoded[31], 1)
    XCTAssertEqual(encoded[63], 2)
    XCTAssertEqual(encoded[95], 3)
  }

  func testEncodeDynamicArray() {
    // uint256[] with values [1, 2]
    let arr = ABIValue.array([
      .uint256(Wei(1)),
      .uint256(Wei(2)),
    ])
    let encoded = arr.encode()

    // 32 bytes length + 2 * 32 bytes = 96 bytes
    XCTAssertEqual(encoded.count, 96)

    // First 32 bytes = length (2)
    XCTAssertEqual(encoded[31], 2)

    // Values
    XCTAssertEqual(encoded[63], 1)
    XCTAssertEqual(encoded[95], 2)
  }

  // MARK: - Tuple Encoding

  func testEncodeStaticTuple() {
    // (address, uint256, bool)
    let addr = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
    let tuple = ABIValue.tuple([
      .address(addr),
      .uint256(Wei(100)),
      .bool(true),
    ])
    let encoded = tuple.encode()

    // 3 * 32 bytes = 96 bytes
    XCTAssertEqual(encoded.count, 96)

    // Address (left-padded)
    XCTAssertEqual(encoded.prefix(12), Data(repeating: 0, count: 12))

    // uint256 = 100
    XCTAssertEqual(encoded[63], 100)

    // bool = true
    XCTAssertEqual(encoded[95], 1)
  }

  func testEncodeDynamicTuple() {
    // (uint256, string) - has dynamic element
    let tuple = ABIValue.tuple([
      .uint256(Wei(42)),
      .string("Hello"),
    ])
    let encoded = tuple.encode()

    // Head: 32 (uint256) + 32 (offset to string)
    // Tail: 32 (string length) + 32 (string data)
    // Total: 128 bytes
    XCTAssertEqual(encoded.count, 128)

    // First element: uint256 = 42
    XCTAssertEqual(encoded[31], 42)

    // Second element: offset to string data (64 = 0x40)
    XCTAssertEqual(encoded[63], 64)

    // String length at offset 64
    XCTAssertEqual(encoded[95], 5)

    // String data "Hello"
    XCTAssertEqual(encoded[96], 0x48)  // H
  }

  // MARK: - Function Selector

  func testFunctionSelector() {
    // transfer(address,uint256) selector
    let selector = ABIValue.functionSelector("transfer(address,uint256)")

    XCTAssertEqual(selector.count, 4)
    // keccak256("transfer(address,uint256)") = 0xa9059cbb...
    XCTAssertEqual(selector[0], 0xa9)
    XCTAssertEqual(selector[1], 0x05)
    XCTAssertEqual(selector[2], 0x9c)
    XCTAssertEqual(selector[3], 0xbb)
  }

  func testFunctionSelectorBalanceOf() {
    // balanceOf(address) selector
    let selector = ABIValue.functionSelector("balanceOf(address)")

    XCTAssertEqual(selector.count, 4)
    // keccak256("balanceOf(address)") = 0x70a08231...
    XCTAssertEqual(selector[0], 0x70)
    XCTAssertEqual(selector[1], 0xa0)
    XCTAssertEqual(selector[2], 0x82)
    XCTAssertEqual(selector[3], 0x31)
  }

  // MARK: - Encode Call

  func testEncodeTransferCall() {
    let to = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!
    let amount = Wei.fromEther(1)

    let calldata = ABIValue.encodeCall(
      signature: "transfer(address,uint256)",
      arguments: [.address(to), .uint256(amount)]
    )

    // 4 bytes selector + 32 bytes address + 32 bytes amount = 68 bytes
    XCTAssertEqual(calldata.count, 68)

    // Check selector
    XCTAssertEqual(calldata[0], 0xa9)
    XCTAssertEqual(calldata[1], 0x05)
    XCTAssertEqual(calldata[2], 0x9c)
    XCTAssertEqual(calldata[3], 0xbb)

    // Check address (left-padded)
    XCTAssertEqual(calldata[4..<16], Data(repeating: 0, count: 12))
  }

  func testEncodeApproveCall() {
    let spender = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!
    let amount = Wei("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!

    let calldata = ABIValue.encodeCall(
      signature: "approve(address,uint256)",
      arguments: [.address(spender), .uint256(amount)]
    )

    // 4 bytes selector + 64 bytes args = 68 bytes
    XCTAssertEqual(calldata.count, 68)

    // approve selector = 0x095ea7b3
    XCTAssertEqual(calldata[0], 0x09)
    XCTAssertEqual(calldata[1], 0x5e)
    XCTAssertEqual(calldata[2], 0xa7)
    XCTAssertEqual(calldata[3], 0xb3)
  }
}
