//
//  StarknetContractTests.swift
//  StarknetKitTests
//
//  Tests for StarknetContract ABI-based API.
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

// MARK: - Test ABI Fixtures

private let erc20ABI = """
  [
    {"type":"function","name":"transfer","inputs":[{"name":"recipient","type":"core::starknet::contract_address::ContractAddress"},{"name":"amount","type":"core::integer::u256"}],"outputs":[{"type":"core::bool"}],"state_mutability":"external"},
    {"type":"function","name":"balance_of","inputs":[{"name":"account","type":"core::starknet::contract_address::ContractAddress"}],"outputs":[{"type":"core::integer::u256"}],"state_mutability":"view"},
    {"type":"function","name":"total_supply","inputs":[],"outputs":[{"type":"core::integer::u256"}],"state_mutability":"view"},
    {"type":"function","name":"approve","inputs":[{"name":"spender","type":"core::starknet::contract_address::ContractAddress"},{"name":"amount","type":"core::integer::u256"}],"outputs":[{"type":"core::bool"}],"state_mutability":"external"},
    {"type":"struct","name":"core::integer::u256","members":[{"name":"low","type":"core::integer::u128"},{"name":"high","type":"core::integer::u128"}]},
    {"type":"event","name":"openzeppelin::erc20::Transfer","kind":"struct","members":[{"name":"from","type":"core::starknet::contract_address::ContractAddress","kind":"key"},{"name":"to","type":"core::starknet::contract_address::ContractAddress","kind":"key"},{"name":"value","type":"core::integer::u256","kind":"data"}]},
    {"type":"event","name":"openzeppelin::erc20::Approval","kind":"struct","members":[{"name":"owner","type":"core::starknet::contract_address::ContractAddress","kind":"key"},{"name":"spender","type":"core::starknet::contract_address::ContractAddress","kind":"key"},{"name":"value","type":"core::integer::u256","kind":"data"}]}
  ]
  """

private let interfaceABI = """
  [
    {"type":"interface","name":"IERC20","items":[
      {"type":"function","name":"name","inputs":[],"outputs":[{"type":"core::byte_array::ByteArray"}],"state_mutability":"view"},
      {"type":"function","name":"symbol","inputs":[],"outputs":[{"type":"core::byte_array::ByteArray"}],"state_mutability":"view"}
    ]},
    {"type":"impl","name":"ERC20Impl","interface_name":"IERC20"}
  ]
  """

// MARK: - CairoType.parse

@Suite("CairoType.parse")
struct CairoTypeParseTests {

  @Test("parse builtin felt252")
  func felt252() throws {
    #expect(try CairoType.parse("core::felt252") == .felt252)
    #expect(try CairoType.parse("felt252") == .felt252)
  }

  @Test("parse builtin bool")
  func bool() throws {
    #expect(try CairoType.parse("core::bool") == .bool)
  }

  @Test("parse builtin integers")
  func integers() throws {
    #expect(try CairoType.parse("core::integer::u8") == .u8)
    #expect(try CairoType.parse("core::integer::u16") == .u16)
    #expect(try CairoType.parse("core::integer::u32") == .u32)
    #expect(try CairoType.parse("core::integer::u64") == .u64)
    #expect(try CairoType.parse("core::integer::u128") == .u128)
    #expect(try CairoType.parse("core::integer::u256") == .u256)
  }

