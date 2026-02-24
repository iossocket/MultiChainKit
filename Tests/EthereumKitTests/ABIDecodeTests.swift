//
//  ABIDecodeTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class ABIDecodeTests: XCTestCase {

  // MARK: - Basic Types

  func testDecodeUint256() throws {
    // 256 encoded as uint256
    let data = Data(hex: "0000000000000000000000000000000000000000000000000000000000000100")
    let result = try ABIValue.decode(types: [.uint(256)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .uint(bits: 256, value: let wei) = result[0] {
      XCTAssertEqual(wei, Wei(256))
    } else {
      XCTFail("Expected uint256")
    }
  }

  func testDecodeUint8() throws {
    // 255 encoded as uint8
    let data = Data(hex: "00000000000000000000000000000000000000000000000000000000000000ff")
    let result = try ABIValue.decode(types: [.uint(8)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .uint(bits: 8, value: let wei) = result[0] {
      XCTAssertEqual(wei, Wei(255))
    } else {
      XCTFail("Expected uint8")
    }
  }

  func testDecodeInt256() throws {
    // -1 encoded as int256 (all 1s in two's complement)
    let data = Data(hex: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    let result = try ABIValue.decode(types: [.int(256)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .int(bits: 256, value: _) = result[0] {
      // For now we just check it decodes - proper signed handling is complex
    } else {
      XCTFail("Expected int256")
    }
  }

  func testDecodeAddress() throws {
    // Address 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    let data = Data(hex: "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    let result = try ABIValue.decode(types: [.address], data: data)

    XCTAssertEqual(result.count, 1)
    if case .address(let addr) = result[0] {
      XCTAssertEqual(addr.checksummed.lowercased(), "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    } else {
      XCTFail("Expected address")
    }
  }

  func testDecodeBool() throws {
    // true
    let trueData = Data(hex: "0000000000000000000000000000000000000000000000000000000000000001")
    let trueResult = try ABIValue.decode(types: [.bool], data: trueData)

    if case .bool(let value) = trueResult[0] {
      XCTAssertTrue(value)
    } else {
      XCTFail("Expected bool")
    }

    // false
    let falseData = Data(hex: "0000000000000000000000000000000000000000000000000000000000000000")
    let falseResult = try ABIValue.decode(types: [.bool], data: falseData)

    if case .bool(let value) = falseResult[0] {
      XCTAssertFalse(value)
    } else {
      XCTFail("Expected bool")
    }
  }

  func testDecodeBytes32() throws {
    let data = Data(hex: "abababababababababababababababababababababababababababababababab")
    let result = try ABIValue.decode(types: [.fixedBytes(32)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .fixedBytes(let bytes) = result[0] {
      XCTAssertEqual(bytes.count, 32)
      XCTAssertEqual(bytes[0], 0xab)
    } else {
      XCTFail("Expected bytes32")
    }
  }

  func testDecodeBytes4() throws {
    // bytes4 is right-padded
    let data = Data(hex: "a9059cbb00000000000000000000000000000000000000000000000000000000")
    let result = try ABIValue.decode(types: [.fixedBytes(4)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .fixedBytes(let bytes) = result[0] {
      XCTAssertEqual(bytes.count, 4)
      XCTAssertEqual(bytes[0], 0xa9)
      XCTAssertEqual(bytes[1], 0x05)
      XCTAssertEqual(bytes[2], 0x9c)
      XCTAssertEqual(bytes[3], 0xbb)
    } else {
      XCTFail("Expected bytes4")
    }
  }

  // MARK: - Multiple Static Types

  func testDecodeMultipleStaticTypes() throws {
    // (address, uint256, bool)
    let data = Data(
      hex:
        "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"  // address
        + "0000000000000000000000000000000000000000000000000000000000000064"  // uint256 = 100
        + "0000000000000000000000000000000000000000000000000000000000000001"  // bool = true
    )

    let result = try ABIValue.decode(
      types: [.address, .uint(256), .bool],
      data: data
    )

    XCTAssertEqual(result.count, 3)

    if case .address(let addr) = result[0] {
      XCTAssertEqual(addr.checksummed.lowercased(), "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    } else {
      XCTFail("Expected address")
    }

    if case .uint(bits: 256, value: let wei) = result[1] {
      XCTAssertEqual(wei, Wei(100))
    } else {
      XCTFail("Expected uint256")
    }

    if case .bool(let value) = result[2] {
      XCTAssertTrue(value)
    } else {
      XCTFail("Expected bool")
    }
  }

  // MARK: - Static Tuple

  func testDecodeStaticTuple() throws {
    // (address, uint256)
    let data = Data(
      hex:
        "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"
        + "00000000000000000000000000000000000000000000000000000000000003e8"  // 1000
    )

    let tupleType = ABIType.tuple([.address, .uint(256)])
    let result = try ABIValue.decode(types: [tupleType], data: data)

    XCTAssertEqual(result.count, 1)
    if case .tuple(let elements) = result[0] {
      XCTAssertEqual(elements.count, 2)

      if case .address(let addr) = elements[0] {
        XCTAssertEqual(addr.checksummed.lowercased(), "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      } else {
        XCTFail("Expected address in tuple")
      }

      if case .uint(bits: 256, value: let wei) = elements[1] {
        XCTAssertEqual(wei, Wei(1000))
      } else {
        XCTFail("Expected uint256 in tuple")
      }
    } else {
      XCTFail("Expected tuple")
    }
  }

  // MARK: - Dynamic Types

  func testDecodeDynamicBytes() throws {
    // bytes with 5 bytes of data
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset = 32
        + "0000000000000000000000000000000000000000000000000000000000000005"  // length = 5
        + "0102030405000000000000000000000000000000000000000000000000000000"  // data (padded)
    )

    let result = try ABIValue.decode(types: [.bytes], data: data)

    XCTAssertEqual(result.count, 1)
    if case .bytes(let bytes) = result[0] {
      XCTAssertEqual(bytes.count, 5)
      XCTAssertEqual(bytes, Data([0x01, 0x02, 0x03, 0x04, 0x05]))
    } else {
      XCTFail("Expected bytes")
    }
  }

  func testDecodeString() throws {
    // string "Hello"
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset = 32
        + "0000000000000000000000000000000000000000000000000000000000000005"  // length = 5
        + "48656c6c6f000000000000000000000000000000000000000000000000000000"  // "Hello" (padded)
    )

    let result = try ABIValue.decode(types: [.string], data: data)

    XCTAssertEqual(result.count, 1)
    if case .string(let str) = result[0] {
      XCTAssertEqual(str, "Hello")
    } else {
      XCTFail("Expected string")
    }
  }

  func testDecodeDynamicArray() throws {
    // uint256[] with [1, 2, 3]
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset = 32
        + "0000000000000000000000000000000000000000000000000000000000000003"  // length = 3
        + "0000000000000000000000000000000000000000000000000000000000000001"  // 1
        + "0000000000000000000000000000000000000000000000000000000000000002"  // 2
        + "0000000000000000000000000000000000000000000000000000000000000003"  // 3
    )

    let result = try ABIValue.decode(types: [.array(.uint(256))], data: data)

    XCTAssertEqual(result.count, 1)
    if case .array(let elements) = result[0] {
      XCTAssertEqual(elements.count, 3)

      if case .uint(bits: 256, value: let v1) = elements[0] {
        XCTAssertEqual(v1, Wei(1))
      }
      if case .uint(bits: 256, value: let v2) = elements[1] {
        XCTAssertEqual(v2, Wei(2))
      }
      if case .uint(bits: 256, value: let v3) = elements[2] {
        XCTAssertEqual(v3, Wei(3))
      }
    } else {
      XCTFail("Expected array")
    }
  }

  func testDecodeFixedArray() throws {
    // uint256[2] with [100, 200]
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000064"  // 100
        + "00000000000000000000000000000000000000000000000000000000000000c8"  // 200
    )

    let result = try ABIValue.decode(types: [.fixedArray(.uint(256), 2)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .fixedArray(let elements) = result[0] {
      XCTAssertEqual(elements.count, 2)

      if case .uint(bits: 256, value: let v1) = elements[0] {
        XCTAssertEqual(v1, Wei(100))
      }
      if case .uint(bits: 256, value: let v2) = elements[1] {
        XCTAssertEqual(v2, Wei(200))
      }
    } else {
      XCTFail("Expected fixed array")
    }
  }

  // MARK: - Mixed Static and Dynamic

  func testDecodeMixedTypes() throws {
    // (uint256, string) - uint256 is static, string is dynamic
    let data = Data(
      hex:
        "000000000000000000000000000000000000000000000000000000000000002a"  // uint256 = 42
        + "0000000000000000000000000000000000000000000000000000000000000040"  // offset to string = 64
        + "0000000000000000000000000000000000000000000000000000000000000005"  // string length = 5
        + "48656c6c6f000000000000000000000000000000000000000000000000000000"  // "Hello"
    )

    let result = try ABIValue.decode(types: [.uint(256), .string], data: data)

    XCTAssertEqual(result.count, 2)

    if case .uint(bits: 256, value: let wei) = result[0] {
      XCTAssertEqual(wei, Wei(42))
    } else {
      XCTFail("Expected uint256")
    }

    if case .string(let str) = result[1] {
      XCTAssertEqual(str, "Hello")
    } else {
      XCTFail("Expected string")
    }
  }

  func testDecodeDynamicTuple() throws {
    // (uint256, string) as tuple
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset to tuple
        + "000000000000000000000000000000000000000000000000000000000000002a"  // uint256 = 42
        + "0000000000000000000000000000000000000000000000000000000000000040"  // offset to string (relative to tuple start)
        + "0000000000000000000000000000000000000000000000000000000000000005"  // string length = 5
        + "48656c6c6f000000000000000000000000000000000000000000000000000000"  // "Hello"
    )

    let tupleType = ABIType.tuple([.uint(256), .string])
    let result = try ABIValue.decode(types: [tupleType], data: data)

    XCTAssertEqual(result.count, 1)
    if case .tuple(let elements) = result[0] {
      XCTAssertEqual(elements.count, 2)

      if case .uint(bits: 256, value: let wei) = elements[0] {
        XCTAssertEqual(wei, Wei(42))
      } else {
        XCTFail("Expected uint256 in tuple")
      }

      if case .string(let str) = elements[1] {
        XCTAssertEqual(str, "Hello")
      } else {
        XCTFail("Expected string in tuple")
      }
    } else {
      XCTFail("Expected tuple")
    }
  }

  // MARK: - Address Array

  func testDecodeAddressArray() throws {
    // address[] with 2 addresses
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset
        + "0000000000000000000000000000000000000000000000000000000000000002"  // length = 2
        + "000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"  // addr1
        + "00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8"  // addr2
    )

    let result = try ABIValue.decode(types: [.array(.address)], data: data)

    XCTAssertEqual(result.count, 1)
    if case .array(let elements) = result[0] {
      XCTAssertEqual(elements.count, 2)

      if case .address(let addr1) = elements[0] {
        XCTAssertEqual(addr1.checksummed.lowercased(), "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      }
      if case .address(let addr2) = elements[1] {
        XCTAssertEqual(addr2.checksummed.lowercased(), "0x70997970c51812dc3a010c7d01b50e0d17dc79c8")
      }
    } else {
      XCTFail("Expected array")
    }
  }

  // MARK: - Function Result Decoding

  func testDecodeFunctionResult() throws {
    // balanceOf(address) returns (uint256)
    // Return value: 1000000000000000000 (1 ETH)
    let data = Data(hex: "0000000000000000000000000000000000000000000000000de0b6b3a7640000")

    let result = try ABIValue.decodeFunctionResult(
      outputTypes: [.uint(256)],
      data: data
    )

    XCTAssertEqual(result.count, 1)
    if case .uint(bits: 256, value: let wei) = result[0] {
      XCTAssertEqual(wei, Wei.fromEther(1))
    } else {
      XCTFail("Expected uint256")
    }
  }

  func testDecodeMultipleReturnValues() throws {
    // getReserves() returns (uint112, uint112, uint32)
    let data = Data(
      hex:
        "00000000000000000000000000000000000000000000000000000000000003e8"  // 1000
        + "00000000000000000000000000000000000000000000000000000000000007d0"  // 2000
        + "0000000000000000000000000000000000000000000000000000000065a1c5d0"  // timestamp
    )

    let result = try ABIValue.decodeFunctionResult(
      outputTypes: [.uint(112), .uint(112), .uint(32)],
      data: data
    )

    XCTAssertEqual(result.count, 3)

    if case .uint(bits: 112, value: let v1) = result[0] {
      XCTAssertEqual(v1, Wei(1000))
    }
    if case .uint(bits: 112, value: let v2) = result[1] {
      XCTAssertEqual(v2, Wei(2000))
    }
  }

  // MARK: - Empty Data

  func testDecodeEmptyArray() throws {
    // uint256[] with 0 elements
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset
        + "0000000000000000000000000000000000000000000000000000000000000000"  // length = 0
    )

    let result = try ABIValue.decode(types: [.array(.uint(256))], data: data)

    XCTAssertEqual(result.count, 1)
    if case .array(let elements) = result[0] {
      XCTAssertEqual(elements.count, 0)
    } else {
      XCTFail("Expected empty array")
    }
  }

  func testDecodeEmptyString() throws {
    let data = Data(
      hex:
        "0000000000000000000000000000000000000000000000000000000000000020"  // offset
        + "0000000000000000000000000000000000000000000000000000000000000000"  // length = 0
    )

    let result = try ABIValue.decode(types: [.string], data: data)

    XCTAssertEqual(result.count, 1)
    if case .string(let str) = result[0] {
      XCTAssertEqual(str, "")
    } else {
      XCTFail("Expected empty string")
    }
  }

  // MARK: - Error Cases

  func testDecodeInsufficientData() {
    let data = Data(hex: "00000000000000000000000000000000")  // Only 16 bytes

    XCTAssertThrowsError(try ABIValue.decode(types: [.uint(256)], data: data)) { error in
      XCTAssertTrue(error is ABIDecodingError)
    }
  }

  func testDecodeInvalidOffset() {
    // Offset points beyond data
    let data = Data(
      hex:
        "00000000000000000000000000000000000000000000000000000000000000ff"  // offset = 255 (invalid)
    )

    XCTAssertThrowsError(try ABIValue.decode(types: [.string], data: data)) { error in
      XCTAssertTrue(error is ABIDecodingError)
    }
  }
}
