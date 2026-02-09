//
//  StarknetTransactionTests.swift
//  StarknetKitTests
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

// MARK: - Multicall Encoding

@Suite("StarknetCall.encodeMulticall")
struct MulticallTests {

  @Test("Empty calls array")
  func encodeEmpty() {
    let result = StarknetCall.encodeMulticall([])
    // [0] — zero calls
    #expect(result == [Felt.zero])
  }

  @Test("Single call with no calldata")
  func encodeSingleNoCalldata() {
    let call = StarknetCall(
      contractAddress: Felt(0x1),
      entryPointSelector: Felt(0x2),
      calldata: []
    )
    let result = StarknetCall.encodeMulticall([call])
    // [1, 0x1, 0x2, 0, ]
    #expect(result == [Felt(1), Felt(0x1), Felt(0x2), Felt.zero])
  }

  @Test("Single call with calldata")
  func encodeSingleWithCalldata() {
    let call = StarknetCall(
      contractAddress: Felt(0xabc),
      entryPointSelector: Felt(0xdef),
      calldata: [Felt(100), Felt(200)]
    )
    let result = StarknetCall.encodeMulticall([call])
    // [1, 0xabc, 0xdef, 2, 100, 200]
    #expect(result == [Felt(1), Felt(0xabc), Felt(0xdef), Felt(2), Felt(100), Felt(200)])
  }

  @Test("Multiple calls")
  func encodeMultiple() {
    let call1 = StarknetCall(
      contractAddress: Felt(0x1),
      entryPointSelector: Felt(0x2),
      calldata: [Felt(10)]
    )
    let call2 = StarknetCall(
      contractAddress: Felt(0x3),
      entryPointSelector: Felt(0x4),
      calldata: [Felt(20), Felt(30)]
    )
    let result = StarknetCall.encodeMulticall([call1, call2])
    // [2, 0x1, 0x2, 1, 10, 0x3, 0x4, 2, 20, 30]
    #expect(
      result == [
        Felt(2),
        Felt(0x1), Felt(0x2), Felt(1), Felt(10),
        Felt(0x3), Felt(0x4), Felt(2), Felt(20), Felt(30),
      ])
  }
}

// MARK: - DA Mode Encoding

@Suite("StarknetTransactionHashUtil.encodeDAModes")
struct DAModeTests {

  @Test("Both L1")
  func bothL1() {
    let result = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l1, nonceDAMode: .l1)
    // (0 << 32) + 0 = 0
    #expect(result == Felt.zero)
  }

  @Test("Fee L2, Nonce L1")
  func feeL2NonceL1() {
    let result = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l2, nonceDAMode: .l1)
    // (0 << 32) + 1 = 1
    #expect(result == Felt(1))
  }

  @Test("Fee L1, Nonce L2")
  func feeL1NonceL2() {
    let result = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l1, nonceDAMode: .l2)
    // (1 << 32) + 0 = 4294967296
    #expect(result == Felt(UInt64(1) << 32))
  }

  @Test("Both L2")
  func bothL2() {
    let result = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l2, nonceDAMode: .l2)
    // (1 << 32) + 1 = 4294967297
    #expect(result == Felt((UInt64(1) << 32) + 1))
  }
}

// MARK: - Resource Bounds Encoding

@Suite("StarknetTransactionHashUtil.encodeResourceBounds")
struct ResourceBoundsTests {

  @Test("Zero bounds")
  func zeroBounds() {
    let bounds = StarknetResourceBoundsMapping.zero
    let result = StarknetTransactionHashUtil.encodeResourceBounds(bounds)
    #expect(result.count == 3)
    // Each should be: prefix << 192 | 0 | 0 = just the prefix shifted
    // L1_GAS prefix = Felt.fromShortString("L1_GAS")
    let l1GasPrefix = Felt.fromShortString("L1_GAS")
    let l2GasPrefix = Felt.fromShortString("L2_GAS")
    let l1DataPrefix = Felt.fromShortString("L1_DATA")

    // prefix << 192: shift the prefix value left by 192 bits
    let l1Expected = Felt(l1GasPrefix.bigUIntValue << 192)
    let l2Expected = Felt(l2GasPrefix.bigUIntValue << 192)
    let l1DataExpected = Felt(l1DataPrefix.bigUIntValue << 192)

    #expect(result[0] == l1Expected)
    #expect(result[1] == l2Expected)
    #expect(result[2] == l1DataExpected)
  }