  @Test("parse ContractAddress")
  func contractAddress() throws {
    #expect(
      try CairoType.parse("core::starknet::contract_address::ContractAddress") == .contractAddress)
  }

  @Test("parse ByteArray")
  func byteArray() throws {
    #expect(try CairoType.parse("core::byte_array::ByteArray") == .byteArray)
  }

  @Test("parse Array<felt252>")
  func arrayFelt() throws {
    #expect(try CairoType.parse("core::array::Array::<core::felt252>") == .array(.felt252))
  }

  @Test("parse Span<u256>")
  func spanU256() throws {
    #expect(try CairoType.parse("core::array::Span::<core::integer::u256>") == .array(.u256))
  }

  @Test("parse Option<u128>")
  func optionU128() throws {
    #expect(try CairoType.parse("core::option::Option::<core::integer::u128>") == .option(.u128))
  }

  @Test("parse unit type ()")
  func unitType() throws {
    #expect(try CairoType.parse("()") == .tuple([]))
  }

  @Test("parse tuple (felt252, u256)")
  func tuple() throws {
    let result = try CairoType.parse("(core::felt252, core::integer::u256)")
    #expect(result == .tuple([.felt252, .u256]))
  }

  @Test("parse nested generic Array<Option<felt252>>")
  func nestedGeneric() throws {
    let result = try CairoType.parse("core::array::Array::<core::option::Option::<core::felt252>>")
    #expect(result == .array(.option(.felt252)))
  }

  @Test("parse struct from registry")
  func structLookup() throws {
    let structs: [String: StarknetABIStruct] = [
      "my::Point": StarknetABIStruct(
        name: "my::Point",
        members: [
          StarknetABIStructMember(name: "x", type: "core::felt252"),
          StarknetABIStructMember(name: "y", type: "core::felt252"),
        ])
    ]
    #expect(try CairoType.parse("my::Point", structs: structs) == .tuple([.felt252, .felt252]))
  }

  @Test("parse enum from registry")
  func enumLookup() throws {
    let enums: [String: StarknetABIEnum] = [
      "my::Status": StarknetABIEnum(
        name: "my::Status",
        variants: [
          StarknetABIEnumVariant(name: "Active", type: "()"),
          StarknetABIEnumVariant(name: "Paused", type: "()"),
        ])
    ]
    #expect(try CairoType.parse("my::Status", enums: enums) == .enum([.tuple([]), .tuple([])]))
  }

  @Test("parse unknown type throws")
  func unknownThrows() {
    #expect(throws: CairoABIError.self) {
      try CairoType.parse("some::unknown::Type")
    }
  }
}

// MARK: - StarknetABIItem Codable

@Suite("StarknetABIItem Codable")
struct StarknetABIItemCodableTests {

  @Test("decode function item")
  func decodeFunction() throws {
    let json = """
      {"type":"function","name":"transfer","inputs":[{"name":"recipient","type":"core::starknet::contract_address::ContractAddress"}],"outputs":[{"type":"core::bool"}],"state_mutability":"external"}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .function(let f) = item else {
      Issue.record("Expected function")
      return
    }
    #expect(f.name == "transfer")
    #expect(f.inputs.count == 1)
    #expect(f.inputs[0].name == "recipient")
    #expect(f.outputs.count == 1)
    #expect(f.stateMutability == "external")
  }

  @Test("decode constructor item")
  func decodeConstructor() throws {
    let json = """
      {"type":"constructor","name":"constructor","inputs":[{"name":"owner","type":"core::starknet::contract_address::ContractAddress"}]}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .constructor(let c) = item else {
      Issue.record("Expected constructor")
      return
    }
    #expect(c.name == "constructor")
    #expect(c.inputs.count == 1)
  }

  @Test("decode event item")
  func decodeEvent() throws {
    let json = """
      {"type":"event","name":"Transfer","kind":"struct","members":[{"name":"from","type":"core::starknet::contract_address::ContractAddress","kind":"key"},{"name":"to","type":"core::starknet::contract_address::ContractAddress","kind":"key"},{"name":"value","type":"core::integer::u256","kind":"data"}]}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .event(let e) = item else {
      Issue.record("Expected event")
      return
    }
    #expect(e.name == "Transfer")
    #expect(e.kind == "struct")
    #expect(e.members?.count == 3)
    #expect(e.members?[0].kind == "key")
    #expect(e.members?[2].kind == "data")
  }

  @Test("decode struct item")
  func decodeStruct() throws {
    let json = """
      {"type":"struct","name":"core::integer::u256","members":[{"name":"low","type":"core::integer::u128"},{"name":"high","type":"core::integer::u128"}]}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .structDef(let s) = item else {
      Issue.record("Expected struct")
      return
    }
    #expect(s.name == "core::integer::u256")
    #expect(s.members.count == 2)
  }

  @Test("decode enum item")
  func decodeEnum() throws {
    let json = """
      {"type":"enum","name":"core::bool","variants":[{"name":"False","type":"()"},{"name":"True","type":"()"}]}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .enumDef(let e) = item else {
      Issue.record("Expected enum")
      return
    }
    #expect(e.name == "core::bool")
    #expect(e.variants.count == 2)
  }

  @Test("decode interface item with nested functions")
  func decodeInterface() throws {
    let json = """
      {"type":"interface","name":"IERC20","items":[{"type":"function","name":"name","inputs":[],"outputs":[{"type":"core::byte_array::ByteArray"}],"state_mutability":"view"}]}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .interface(let iface) = item else {
      Issue.record("Expected interface")
      return
    }
    #expect(iface.name == "IERC20")
    #expect(iface.items.count == 1)
    if case .function(let f) = iface.items[0] {
      #expect(f.name == "name")
    } else {
      Issue.record("Expected function inside interface")
    }
  }

