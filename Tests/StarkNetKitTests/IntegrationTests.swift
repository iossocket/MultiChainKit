//
//  IntegrationTests.swift
//  StarknetKitTests
//
//  Day 28: End-to-end integration tests covering the full Starknet workflow.
//  Private key → Account type → Compute address → Build tx → Sign → Verify.
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

// MARK: - Shared Fixtures

/// A deterministic private key for all integration tests.
private let testPrivateKey = Felt("0x0123456789abcdef0123456789abcdef")!

/// Sepolia chain for address/hash computation.
private let sepolia = Starknet.sepolia

// MARK: - 1. Account Type → Compute Address → Verify

@Suite("Integration: Account Address Derivation")
struct AccountAddressDerivationTests {

  @Test("OZ account: privateKey → publicKey → computeAddress is deterministic")
  func ozAccountAddress() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let oz = OpenZeppelinAccount()

    let addr1 = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    let addr2 = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    #expect(addr1 == addr2)

    // Constructor calldata is just [publicKey]
    #expect(oz.constructorCalldata(publicKey: pubKey) == [pubKey])
  }

  @Test("Different salt produces different address for same key")
  func differentSaltDifferentAddress() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let oz = OpenZeppelinAccount()

    let addr1 = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    let addr2 = try oz.computeAddress(publicKey: pubKey, salt: Felt(0x999))
    #expect(addr1 != addr2)
  }

  @Test("Different class hash produces different address")
  func differentClassHashDifferentAddress() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!

    let oz1 = OpenZeppelinAccount()
    let oz2 = OpenZeppelinAccount(classHash: Felt(0xDEAD))

    let addr1 = try oz1.computeAddress(publicKey: pubKey, salt: pubKey)
    let addr2 = try oz2.computeAddress(publicKey: pubKey, salt: pubKey)
    #expect(addr1 != addr2)
  }
}

// MARK: - 2. InvokeV3 Multicall → Sign → Verify

@Suite("Integration: InvokeV3 Multicall Sign & Verify")
struct InvokeV3MulticallTests {

  @Test("Build multicall InvokeV3, sign, verify signature")
  func multicallSignVerify() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let oz = OpenZeppelinAccount()
    let addr = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    let account = StarknetAccount(signer: signer, address: addr, chain: sepolia)

    // Two ERC-20 transfer calls
    let strkToken = Felt("0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d")!
    let call1 = StarknetCall(
      contractAddress: strkToken,
      entrypoint: "transfer",
      calldata: [Felt(0xBEEF), Felt(1000), .zero]  // recipient, amount_low, amount_high
    )
    let call2 = StarknetCall(
      contractAddress: strkToken,
      entrypoint: "transfer",
      calldata: [Felt(0xCAFE), Felt(2000), .zero]
    )

    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: 10000, maxPricePerUnit: 1_000_000_000),
      l2Gas: .zero,
      l1DataGas: .zero
    )

    let tx = account.buildInvokeV3(calls: [call1, call2], resourceBounds: bounds, nonce: Felt(7))

    // Verify multicall encoding: [2, to1, sel1, 3, data1..., to2, sel2, 3, data2...]
    #expect(tx.calldata[0] == Felt(2))  // 2 calls
    #expect(tx.senderAddress == account.addressFelt)
    #expect(tx.nonce == Felt(7))

    // Sign and verify
    let signed = try account.signInvokeV3(tx)
    #expect(signed.signature.count == 2)  // [r, s]

    let hash = try tx.transactionHash()
    let valid = try StarkCurve.verify(
      publicKey: pubKey, hash: hash,
      r: Felt(signed.signature[0].bigEndianData),
      s: Felt(signed.signature[1].bigEndianData)
    )
    #expect(valid)
  }

  @Test("InvokeV1 single call sign & verify")
  func invokeV1SignVerify() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let addr = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)
    let account = StarknetAccount(signer: signer, address: addr, chain: sepolia)

    let call = StarknetCall(
      contractAddress: Felt(0x1),
      entrypoint: "execute",
      calldata: [Felt(42)]
    )
    let tx = account.buildInvokeV1(calls: [call], maxFee: Felt(100_000), nonce: .zero)
    let signed = try account.signInvokeV1(tx)

    let hash = try tx.transactionHash()
    let valid = try StarkCurve.verify(
      publicKey: pubKey, hash: hash,
      r: Felt(signed.signature[0].bigEndianData),
      s: Felt(signed.signature[1].bigEndianData)
    )
    #expect(valid)
  }

  @Test("V1 and V3 produce different hashes for same logical call")
  func v1v3DifferentHashes() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let addr = try OpenZeppelinAccount().computeAddress(
      publicKey: signer.publicKeyFelt!, salt: signer.publicKeyFelt!)
    let account = StarknetAccount(signer: signer, address: addr, chain: sepolia)

    let call = StarknetCall(contractAddress: Felt(0x1), entrypoint: "foo", calldata: [Felt(1)])
    let v1 = account.buildInvokeV1(calls: [call], maxFee: Felt(100), nonce: .zero)
    let v3 = account.buildInvokeV3(calls: [call], resourceBounds: .zero, nonce: .zero)

    let h1 = try v1.transactionHash()
    let h3 = try v3.transactionHash()
    #expect(h1 != h3)  // Different hash algorithms (Pedersen vs Poseidon)
  }
}

