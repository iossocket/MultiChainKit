//
//  StarknetContract.swift
//  StarknetKit
//
//  High-level contract interaction API for Starknet.
//  Accepts a JSON ABI, looks up functions/events by name,
//  encodes calls, decodes results, and decodes events.
//

import BigInt
import Foundation
import MultiChainCore

// MARK: - StarknetContract

public struct StarknetContract: Sendable {
  public let address: Felt
  public let abi: [StarknetABIItem]
  public let provider: StarknetProvider

  // Pre-indexed lookups built at init
  public let functions: [String: StarknetABIFunction]
  public let events: [String: StarknetABIEvent]
  public let structs: [String: StarknetABIStruct]
  public let enums: [String: StarknetABIEnum]

  // MARK: - Init

  public init(address: Felt, abi: [StarknetABIItem], provider: StarknetProvider) {
    self.address = address
    self.abi = abi
    self.provider = provider

    var fns: [String: StarknetABIFunction] = [:]
    var evts: [String: StarknetABIEvent] = [:]
    var strs: [String: StarknetABIStruct] = [:]
    var ens: [String: StarknetABIEnum] = [:]

    for item in abi {
      switch item {
      case .function(let f):
        fns[f.name] = f
      case .event(let e):
        evts[Self.shortName(e.name)] = e
      case .structDef(let s):
        strs[s.name] = s
      case .enumDef(let e):
        ens[e.name] = e
      case .interface(let iface):
        for sub in iface.items {
          if case .function(let f) = sub {
            fns[f.name] = f
          }
        }
      case .constructor, .l1Handler, .impl:
        break
      }
    }

    self.functions = fns
    self.events = evts
    self.structs = strs
    self.enums = ens
  }

  /// Initialize from a JSON ABI string.
  public init(address: Felt, abiJson: String, provider: StarknetProvider) throws {
    guard let data = abiJson.data(using: .utf8) else {
      throw StarknetContractError.invalidABI("Invalid UTF-8 string")
    }
    let items = try JSONDecoder().decode([StarknetABIItem].self, from: data)
    self.init(address: address, abi: items, provider: provider)
  }

  // MARK: - Encode Call

  /// Build a StarknetCall from function name and CairoValue arguments.
  public func encodeCall(function name: String, args: [CairoValue] = []) throws -> StarknetCall {
    guard let fn = functions[name] else {
      throw StarknetContractError.functionNotFound(name)
    }
    guard args.count == fn.inputs.count else {
      throw StarknetContractError.argumentCountMismatch(expected: fn.inputs.count, got: args.count)
    }
    let calldata = CairoValue.encodeCalldata(args)
    let selector = StarknetKeccak.functionSelector(name)
    return StarknetCall(contractAddress: address, entryPointSelector: selector, calldata: calldata)
  }

  // MARK: - Read (starknet_call)

  /// Execute a read-only call and return raw Felt results.
  public func callRaw(
    function name: String,
    args: [CairoValue] = [],
    block: StarknetBlockId = .latest
  ) async throws -> [Felt] {
    let call = try encodeCall(function: name, args: args)
    let request = provider.callRequest(call: call, block: block)
    return try await provider.send(request: request)
  }

  /// Execute a read-only call and decode results using the ABI output types.
  public func call(
    function name: String,
    args: [CairoValue] = [],
    block: StarknetBlockId = .latest
  ) async throws -> [CairoValue] {
    guard let fn = functions[name] else {
      throw StarknetContractError.functionNotFound(name)
    }
    guard !fn.outputs.isEmpty else {
      throw StarknetContractError.noOutputTypes(name)
    }
    let raw = try await callRaw(function: name, args: args, block: block)
    var results: [CairoValue] = []
    var offset = 0
    for output in fn.outputs {
      let cairoType = try CairoType.parse(output.type, structs: structs, enums: enums)
      let (value, consumed) = try CairoValue.decode(type: cairoType, from: raw, at: offset)
      results.append(value)
      offset += consumed
    }
    return results
  }

  // MARK: - Fee Estimation

  /// Estimate the fee for invoking a function on this contract.
  /// Requires an account to build and sign the invoke transaction.
  public func estimateFee(
    function name: String,
    args: [CairoValue] = [],
    account: StarknetAccount,
    nonce: Felt
  ) async throws -> StarknetFeeEstimate {
    let call = try encodeCall(function: name, args: args)
    return try await account.estimateFee(calls: [call], nonce: nonce)
  }

  // MARK: - Event Fetching