  @Test("Non-zero bounds")
  func nonZeroBounds() {
    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: 1000, maxPricePerUnit: BigUInt(500)),
      l2Gas: StarknetResourceBounds(maxAmount: 2000, maxPricePerUnit: BigUInt(100)),
      l1DataGas: .zero
    )
    let result = StarknetTransactionHashUtil.encodeResourceBounds(bounds)
    #expect(result.count == 3)

    // L1_GAS: prefix << 192 | 1000 << 128 | 500
    let l1GasPrefix = Felt.fromShortString("L1_GAS")
    let expected0 = Felt(
      (l1GasPrefix.bigUIntValue << 192)
        + (BigUInt(1000) << 128)
        + BigUInt(500)
    )
    #expect(result[0] == expected0)

    // L2_GAS: prefix << 192 | 2000 << 128 | 100
    let l2GasPrefix = Felt.fromShortString("L2_GAS")
    let expected1 = Felt(
      (l2GasPrefix.bigUIntValue << 192)
        + (BigUInt(2000) << 128)
        + BigUInt(100)
    )
    #expect(result[1] == expected1)
  }

  @Test("Large maxPricePerUnit (128-bit)")
  func largePricePerUnit() {
    let largePrice = BigUInt(1) << 64 + BigUInt(42)
    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: UInt64.max, maxPricePerUnit: largePrice),
      l2Gas: .zero,
      l1DataGas: .zero
    )
    let result = StarknetTransactionHashUtil.encodeResourceBounds(bounds)

    let l1GasPrefix = Felt.fromShortString("L1_GAS")
    let expected = Felt(
      (l1GasPrefix.bigUIntValue << 192)
        + (BigUInt(UInt64.max) << 128)
        + largePrice
    )
    #expect(result[0] == expected)
  }
}

// MARK: - Contract Address Calculation

@Suite("StarknetContractAddress.calculate")
struct ContractAddressTests {

  @Test("Zero deployer, simple inputs")
  func zeroDeployer() throws {
    // address = pedersen_on(["STARKNET_CONTRACT_ADDRESS", 0, salt, classHash, pedersen_on(calldata)]) mod 2^251
    let classHash = Felt(0x1234)
    let salt = Felt(0x5678)
    let calldata: [Felt] = [Felt(0xaa), Felt(0xbb)]

    let address = try StarknetContractAddress.calculate(
      classHash: classHash,
      calldata: calldata,
      salt: salt,
      deployerAddress: .zero
    )

    // Verify by computing manually:
    let calldataHash = try Pedersen.hashMany(calldata)
    let prefix = Felt.fromShortString("STARKNET_CONTRACT_ADDRESS")
    let fullHash = try Pedersen.hashMany([prefix, .zero, salt, classHash, calldataHash])
    // mod 2^251
    let mask = BigUInt(1) << 251
    let expected = Felt(fullHash.bigUIntValue % mask)

    #expect(address == expected)
  }

  @Test("Non-zero deployer")
  func nonZeroDeployer() throws {
    let classHash = Felt("0x29927c8af6bccf3f6fda035981e765a7bdbf18a2dc0d630494f8758aa908e2b")!
    let salt = Felt("0x1234")!
    let deployer = Felt("0x1")!
    let calldata: [Felt] = [Felt("0x5678")!]

    let address = try StarknetContractAddress.calculate(
      classHash: classHash,
      calldata: calldata,
      salt: salt,
      deployerAddress: deployer
    )

    // Verify manually
    let calldataHash = try Pedersen.hashMany(calldata)
    let prefix = Felt.fromShortString("STARKNET_CONTRACT_ADDRESS")
    let fullHash = try Pedersen.hashMany([prefix, deployer, salt, classHash, calldataHash])
    let mask = BigUInt(1) << 251
    let expected = Felt(fullHash.bigUIntValue % mask)

    #expect(address == expected)
  }