// MARK: - 3. DeployAccount → Sign → Verify

@Suite("Integration: DeployAccount Sign & Verify")
struct DeployAccountTests {

  @Test("DeployAccountV3: build, compute address, sign, verify")
  func deployAccountV3() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let oz = OpenZeppelinAccount()

    let deployTx = StarknetDeployAccountV3(
      classHash: oz.classHash,
      contractAddressSalt: pubKey,
      constructorCalldata: oz.constructorCalldata(publicKey: pubKey),
      resourceBounds: StarknetResourceBoundsMapping(
        l1Gas: StarknetResourceBounds(maxAmount: 5000, maxPricePerUnit: 500_000_000),
        l2Gas: .zero,
        l1DataGas: .zero
      ),
      nonce: .zero,
      chainId: sepolia.chainId
    )

    // Contract address from deploy tx matches account type computation
    let deployAddr = try deployTx.contractAddress()
    let expectedAddr = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    #expect(deployAddr == Felt(expectedAddr.data))

    // Sign via account
    let account = StarknetAccount(signer: signer, address: expectedAddr, chain: sepolia)
    let signed = try account.signDeployAccountV3(deployTx)
    #expect(signed.signature.count == 2)

    // Verify signature
    let hash = try deployTx.transactionHash()
    let valid = try StarkCurve.verify(
      publicKey: pubKey, hash: hash,
      r: Felt(signed.signature[0].bigEndianData),
      s: Felt(signed.signature[1].bigEndianData)
    )
    #expect(valid)
  }

  @Test("DeployAccountV1: build, sign, verify")
  func deployAccountV1() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let oz = OpenZeppelinAccount()

    let deployTx = StarknetDeployAccountV1(
      classHash: oz.classHash,
      contractAddressSalt: pubKey,
      constructorCalldata: oz.constructorCalldata(publicKey: pubKey),
      maxFee: Felt(50_000),
      nonce: .zero,
      chainId: sepolia.chainId
    )

    let deployAddr = try deployTx.contractAddress()
    let expectedAddr = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    #expect(deployAddr == Felt(expectedAddr.data))

    let account = StarknetAccount(signer: signer, address: expectedAddr, chain: sepolia)
    let signed = try account.signDeployAccountV1(deployTx)

    let hash = try deployTx.transactionHash()
    let valid = try StarkCurve.verify(
      publicKey: pubKey, hash: hash,
      r: Felt(signed.signature[0].bigEndianData),
      s: Felt(signed.signature[1].bigEndianData)
    )
    #expect(valid)
  }

  @Test("sendTransactionRequest builds correct RPC method for deploy")
  func sendDeployRequest() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let addr = try OpenZeppelinAccount().computeAddress(
      publicKey: signer.publicKeyFelt!, salt: signer.publicKeyFelt!)
    let account = StarknetAccount(signer: signer, address: addr, chain: sepolia)

    let deployTx = StarknetDeployAccountV3(
      classHash: OpenZeppelinAccount.defaultClassHash,
      contractAddressSalt: signer.publicKeyFelt!,
      constructorCalldata: [signer.publicKeyFelt!],
      resourceBounds: .zero,
      nonce: .zero,
      chainId: sepolia.chainId
    )
    let signed = try account.signDeployAccountV3(deployTx)
    let request = account.sendTransactionRequest(.deployAccountV3(signed))
    #expect(request.method == "starknet_addDeployAccountTransaction")
  }
}

