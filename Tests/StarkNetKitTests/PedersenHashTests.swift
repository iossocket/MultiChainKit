//
//  PedersenHashTests.swift
//  StarknetKitTests
//
//  Tests for Pedersen hash function
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

@Suite("PedersenHash Tests")
struct PedersenHashTests {

  // MARK: - hash(a, b)

  @Test("Pedersen hash: (1, 2)")
  func hashOneTwo() throws {
    let result = try Pedersen.hash(Felt(1), Felt(2))
    #expect(result == Felt("0x5bb9440e27889a364bcb678b1f679ecd1347acdedcbf36e83494f857cc58026")!)
  }

  @Test("Pedersen hash: (0, 0)")
  func hashZeroZero() throws {
    let result = try Pedersen.hash(.zero, .zero)
    #expect(result == Felt("0x49ee3eba8c1600700ee1b87eb599f16716b0b1022947733551fde4050ca6804")!)
  }

  @Test("Pedersen hash: (1, 0)")
  func hashOneZero() throws {
    let result = try Pedersen.hash(Felt(1), .zero)
    #expect(result == Felt("0x268a9d47dde48af4b6e2c33932ed1c13adec25555abaa837c376af4ea2f8a94")!)
  }

  @Test("Pedersen hash: (0, 1)")
  func hashZeroOne() throws {
    let result = try Pedersen.hash(.zero, Felt(1))
    #expect(result == Felt("0x46c9aeb066cc2f41c7124af30514f9e607137fbac950524f5fdace5788f9d43")!)
  }

  @Test("Pedersen hash: (maxFelt, maxFelt)")
  func hashMaxMax() throws {
    let maxFelt = Felt(Felt.PRIME - 1)
    let result = try Pedersen.hash(maxFelt, maxFelt)
    #expect(result == Felt("0x7258fccaf3371fad51b117471d9d888a1786c5694c3e6099160477b593a576e")!)
  }

  @Test("Pedersen hash: large values")
  func hashLargeValues() throws {
    let a = Felt("0x7abcde123245643903241432abcde")!
    let b = Felt("0x791234124214214728147241242142a89b812221c21d")!
    let result = try Pedersen.hash(a, b)
    #expect(result == Felt("0x440a3075f082daa47147a22a4cd0c934ef65ea13ef87bf13adf45613e12f6ee")!)
  }

  @Test("Pedersen hash: chained result")
  func hashChained() throws {
    let a = Felt("0x46c9aeb066cc2f41c7124af30514f9e607137fbac950524f5fdace5788f9d43")!
    let b = Felt("0x49ee3eba8c1600700ee1b87eb599f16716b0b1022947733551fde4050ca6804")!
    let result = try Pedersen.hash(a, b)
    #expect(result == Felt("0x68ad69169c41c758ebd02e2fce51716497a708232a45a1b83e82fac1ade326e")!)
  }

  @Test("Pedersen hash: zero first element")
  func hashZeroFirst() throws {
    let b = Felt("0x15d40a3d6ca2ac30f4031e42be28da9b056fef9bb7357ac5e85627ee876e5ad")!
    let result = try Pedersen.hash(.zero, b)
    #expect(result == Felt("0x1a0c3e0f68c3ee702017fdb6452339244840eedbb70ab3d4f45e2affd1c9420")!)
  }

  // MARK: - hashMany (pedersenOn)

  @Test("PedersenOn: empty array")
  func hashManyEmpty() throws {
    let result = try Pedersen.hashMany([])
    #expect(result == Felt("0x49ee3eba8c1600700ee1b87eb599f16716b0b1022947733551fde4050ca6804")!)
  }

  @Test("PedersenOn: integer values")
  func hashManyIntegers() throws {
    let result = try Pedersen.hashMany([Felt(123_782_376), Felt(213_984), Felt(128_763_521_321)])
    #expect(result == Felt("0x7b422405da6571242dfc245a43de3b0fe695e7021c148b918cd9cdb462cac59")!)
  }

  @Test("PedersenOn: hex values")
  func hashManyHex() throws {
    let a = Felt("0x15d40a3d6ca2ac30f4031e42be28da9b056fef9bb7357ac5e85627ee876e5ad")!
    let b = Felt("0x10927538dee311ae5093324fc180ab87f23bbd7bc05456a12a1a506f220db25")!
    let result = try Pedersen.hashMany([a, b])
    #expect(result == Felt("0x43e637ca70a5daac877cba6b57e0b9ceffc5b37d28509e46b4fd2dee968a70c")!)
  }
}