  @Test("decode impl item")
  func decodeImpl() throws {
    let json = """
      {"type":"impl","name":"ERC20Impl","interface_name":"IERC20"}
      """
    let item = try JSONDecoder().decode(StarknetABIItem.self, from: json.data(using: .utf8)!)
    guard case .impl(let i) = item else {
      Issue.record("Expected impl")
      return
    }
    #expect(i.name == "ERC20Impl")
    #expect(i.interfaceName == "IERC20")
  }

  @Test("decode full ERC20 ABI array")
  func decodeFullABI() throws {
    let items = try JSONDecoder().decode([StarknetABIItem].self, from: erc20ABI.data(using: .utf8)!)
    #expect(items.count == 7)
  }
}

// MARK: - StarknetContract Init

@Suite("StarknetContract init")
struct StarknetContractInitTests {

  static let provider = StarknetProvider(chain: .devnet)

  @Test("init from JSON ABI string")
  func initFromJson() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)
    #expect(contract.address == Felt(0xABC))
    #expect(!contract.functions.isEmpty)
    #expect(!contract.events.isEmpty)
    #expect(!contract.structs.isEmpty)
  }

  @Test("functions indexed by name")
  func functionsIndexed() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    #expect(contract.functions["transfer"] != nil)
    #expect(contract.functions["balance_of"] != nil)
    #expect(contract.functions["total_supply"] != nil)
    #expect(contract.functions["approve"] != nil)
  }

  @Test("events indexed by short name")
  func eventsIndexed() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    #expect(contract.events["Transfer"] != nil)
    #expect(contract.events["Approval"] != nil)
  }

  @Test("structs indexed by full name")
  func structsIndexed() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    #expect(contract.structs["core::integer::u256"] != nil)
  }

  @Test("interface functions flattened into functions dict")
  func interfaceFlattened() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: interfaceABI, provider: Self.provider)
    #expect(contract.functions["name"] != nil)
    #expect(contract.functions["symbol"] != nil)
  }
}

// MARK: - StarknetContract encodeCall

@Suite("StarknetContract encodeCall")
struct StarknetContractEncodeCallTests {

  static let provider = StarknetProvider(chain: .devnet)

  @Test("encodeCall with no args")
  func noArgs() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)
    let call = try contract.encodeCall(function: "total_supply")
    #expect(call.contractAddress == Felt(0xABC))
    #expect(call.entryPointSelector == StarknetKeccak.functionSelector("total_supply"))
    #expect(call.calldata.isEmpty)
  }

  @Test("encodeCall transfer: recipient + u256")
  func transferCalldata() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)
    let recipient = Felt(0xBEEF)
    let call = try contract.encodeCall(
      function: "transfer",
      args: [.contractAddress(recipient), .u256(BigUInt(500))]
    )
    #expect(call.contractAddress == Felt(0xABC))
    #expect(call.entryPointSelector == StarknetKeccak.functionSelector("transfer"))
    #expect(call.calldata.count == 3)
    #expect(call.calldata[0] == recipient)
    #expect(call.calldata[1] == Felt(500))
    #expect(call.calldata[2] == .zero)
  }

  @Test("encodeCall balance_of: single address arg")
  func balanceOf() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    let account = Felt(0xDEAD)
    let call = try contract.encodeCall(function: "balance_of", args: [.contractAddress(account)])
    #expect(call.calldata == [account])
  }

  @Test("encodeCall function not found throws")
  func functionNotFound() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    #expect(throws: StarknetContractError.self) {
      _ = try contract.encodeCall(function: "nonexistent")
    }
  }

  @Test("encodeCall argument count mismatch throws")
  func argCountMismatch() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    #expect(throws: StarknetContractError.self) {
      _ = try contract.encodeCall(function: "transfer", args: [.contractAddress(Felt(0x1))])
    }
  }

  @Test("encodeCall result usable with provider.callRequest")
  func callRequestCompatibility() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)
    let call = try contract.encodeCall(
      function: "balance_of", args: [.contractAddress(Felt(0xFACE))])
    let request = Self.provider.callRequest(call: call)
    #expect(request.method == "starknet_call")
  }

  @Test("multiple encodeCall results usable for multicall")
  func multicallCompatibility() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)
    let t1 = try contract.encodeCall(
      function: "transfer", args: [.contractAddress(Felt(0xA)), .u256(BigUInt(100))])
    let t2 = try contract.encodeCall(
      function: "transfer", args: [.contractAddress(Felt(0xB)), .u256(BigUInt(200))])
    let multicall = StarknetCall.encodeMulticall([t1, t2])
    #expect(!multicall.isEmpty)
  }
}