// MARK: - 4. Cairo ABI Encode/Decode Round-Trip

@Suite("Integration: Cairo ABI Round-Trip")
struct CairoABIRoundTripTests {

  @Test("u256 encode → decode round-trip")
  func u256RoundTrip() throws {
    let original = CairoValue.u256(BigUInt("123456789012345678901234567890"))
    let encoded = original.encode()
    #expect(encoded.count == 2)  // low + high

    let (decoded, consumed) = try CairoValue.decode(type: .u256, from: encoded, at: 0)
    #expect(consumed == 2)
    #expect(decoded.u256Value == original.u256Value)
  }

  @Test("ByteArray encode → decode round-trip")
  func byteArrayRoundTrip() throws {
    let text = "Hello, Starknet! This is a long string that exceeds 31 bytes for testing."
    let original = CairoValue.byteArray(CairoByteArray(string: text))
    let encoded = original.encode()

    let (decoded, _) = try CairoValue.decode(type: .byteArray, from: encoded, at: 0)
    if case .byteArray(let ba) = decoded {
      #expect(ba.toString() == text)
    } else {
      Issue.record("Expected byteArray, got \(decoded)")
    }
  }

  @Test("Array of u128 encode → decode round-trip")
  func arrayRoundTrip() throws {
    let values: [CairoValue] = [.u128(BigUInt(100)), .u128(BigUInt(200)), .u128(BigUInt(300))]
    let original = CairoValue.array(values)
    let encoded = original.encode()
    // [length=3, 100, 200, 300]
    #expect(encoded.count == 4)
    #expect(encoded[0] == Felt(3))

    let (decoded, consumed) = try CairoValue.decode(type: .array(.u128), from: encoded, at: 0)
    #expect(consumed == 4)
    if case .array(let items) = decoded {
      #expect(items.count == 3)
      #expect(items[0] == .u128(BigUInt(100)))
      #expect(items[2] == .u128(BigUInt(300)))
    } else {
      Issue.record("Expected array")
    }
  }

  @Test("Mixed calldata: multiple values encode → decode")
  func mixedCalldata() throws {
    let values: [CairoValue] = [
      .felt252(Felt(0xABC)),
      .bool(true),
      .u256(BigUInt(999)),
      .contractAddress(Felt(0xDEAD)),
    ]
    let encoded = CairoValue.encodeCalldata(values)
    // felt252(1) + bool(1) + u256(2) + contractAddress(1) = 5 felts
    #expect(encoded.count == 5)

    var offset = 0
    let types: [CairoType] = [.felt252, .bool, .u256, .contractAddress]
    for (i, type) in types.enumerated() {
      let (decoded, consumed) = try CairoValue.decode(type: type, from: encoded, at: offset)
      #expect(decoded == values[i])
      offset += consumed
    }
    #expect(offset == encoded.count)
  }

  @Test("Option<felt252> some/none round-trip")
  func optionRoundTrip() throws {
    let some = CairoValue.some(.felt252(Felt(42)))
    let someEncoded = some.encode()
    #expect(someEncoded[0] == Felt.zero)  // variant 0 = Some
    let (someDecoded, _) = try CairoValue.decode(type: .option(.felt252), from: someEncoded, at: 0)
    #expect(someDecoded == some)

    let none = CairoValue.none
    let noneEncoded = none.encode()
    #expect(noneEncoded[0] == Felt(1))  // variant 1 = None
    let (noneDecoded, _) = try CairoValue.decode(type: .option(.felt252), from: noneEncoded, at: 0)
    #expect(noneDecoded == none)
  }
}

// MARK: - 5. SNIP-12 Typed Data → Sign → Verify

@Suite("Integration: SNIP-12 Sign & Verify")
struct SNIP12IntegrationTests {