  @Test("Empty constructor calldata")
  func emptyCalldata() throws {
    let classHash = Felt(0xabc)
    let salt = Felt(0xdef)

    let address = try StarknetContractAddress.calculate(
      classHash: classHash,
      calldata: [],
      salt: salt
    )

    let calldataHash = try Pedersen.hashMany([])
    let prefix = Felt.fromShortString("STARKNET_CONTRACT_ADDRESS")
    let fullHash = try Pedersen.hashMany([prefix, .zero, salt, classHash, calldataHash])
    let mask = BigUInt(1) << 251
    let expected = Felt(fullHash.bigUIntValue % mask)

    #expect(address == expected)
  }
}

// MARK: - InvokeV1 Transaction Hash

@Suite("StarknetInvokeV1.transactionHash")
struct InvokeV1HashTests {

  @Test("Simple invoke V1")
  func simpleInvokeV1() throws {
    // hash = pedersen_on([invoke_prefix, 1, sender, 0, pedersen_on(calldata), maxFee, chainId, nonce])
    let sender = Felt("0x13e3ca9a377084c37dc7ab70e4f5b849f7ef5da6ca1aaf71f76ae4765aa3c8a")!
    let calldata: [Felt] = [Felt(0x1), Felt(0x2), Felt(0x3)]
    let maxFee = Felt(1000)
    let nonce = Felt(7)
    let chainId = Felt.fromShortString("SN_SEPOLIA")

    let tx = StarknetInvokeV1(
      senderAddress: sender,
      calldata: calldata,
      maxFee: maxFee,
      nonce: nonce,
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    // Verify manually
    let invokePrefix = Felt.fromShortString("invoke")
    let calldataHash = try Pedersen.hashMany(calldata)
    let expected = try Pedersen.hashMany([
      invokePrefix, Felt(1), sender, .zero, calldataHash, maxFee, chainId, nonce,
    ])

    #expect(hash == expected)
  }

  @Test("Invoke V1 with empty calldata")
  func emptyCalldata() throws {
    let sender = Felt(0x123)
    let maxFee = Felt(0)
    let nonce = Felt.zero
    let chainId = Felt.fromShortString("SN_MAIN")

    let tx = StarknetInvokeV1(
      senderAddress: sender,
      calldata: [],
      maxFee: maxFee,
      nonce: nonce,
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    let invokePrefix = Felt.fromShortString("invoke")
    let calldataHash = try Pedersen.hashMany([])
    let expected = try Pedersen.hashMany([
      invokePrefix, Felt(1), sender, .zero, calldataHash, maxFee, chainId, nonce,
    ])

    #expect(hash == expected)
  }

  @Test("Invoke V1 signature not included in hash")
  func signatureNotInHash() throws {
    let sender = Felt(0x456)
    let calldata: [Felt] = [Felt(1)]
    let maxFee = Felt(100)
    let nonce = Felt(1)
    let chainId = Felt.fromShortString("SN_SEPOLIA")

    let tx1 = StarknetInvokeV1(
      senderAddress: sender, calldata: calldata, maxFee: maxFee,
      nonce: nonce, chainId: chainId, signature: [])
    let tx2 = StarknetInvokeV1(
      senderAddress: sender, calldata: calldata, maxFee: maxFee,
      nonce: nonce, chainId: chainId, signature: [Felt(999), Felt(888)])

    let hash1 = try tx1.transactionHash()
    let hash2 = try tx2.transactionHash()

    #expect(hash1 == hash2)
  }
}

// MARK: - InvokeV3 Transaction Hash

@Suite("StarknetInvokeV3.transactionHash")
struct InvokeV3HashTests {

  @Test("Simple invoke V3")
  func simpleInvokeV3() throws {
    // hash = poseidon_many([invoke_prefix, 3, sender, fee_field_hash, poseidon_many(paymaster),
    //                       chainId, nonce, da_modes, poseidon_many(account_deploy_data), poseidon_many(calldata)])
    let sender = Felt("0x13e3ca9a377084c37dc7ab70e4f5b849f7ef5da6ca1aaf71f76ae4765aa3c8a")!
    let calldata: [Felt] = [Felt(0x1), Felt(0x2)]
    let nonce = Felt(3)
    let chainId = Felt.fromShortString("SN_SEPOLIA")
    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: 1000, maxPricePerUnit: BigUInt(500)),
      l2Gas: StarknetResourceBounds(maxAmount: 2000, maxPricePerUnit: BigUInt(100)),
      l1DataGas: .zero
    )

    let tx = StarknetInvokeV3(
      senderAddress: sender,
      calldata: calldata,
      resourceBounds: bounds,
      tip: 0,
      nonce: nonce,
      nonceDAMode: .l1,
      feeDAMode: .l1,
      paymasterData: [],
      accountDeploymentData: [],
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    // Verify manually
    let invokePrefix = Felt.fromShortString("invoke")
    let encodedBounds = StarknetTransactionHashUtil.encodeResourceBounds(bounds)
    let feeFieldHash = try Poseidon.hashMany([Felt(0)] + encodedBounds)  // tip=0
    let paymasterHash = try Poseidon.hashMany([])
    let daModes = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l1, nonceDAMode: .l1)
    let accountDeployHash = try Poseidon.hashMany([])
    let calldataHash = try Poseidon.hashMany(calldata)

    let expected = try Poseidon.hashMany([
      invokePrefix, Felt(3), sender, feeFieldHash, paymasterHash,
      chainId, nonce, daModes, accountDeployHash, calldataHash,
    ])

    #expect(hash == expected)
  }