// MARK: - StarknetContract decodeEvent

@Suite("StarknetContract decodeEvent")
struct StarknetContractDecodeEventTests {

  static let provider = StarknetProvider(chain: .devnet)

  @Test("decode Transfer event")
  func decodeTransfer() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)

    let selector = StarknetKeccak.hash(Data("Transfer".utf8))
    let from = Felt(0xAAA)
    let to = Felt(0xBBB)
    let keys: [Felt] = [selector, from, to]
    let data: [Felt] = [Felt(1000), .zero]  // u256 low=1000, high=0

    let decoded = try contract.decodeEvent(name: "Transfer", keys: keys, data: data)
    #expect(decoded.name == "Transfer")
    #expect(decoded.keys["from"] == .contractAddress(from))
    #expect(decoded.keys["to"] == .contractAddress(to))
    #expect(decoded.data["value"]?.u256Value == BigUInt(1000))
  }

  @Test("decode Approval event")
  func decodeApproval() throws {
    let contract = try StarknetContract(
      address: Felt(0xABC), abiJson: erc20ABI, provider: Self.provider)

    let selector = StarknetKeccak.hash(Data("Approval".utf8))
    let owner = Felt(0x111)
    let spender = Felt(0x222)
    let keys: [Felt] = [selector, owner, spender]
    let amount = (BigUInt(1) << 128) + BigUInt(42)
    let data: [Felt] = [Felt(42), Felt(1)]  // u256 low=42, high=1

    let decoded = try contract.decodeEvent(name: "Approval", keys: keys, data: data)
    #expect(decoded.keys["owner"] == .contractAddress(owner))
    #expect(decoded.keys["spender"] == .contractAddress(spender))
    #expect(decoded.data["value"]?.u256Value == amount)
  }

  @Test("decode event not found throws")
  func eventNotFound() throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    #expect(throws: StarknetContractError.self) {
      _ = try contract.decodeEvent(name: "NonExistent", keys: [.zero], data: [])
    }
  }
}

// MARK: - StarknetContractError

@Suite("StarknetContractError")
struct StarknetContractErrorTests {

  @Test("error cases are equatable")
  func equatable() {
    #expect(StarknetContractError.functionNotFound("foo") == .functionNotFound("foo"))
    #expect(StarknetContractError.eventNotFound("bar") == .eventNotFound("bar"))
    #expect(
      StarknetContractError.argumentCountMismatch(expected: 2, got: 1)
        == .argumentCountMismatch(expected: 2, got: 1))
    #expect(StarknetContractError.invalidABI("bad") == .invalidABI("bad"))
  }
}

// MARK: - StarknetDecodedEvent

@Suite("StarknetDecodedEvent")
struct StarknetDecodedEventTests {

  @Test("equatable")
  func equatable() {
    let a = StarknetDecodedEvent(
      name: "Transfer", keys: ["from": .contractAddress(Felt(1))], data: [:])
    let b = StarknetDecodedEvent(
      name: "Transfer", keys: ["from": .contractAddress(Felt(1))], data: [:])
    #expect(a == b)
  }
}

// MARK: - StarknetFeeEstimate

@Suite("StarknetFeeEstimate")
struct StarknetFeeEstimateTests {

  @Test("decode from JSON")
  func decodeFromJson() throws {
    let json = """
      {"gas_consumed":"0x1a4","gas_price":"0x3b9aca00","data_gas_consumed":"0x0","data_gas_price":"0x1","overall_fee":"0x61c46800","fee_unit":"WEI"}
      """
    let estimate = try JSONDecoder().decode(
      StarknetFeeEstimate.self, from: json.data(using: .utf8)!)
    #expect(estimate.gasConsumed == "0x1a4")
    #expect(estimate.gasPrice == "0x3b9aca00")
    #expect(estimate.dataGasConsumed == "0x0")
    #expect(estimate.overallFee == "0x61c46800")
    #expect(estimate.feeUnit == "WEI")
  }