  @Test("Full SNIP-12 v0 flow: typed data → messageHash → sign → verify")
  func snip12V0FullFlow() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let addr = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)

    let types: [String: [SNIP12Type]] = [
      "StarkNetDomain": [
        SNIP12Type(name: "name", type: "felt"),
        SNIP12Type(name: "version", type: "felt"),
        SNIP12Type(name: "chainId", type: "felt"),
      ],
      "Person": [
        SNIP12Type(name: "name", type: "felt"),
        SNIP12Type(name: "wallet", type: "felt"),
      ],
      "Mail": [
        SNIP12Type(name: "from", type: "Person"),
        SNIP12Type(name: "to", type: "Person"),
        SNIP12Type(name: "contents", type: "felt"),
      ],
    ]

    let domain = SNIP12Domain(name: "StarkNet Mail", version: "1", chainId: "1", revision: .v0)
    let message: [String: SNIP12Value] = [
      "from": .struct([
        "name": .felt(Felt.fromShortString("Alice")),
        "wallet": .felt(Felt(addr.data)),
      ]),
      "to": .struct([
        "name": .felt(Felt.fromShortString("Bob")),
        "wallet": .felt(Felt(0xBBB)),
      ]),
      "contents": .felt(Felt.fromShortString("Hello Bob")),
    ]

    let typedData = SNIP12TypedData(
      types: types, primaryType: "Mail", domain: domain, message: message)
    let hash = try typedData.messageHash(accountAddress: Felt(addr.data))
    #expect(hash != .zero)

    // Sign and verify
    let sig = try signer.sign(feltHash: hash)
    let valid = try StarkCurve.verify(publicKey: pubKey, hash: hash, r: sig.r, s: sig.s)
    #expect(valid)
  }

  @Test("Full SNIP-12 v1 flow: typed data → messageHash → sign → verify")
  func snip12V1FullFlow() throws {
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let addr = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)

    let types: [String: [SNIP12Type]] = [
      "StarknetDomain": [
        SNIP12Type(name: "name", type: "shortstring"),
        SNIP12Type(name: "version", type: "shortstring"),
        SNIP12Type(name: "chainId", type: "shortstring"),
        SNIP12Type(name: "revision", type: "shortstring"),
      ],
      "Order": [
        SNIP12Type(name: "amount", type: "u128"),
        SNIP12Type(name: "recipient", type: "ContractAddress"),
      ],
    ]

    let domain = SNIP12Domain(name: "MyDApp", version: "1", chainId: "SN_SEPOLIA", revision: .v1)
    let message: [String: SNIP12Value] = [
      "amount": .u128(Felt(1_000_000)),
      "recipient": .contractAddress(Felt(0xCAFE)),
    ]

    let typedData = SNIP12TypedData(
      types: types, primaryType: "Order", domain: domain, message: message)
    let hash = try typedData.messageHash(accountAddress: Felt(addr.data))
    #expect(hash != .zero)

    let sig = try signer.sign(feltHash: hash)
    let valid = try StarkCurve.verify(publicKey: pubKey, hash: hash, r: sig.r, s: sig.s)
    #expect(valid)
  }

  @Test("Same message, different accounts → different messageHash")
  func differentAccountsDifferentHash() throws {
    let types: [String: [SNIP12Type]] = [
      "StarkNetDomain": [
        SNIP12Type(name: "name", type: "felt"),
        SNIP12Type(name: "version", type: "felt"),
        SNIP12Type(name: "chainId", type: "felt"),
      ],
      "Simple": [
        SNIP12Type(name: "value", type: "felt")
      ],
    ]
    let domain = SNIP12Domain(name: "Test", version: "1", chainId: "1", revision: .v0)
    let message: [String: SNIP12Value] = ["value": .felt(Felt(42))]
    let typedData = SNIP12TypedData(
      types: types, primaryType: "Simple", domain: domain, message: message)

    let hash1 = try typedData.messageHash(accountAddress: Felt(0xAAA))
    let hash2 = try typedData.messageHash(accountAddress: Felt(0xBBB))
    #expect(hash1 != hash2)
  }
}

// MARK: - 6. Receipt Decode Integration

@Suite("Integration: Receipt Decode")
struct ReceiptIntegrationTests {

  @Test("Decode real invoke receipt JSON and inspect fields")
  func decodeInvokeReceipt() throws {
    let json = """
      {
        "type": "INVOKE",
        "transaction_hash": "0x06a09ffbf590de3e2b30fca4f4f2b0e48f0e0d183e6e22f9cbaa0164f7e8c30a",
        "actual_fee": { "amount": "0x2386f26fc10000", "unit": "FRI" },
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
          "data_availability": { "l1_gas": 0, "l1_data_gas": 128 }
        }
      }
      """
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: Data(json.utf8))