  @Test("Invoke V3 with paymaster data")
  func withPaymasterData() throws {
    let sender = Felt(0x789)
    let calldata: [Felt] = [Felt(42)]
    let nonce = Felt(1)
    let chainId = Felt.fromShortString("SN_MAIN")
    let paymasterData: [Felt] = [Felt(0xa01), Felt(0xa02)]
    let bounds = StarknetResourceBoundsMapping.zero

    let tx = StarknetInvokeV3(
      senderAddress: sender,
      calldata: calldata,
      resourceBounds: bounds,
      tip: 100,
      nonce: nonce,
      nonceDAMode: .l2,
      feeDAMode: .l1,
      paymasterData: paymasterData,
      accountDeploymentData: [],
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    let invokePrefix = Felt.fromShortString("invoke")
    let encodedBounds = StarknetTransactionHashUtil.encodeResourceBounds(bounds)
    let feeFieldHash = try Poseidon.hashMany([Felt(100)] + encodedBounds)
    let paymasterHash = try Poseidon.hashMany(paymasterData)
    let daModes = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l1, nonceDAMode: .l2)
    let accountDeployHash = try Poseidon.hashMany([])
    let calldataHash = try Poseidon.hashMany(calldata)

    let expected = try Poseidon.hashMany([
      invokePrefix, Felt(3), sender, feeFieldHash, paymasterHash,
      chainId, nonce, daModes, accountDeployHash, calldataHash,
    ])

    #expect(hash == expected)
  }

  @Test("Invoke V3 signature not included in hash")
  func signatureNotInHash() throws {
    let sender = Felt(0x456)
    let calldata: [Felt] = [Felt(1)]
    let nonce = Felt(1)
    let chainId = Felt.fromShortString("SN_SEPOLIA")
    let bounds = StarknetResourceBoundsMapping.zero

    let tx1 = StarknetInvokeV3(
      senderAddress: sender, calldata: calldata, resourceBounds: bounds,
      nonce: nonce, chainId: chainId, signature: [])
    let tx2 = StarknetInvokeV3(
      senderAddress: sender, calldata: calldata, resourceBounds: bounds,
      nonce: nonce, chainId: chainId, signature: [Felt(999), Felt(888)])

    let hash1 = try tx1.transactionHash()
    let hash2 = try tx2.transactionHash()

    #expect(hash1 == hash2)
  }
}