  @Test("overallFeeFelt parses hex")
  func overallFeeFelt() throws {
    let json = """
      {"gas_consumed":"0x1","gas_price":"0x1","data_gas_consumed":"0x0","data_gas_price":"0x1","overall_fee":"0xff","fee_unit":"WEI"}
      """
    let estimate = try JSONDecoder().decode(
      StarknetFeeEstimate.self, from: json.data(using: .utf8)!)
    #expect(estimate.overallFeeFelt == Felt(255))
  }

  @Test("equatable")
  func equatable() throws {
    let json = """
      {"gas_consumed":"0x1","gas_price":"0x2","data_gas_consumed":"0x0","data_gas_price":"0x1","overall_fee":"0x3","fee_unit":"WEI"}
      """
    let a = try JSONDecoder().decode(StarknetFeeEstimate.self, from: json.data(using: .utf8)!)
    let b = try JSONDecoder().decode(StarknetFeeEstimate.self, from: json.data(using: .utf8)!)
    #expect(a == b)
  }
}

// MARK: - StarknetEventFilter

@Suite("StarknetEventFilter")
struct StarknetEventFilterTests {

  @Test("encodes to JSON with correct keys")
  func encodesToJson() throws {
    let filter = StarknetEventFilter(
      fromBlock: .number(100),
      toBlock: .latest,
      address: Felt(0xABC),
      keys: [[Felt(0x1), Felt(0x2)]],
      chunkSize: 50
    )
    let data = try JSONEncoder().encode(filter)
    let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(dict["chunk_size"] as? Int == 50)
    #expect(dict["address"] as? String == Felt(0xABC).hexString)
    #expect(dict["continuation_token"] == nil)
  }

  @Test("nil address and keys omitted")
  func nilFieldsOmitted() throws {
    let filter = StarknetEventFilter(fromBlock: .latest, toBlock: .latest)
    let data = try JSONEncoder().encode(filter)
    let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(dict["address"] is NSNull || dict["address"] == nil)
    #expect(dict["keys"] is NSNull || dict["keys"] == nil)
  }
}

// MARK: - StarknetEventsResponse

@Suite("StarknetEventsResponse")
struct StarknetEventsResponseTests {

  @Test("decode response with events")
  func decodeWithEvents() throws {
    let json = """
      {"events":[{"from_address":"0xabc","keys":["0x1","0x2"],"data":["0x3"],"block_hash":"0xdef","block_number":42,"transaction_hash":"0x999"}],"continuation_token":"token123"}
      """
    let response = try JSONDecoder().decode(
      StarknetEventsResponse.self, from: json.data(using: .utf8)!)
    #expect(response.events.count == 1)
    #expect(response.continuationToken == "token123")
    #expect(response.events[0].fromAddress == "0xabc")
    #expect(response.events[0].blockNumber == 42)
    #expect(response.events[0].transactionHash == "0x999")
  }

  @Test("decode response without continuation token")
  func decodeNoContinuation() throws {
    let json = """
      {"events":[]}
      """
    let response = try JSONDecoder().decode(
      StarknetEventsResponse.self, from: json.data(using: .utf8)!)
    #expect(response.events.isEmpty)
    #expect(response.continuationToken == nil)
  }

  @Test("feltKeys and feltData convert hex strings")
  func feltConversion() throws {
    let json = """
      {"from_address":"0x1","keys":["0xa","0xb"],"data":["0xc","0xd"],"block_hash":"0x0","block_number":0,"transaction_hash":"0x0"}
      """
    let event = try JSONDecoder().decode(
      StarknetEmittedEventWithContext.self, from: json.data(using: .utf8)!)
    #expect(event.feltKeys == [Felt(0xa), Felt(0xb)])
    #expect(event.feltData == [Felt(0xc), Felt(0xd)])
  }
}

// MARK: - StarknetContract getEvents validation

@Suite("StarknetContract getEvents validation")
struct StarknetContractGetEventsValidationTests {

  static let provider = StarknetProvider(chain: .devnet)

  @Test("getEvents throws eventNotFound for unknown event")
  func eventNotFound() async throws {
    let contract = try StarknetContract(
      address: Felt(0x1), abiJson: erc20ABI, provider: Self.provider)
    do {
      _ = try await contract.getEvents(eventName: "NonExistent")
      Issue.record("Expected eventNotFound error")
    } catch let error as StarknetContractError {
      #expect(error == .eventNotFound("NonExistent"))
    }
  }
}