  /// Fetch and decode events emitted by this contract.
  public func getEvents(
    eventName: String,
    fromBlock: StarknetBlockId = .latest,
    toBlock: StarknetBlockId = .latest,
    extraKeys: [[Felt]]? = nil,
    chunkSize: Int = 100,
    continuationToken: String? = nil
  ) async throws -> (events: [StarknetDecodedEvent], continuationToken: String?) {
    guard let event = events[eventName] else {
      throw StarknetContractError.eventNotFound(eventName)
    }
    guard event.kind == "struct", event.members != nil else {
      throw StarknetContractError.unsupportedEventKind(event.kind)
    }

    let selector = StarknetKeccak.hash(Data(eventName.utf8))
    var keysFilter: [[Felt]] = [[selector]]
    if let extra = extraKeys {
      keysFilter.append(contentsOf: extra)
    }

    let filter = StarknetEventFilter(
      fromBlock: fromBlock,
      toBlock: toBlock,
      address: address,
      keys: keysFilter,
      chunkSize: chunkSize,
      continuationToken: continuationToken
    )

    let response: StarknetEventsResponse = try await provider.send(
      request: provider.getEventsRequest(filter: filter)
    )

    let decoded = try response.events.map { raw in
      try decodeEvent(name: eventName, keys: raw.feltKeys, data: raw.feltData)
    }

    return (events: decoded, continuationToken: response.continuationToken)
  }

  // MARK: - Event Decoding

  /// Decode a single event from keys and data arrays.
  /// keys[0] is the event selector (skipped), remaining keys are "key" members.
  public func decodeEvent(
    name: String,
    keys: [Felt],
    data: [Felt]
  ) throws -> StarknetDecodedEvent {
    guard let event = events[name] else {
      throw StarknetContractError.eventNotFound(name)
    }
    guard event.kind == "struct", let members = event.members else {
      throw StarknetContractError.unsupportedEventKind(event.kind)
    }

    var decodedKeys: [String: CairoValue] = [:]
    var decodedData: [String: CairoValue] = [:]
    var keyOffset = 1  // skip selector at keys[0]
    var dataOffset = 0

    for member in members {
      let cairoType = try CairoType.parse(member.type, structs: structs, enums: enums)
      if member.kind == "key" {
        let (value, consumed) = try CairoValue.decode(type: cairoType, from: keys, at: keyOffset)
        decodedKeys[member.name] = value
        keyOffset += consumed
      } else {
        let (value, consumed) = try CairoValue.decode(type: cairoType, from: data, at: dataOffset)
        decodedData[member.name] = value
        dataOffset += consumed
      }
    }

    return StarknetDecodedEvent(name: name, keys: decodedKeys, data: decodedData)
  }

  // MARK: - Invoke (Write)

  /// Encode a call, auto-fill nonce + fees, sign, and broadcast. Returns the invoke response.
  public func invoke(
    function name: String,
    args: [CairoValue] = [],
    account: StarknetAccount,
    feeMultiplier: Double = 1.5
  ) async throws -> StarknetInvokeTransactionResponse {
    let call = try encodeCall(function: name, args: args)
    return try await account.executeV3(calls: [call], feeMultiplier: feeMultiplier)
  }

  // MARK: - Private

  /// Extract short name from fully-qualified Cairo name.
  /// e.g. "openzeppelin_token::erc20::ERC20Component::Transfer" → "Transfer"
  private static func shortName(_ fullName: String) -> String {
    if let last = fullName.split(separator: ":").last {
      return String(last)
    }
    return fullName
  }
}

// MARK: - StarknetContractError

public enum StarknetContractError: Error, Sendable, Equatable {
  case invalidABI(String)
  case functionNotFound(String)
  case eventNotFound(String)
  case argumentCountMismatch(expected: Int, got: Int)
  case noOutputTypes(String)
  case unsupportedEventKind(String)
}

// MARK: - Event Types

/// Raw event as emitted by a Starknet contract.
public struct StarknetEmittedEvent: Codable, Sendable, Equatable {
  public let fromAddress: Felt
  public let keys: [Felt]
  public let data: [Felt]

  public init(fromAddress: Felt, keys: [Felt], data: [Felt]) {
    self.fromAddress = fromAddress
    self.keys = keys
    self.data = data
  }

  enum CodingKeys: String, CodingKey {
    case fromAddress = "from_address"
    case keys, data
  }
}

/// A decoded Starknet event with named key and data fields.
public struct StarknetDecodedEvent: Sendable, Equatable {
  public let name: String
  public let keys: [String: CairoValue]
  public let data: [String: CairoValue]

  public init(name: String, keys: [String: CairoValue], data: [String: CairoValue]) {
    self.name = name
    self.keys = keys
    self.data = data
  }
}