// MARK: - DeployAccountV1 Transaction Hash

@Suite("StarknetDeployAccountV1")
struct DeployAccountV1Tests {

  @Test("Contract address calculation")
  func contractAddress() throws {
    let classHash = Felt("0x29927c8af6bccf3f6fda035981e765a7bdbf18a2dc0d630494f8758aa908e2b")!
    let salt = Felt("0x1234")!
    let constructorCalldata: [Felt] = [Felt("0x5678")!]

    let tx = StarknetDeployAccountV1(
      classHash: classHash,
      contractAddressSalt: salt,
      constructorCalldata: constructorCalldata,
      maxFee: Felt(1000),
      nonce: .zero,
      chainId: Felt.fromShortString("SN_SEPOLIA")
    )

    let address = try tx.contractAddress()

    // Should match StarknetContractAddress.calculate with deployer=0
    let expected = try StarknetContractAddress.calculate(
      classHash: classHash,
      calldata: constructorCalldata,
      salt: salt,
      deployerAddress: .zero
    )

    #expect(address == expected)
  }

  @Test("Transaction hash")
  func transactionHash() throws {
    // hash = pedersen_on([deploy_account_prefix, 1, contract_address, 0,
    //                     pedersen_on([classHash, salt, ...constructor_calldata]), maxFee, chainId, nonce])
    let classHash = Felt(0xabc)
    let salt = Felt(0xdef)
    let constructorCalldata: [Felt] = [Felt(0x11), Felt(0x22)]
    let maxFee = Felt(5000)
    let nonce = Felt.zero
    let chainId = Felt.fromShortString("SN_SEPOLIA")

    let tx = StarknetDeployAccountV1(
      classHash: classHash,
      contractAddressSalt: salt,
      constructorCalldata: constructorCalldata,
      maxFee: maxFee,
      nonce: nonce,
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    // Compute expected
    let contractAddress = try tx.contractAddress()
    let deployAccountPrefix = Felt.fromShortString("deploy_account")
    let calldataForHash: [Felt] = [classHash, salt] + constructorCalldata
    let calldataHash = try Pedersen.hashMany(calldataForHash)
    let expected = try Pedersen.hashMany([
      deployAccountPrefix, Felt(1), contractAddress, .zero, calldataHash, maxFee, chainId, nonce,
    ])

    #expect(hash == expected)
  }

  @Test("Transaction hash with empty constructor calldata")
  func emptyConstructorCalldata() throws {
    let classHash = Felt(0x111)
    let salt = Felt(0x222)
    let maxFee = Felt(100)
    let nonce = Felt.zero
    let chainId = Felt.fromShortString("SN_MAIN")

    let tx = StarknetDeployAccountV1(
      classHash: classHash,
      contractAddressSalt: salt,
      constructorCalldata: [],
      maxFee: maxFee,
      nonce: nonce,
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    let contractAddress = try tx.contractAddress()
    let deployAccountPrefix = Felt.fromShortString("deploy_account")
    let calldataForHash: [Felt] = [classHash, salt]
    let calldataHash = try Pedersen.hashMany(calldataForHash)
    let expected = try Pedersen.hashMany([
      deployAccountPrefix, Felt(1), contractAddress, .zero, calldataHash, maxFee, chainId, nonce,
    ])

    #expect(hash == expected)
  }
}

// MARK: - DeployAccountV3 Transaction Hash

@Suite("StarknetDeployAccountV3")
struct DeployAccountV3Tests {

  @Test("Contract address calculation")
  func contractAddress() throws {
    let classHash = Felt(0xabc)
    let salt = Felt(0xdef)
    let constructorCalldata: [Felt] = [Felt(0x11)]

    let tx = StarknetDeployAccountV3(
      classHash: classHash,
      contractAddressSalt: salt,
      constructorCalldata: constructorCalldata,
      resourceBounds: .zero,
      nonce: .zero,
      chainId: Felt.fromShortString("SN_SEPOLIA")
    )

    let address = try tx.contractAddress()

    let expected = try StarknetContractAddress.calculate(
      classHash: classHash,
      calldata: constructorCalldata,
      salt: salt,
      deployerAddress: .zero
    )

    #expect(address == expected)
  }

  @Test("Transaction hash")
  func transactionHash() throws {
    // hash = poseidon_many([deploy_account_prefix, 3, contract_address, fee_field_hash,
    //                       poseidon_many(paymaster), chainId, nonce, da_modes,
    //                       poseidon_many(constructor_calldata), classHash, salt])
    let classHash = Felt(0xabc)
    let salt = Felt(0xdef)
    let constructorCalldata: [Felt] = [Felt(0x11), Felt(0x22)]
    let nonce = Felt.zero
    let chainId = Felt.fromShortString("SN_SEPOLIA")
    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: 500, maxPricePerUnit: BigUInt(200)),
      l2Gas: .zero,
      l1DataGas: .zero
    )

    let tx = StarknetDeployAccountV3(
      classHash: classHash,
      contractAddressSalt: salt,
      constructorCalldata: constructorCalldata,
      resourceBounds: bounds,
      tip: 0,
      nonce: nonce,
      nonceDAMode: .l1,
      feeDAMode: .l1,
      paymasterData: [],
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    // Verify manually
    let contractAddress = try tx.contractAddress()
    let deployAccountPrefix = Felt.fromShortString("deploy_account")
    let encodedBounds = StarknetTransactionHashUtil.encodeResourceBounds(bounds)
    let feeFieldHash = try Poseidon.hashMany([Felt(0)] + encodedBounds)
    let paymasterHash = try Poseidon.hashMany([])
    let daModes = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l1, nonceDAMode: .l1)
    let constructorHash = try Poseidon.hashMany(constructorCalldata)

    let expected = try Poseidon.hashMany([
      deployAccountPrefix, Felt(3), contractAddress, feeFieldHash, paymasterHash,
      chainId, nonce, daModes, constructorHash, classHash, salt,
    ])

    #expect(hash == expected)
  }