    #expect(receipt.type == "INVOKE")
    #expect(receipt.isSuccess)
    #expect(!receipt.isReverted)
    #expect(!receipt.isPending)
    #expect(receipt.events.count == 1)
    #expect(receipt.events[0].data.count == 3)
    #expect(
      receipt.transactionHashFelt == Felt(
        "0x06a09ffbf590de3e2b30fca4f4f2b0e48f0e0d183e6e22f9cbaa0164f7e8c30a")!)
    #expect(receipt.blockNumber == 123456)
    #expect(receipt.executionResources.steps == 1234)
  }

  @Test("Decode deploy account receipt")
  func decodeDeployReceipt() throws {
    let json = """
      {
        "type": "DEPLOY_ACCOUNT",
        "transaction_hash": "0x01234",
        "actual_fee": { "amount": "0x100", "unit": "WEI" },
        "execution_status": "SUCCEEDED",
        "finality_status": "ACCEPTED_ON_L1",
        "block_hash": "0x0abcd",
        "block_number": 999,
        "messages_sent": [],
        "events": [],
        "execution_resources": {
          "steps": 500,
          "data_availability": { "l1_gas": 10, "l1_data_gas": 20 }
        }
      }
      """
    let receipt = try JSONDecoder().decode(StarknetReceipt.self, from: Data(json.utf8))
    #expect(receipt.type == "DEPLOY_ACCOUNT")
    #expect(receipt.isSuccess)
    #expect(receipt.isAcceptedOnL1)
  }
}

// MARK: - 7. Full Workflow: Account Type → Deploy → Invoke → Sign

@Suite("Integration: Full Workflow")
struct FullWorkflowTests {

  @Test("OZ: derive address → build deploy → build invoke → both signed correctly")
  func ozFullWorkflow() throws {
    // 1. Derive keys and address
    let signer = try StarknetSigner(privateKey: testPrivateKey)
    let pubKey = signer.publicKeyFelt!
    let oz = OpenZeppelinAccount()
    let addr = try oz.computeAddress(publicKey: pubKey, salt: pubKey)
    let account = StarknetAccount(signer: signer, address: addr, chain: sepolia)

    // 2. Build and sign DeployAccountV3
    let deployTx = StarknetDeployAccountV3(
      classHash: oz.classHash,
      contractAddressSalt: pubKey,
      constructorCalldata: oz.constructorCalldata(publicKey: pubKey),
      resourceBounds: StarknetResourceBoundsMapping(
        l1Gas: StarknetResourceBounds(maxAmount: 5000, maxPricePerUnit: 1_000_000_000),
        l2Gas: .zero,
        l1DataGas: .zero
      ),
      nonce: .zero,
      chainId: sepolia.chainId
    )
    let signedDeploy = try account.signDeployAccountV3(deployTx)
    let deployHash = try deployTx.transactionHash()

    // 3. Build and sign InvokeV3 (ERC-20 approve)
    let strkToken = Felt("0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d")!
    let approveCall = StarknetCall(
      contractAddress: strkToken,
      entrypoint: "approve",
      calldata: [Felt(0xDEAD), Felt(UInt64.max), .zero]  // spender, amount_low, amount_high
    )
    let invokeTx = account.buildInvokeV3(
      calls: [approveCall],
      resourceBounds: StarknetResourceBoundsMapping(
        l1Gas: StarknetResourceBounds(maxAmount: 10000, maxPricePerUnit: 1_000_000_000),
        l2Gas: .zero,
        l1DataGas: .zero
      ),
      nonce: Felt(1)
    )
    let signedInvoke = try account.signInvokeV3(invokeTx)
    let invokeHash = try invokeTx.transactionHash()

    // 4. Verify both signatures
    #expect(deployHash != invokeHash)

    let deployValid = try StarkCurve.verify(
      publicKey: pubKey, hash: deployHash,
      r: Felt(signedDeploy.signature[0].bigEndianData),
      s: Felt(signedDeploy.signature[1].bigEndianData)
    )
    #expect(deployValid)

    let invokeValid = try StarkCurve.verify(
      publicKey: pubKey, hash: invokeHash,
      r: Felt(signedInvoke.signature[0].bigEndianData),
      s: Felt(signedInvoke.signature[1].bigEndianData)
    )
    #expect(invokeValid)

    // 5. Verify sendTransactionRequest builds correct RPC methods
    let deployReq = account.sendTransactionRequest(.deployAccountV3(signedDeploy))
    #expect(deployReq.method == "starknet_addDeployAccountTransaction")

    let invokeReq = account.sendTransactionRequest(.invokeV3(signedInvoke))
    #expect(invokeReq.method == "starknet_addInvokeTransaction")
  }
}