  @Test("Transaction hash with paymaster and DA modes")
  func withPaymasterAndDAModes() throws {
    let classHash = Felt(0x999)
    let salt = Felt(0x888)
    let constructorCalldata: [Felt] = [Felt(0x77)]
    let nonce = Felt(5)
    let chainId = Felt.fromShortString("SN_MAIN")
    let bounds = StarknetResourceBoundsMapping.zero
    let paymasterData: [Felt] = [Felt(0xaa)]

    let tx = StarknetDeployAccountV3(
      classHash: classHash,
      contractAddressSalt: salt,
      constructorCalldata: constructorCalldata,
      resourceBounds: bounds,
      tip: 50,
      nonce: nonce,
      nonceDAMode: .l2,
      feeDAMode: .l2,
      paymasterData: paymasterData,
      chainId: chainId
    )

    let hash = try tx.transactionHash()

    let contractAddress = try tx.contractAddress()
    let deployAccountPrefix = Felt.fromShortString("deploy_account")
    let encodedBounds = StarknetTransactionHashUtil.encodeResourceBounds(bounds)
    let feeFieldHash = try Poseidon.hashMany([Felt(50)] + encodedBounds)
    let paymasterHash = try Poseidon.hashMany(paymasterData)
    let daModes = StarknetTransactionHashUtil.encodeDAModes(feeDAMode: .l2, nonceDAMode: .l2)
    let constructorHash = try Poseidon.hashMany(constructorCalldata)

    let expected = try Poseidon.hashMany([
      deployAccountPrefix, Felt(3), contractAddress, feeFieldHash, paymasterHash,
      chainId, nonce, daModes, constructorHash, classHash, salt,
    ])

    #expect(hash == expected)
  }
}
