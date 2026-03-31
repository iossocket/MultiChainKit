//
//  StarknetReceipt.swift
//  StarknetKit
//
//  Starknet transaction receipt from starknet_getTransactionReceipt (v0.7).
//

import Foundation
import MultiChainCore

// MARK: - StarknetReceipt

public struct StarknetReceipt: ChainReceipt, Sendable {

  // MARK: - Raw JSON fields

  public let type: String?  // "INVOKE", "DECLARE", "DEPLOY", "DEPLOY_ACCOUNT", "L1_HANDLER"
  public let transactionHashHex: String
  public let actualFee: StarknetFeePayment?
  public let executionStatus: String  // "SUCCEEDED" or "REVERTED"
  public let finalityStatus: String  // "ACCEPTED_ON_L2" or "ACCEPTED_ON_L1"
  public let revertReason: String?
  public let blockHash: String?  // nil if pending
  public let blockNumberValue: UInt64?  // nil if pending
  public let messagesSent: [StarknetMessageToL1]
  public let events: [StarknetReceiptEvent]
  public let executionResources: StarknetExecutionResources
  public let contractAddress: String?  // DEPLOY / DEPLOY_ACCOUNT only
  public let messageHash: String?  // L1_HANDLER only

  enum CodingKeys: String, CodingKey {
    case type
    case transactionHashHex = "transaction_hash"
    case actualFee = "actual_fee"
    case executionStatus = "execution_status"
    case finalityStatus = "finality_status"
    case revertReason = "revert_reason"
    case blockHash = "block_hash"
    case blockNumberValue = "block_number"
    case messagesSent = "messages_sent"
    case events
    case executionResources = "execution_resources"
    case contractAddress = "contract_address"
    case messageHash = "message_hash"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.type = try container.decodeIfPresent(String.self, forKey: .type)
    self.transactionHashHex = try container.decode(String.self, forKey: .transactionHashHex)
    self.actualFee = try container.decodeIfPresent(StarknetFeePayment.self, forKey: .actualFee)
    self.executionStatus = try container.decode(String.self, forKey: .executionStatus)
    self.finalityStatus = try container.decode(String.self, forKey: .finalityStatus)
    self.revertReason = try container.decodeIfPresent(String.self, forKey: .revertReason)
    self.blockHash = try container.decodeIfPresent(String.self, forKey: .blockHash)
    self.blockNumberValue = try container.decodeIfPresent(UInt64.self, forKey: .blockNumberValue)
    self.messagesSent = try container.decodeIfPresent([StarknetMessageToL1].self, forKey: .messagesSent) ?? []
    self.events = try container.decodeIfPresent([StarknetReceiptEvent].self, forKey: .events) ?? []
    self.executionResources =
      try container.decodeIfPresent(StarknetExecutionResources.self, forKey: .executionResources)
      ?? StarknetExecutionResources()
    self.contractAddress = try container.decodeIfPresent(String.self, forKey: .contractAddress)
    self.messageHash = try container.decodeIfPresent(String.self, forKey: .messageHash)
  }

  // MARK: - ChainReceipt

  public var transactionHash: Data {
    Felt(transactionHashHex)?.bigEndianData ?? Data()
  }

  public var isSuccess: Bool {
    executionStatus == "SUCCEEDED"
  }

  public var blockNumber: UInt64? {
    blockNumberValue
  }

  // MARK: - Convenience

  public var transactionHashFelt: Felt {
    Felt(transactionHashHex) ?? .zero
  }

  public var isPending: Bool {
    blockHash == nil
  }

  public var isReverted: Bool {
    executionStatus == "REVERTED"
  }

  public var isAcceptedOnL1: Bool {
    finalityStatus == "ACCEPTED_ON_L1"
  }
}

// MARK: - StarknetTransactionStatus

public struct StarknetTransactionStatus: Decodable, Sendable, Equatable {
  public let finalityStatus: String
  public let executionStatus: String?
  public let failureReason: String?

  enum CodingKeys: String, CodingKey {
    case finalityStatus = "finality_status"
    case executionStatus = "execution_status"
    case failureReason = "failure_reason"
  }

  public var isAccepted: Bool {
    finalityStatus == "ACCEPTED_ON_L2" || finalityStatus == "ACCEPTED_ON_L1"
  }

  public var isRejected: Bool {
    finalityStatus == "REJECTED"
  }

  public var isReverted: Bool {
    executionStatus == "REVERTED"
  }
}

// MARK: - FeePayment

public struct StarknetFeePayment: Codable, Sendable, Equatable {
  public let amount: String
  public let unit: String  // "WEI" (V1 txns) or "FRI" (V3 txns, STRK-denominated)

  public var amountFelt: Felt {
    Felt(amount) ?? .zero
  }
}

// MARK: - MessageToL1

public struct StarknetMessageToL1: Codable, Sendable, Equatable {
  public let fromAddress: String
  public let toAddress: String
  public let payload: [String]

  enum CodingKeys: String, CodingKey {
    case fromAddress = "from_address"
    case toAddress = "to_address"
    case payload
  }

  public var payloadFelts: [Felt] {
    payload.compactMap { Felt($0) }
  }
}

// MARK: - Receipt Event

public struct StarknetReceiptEvent: Codable, Sendable, Equatable {
  public let fromAddress: String
  public let keys: [String]
  public let data: [String]

  enum CodingKeys: String, CodingKey {
    case fromAddress = "from_address"
    case keys, data
  }

  public var feltKeys: [Felt] {
    keys.compactMap { Felt($0) }
  }

  public var feltData: [Felt] {
    data.compactMap { Felt($0) }
  }
}

// MARK: - Execution Resources

public struct StarknetExecutionResources: Codable, Sendable, Equatable {
  public let steps: UInt64?
  public let memoryHoles: UInt64?
  public let rangeCheckBuiltinApplications: UInt64?
  public let pedersenBuiltinApplications: UInt64?
  public let poseidonBuiltinApplications: UInt64?
  public let ecOpBuiltinApplications: UInt64?
  public let ecdsaBuiltinApplications: UInt64?
  public let bitwiseBuiltinApplications: UInt64?
  public let keccakBuiltinApplications: UInt64?
  public let segmentArenaBuiltin: UInt64?
  public let dataAvailability: StarknetDataAvailability?
  public let l1Gas: UInt64?
  public let l1DataGas: UInt64?
  public let l2Gas: UInt64?

  enum CodingKeys: String, CodingKey {
    case steps
    case memoryHoles = "memory_holes"
    case rangeCheckBuiltinApplications = "range_check_builtin_applications"
    case pedersenBuiltinApplications = "pedersen_builtin_applications"
    case poseidonBuiltinApplications = "poseidon_builtin_applications"
    case ecOpBuiltinApplications = "ec_op_builtin_applications"
    case ecdsaBuiltinApplications = "ecdsa_builtin_applications"
    case bitwiseBuiltinApplications = "bitwise_builtin_applications"
    case keccakBuiltinApplications = "keccak_builtin_applications"
    case segmentArenaBuiltin = "segment_arena_builtin"
    case dataAvailability = "data_availability"
    case l1Gas = "l1_gas"
    case l1DataGas = "l1_data_gas"
    case l2Gas = "l2_gas"
  }

  public init(
    steps: UInt64? = nil,
    memoryHoles: UInt64? = nil,
    rangeCheckBuiltinApplications: UInt64? = nil,
    pedersenBuiltinApplications: UInt64? = nil,
    poseidonBuiltinApplications: UInt64? = nil,
    ecOpBuiltinApplications: UInt64? = nil,
    ecdsaBuiltinApplications: UInt64? = nil,
    bitwiseBuiltinApplications: UInt64? = nil,
    keccakBuiltinApplications: UInt64? = nil,
    segmentArenaBuiltin: UInt64? = nil,
    dataAvailability: StarknetDataAvailability? = nil,
    l1Gas: UInt64? = nil,
    l1DataGas: UInt64? = nil,
    l2Gas: UInt64? = nil
  ) {
    self.steps = steps
    self.memoryHoles = memoryHoles
    self.rangeCheckBuiltinApplications = rangeCheckBuiltinApplications
    self.pedersenBuiltinApplications = pedersenBuiltinApplications
    self.poseidonBuiltinApplications = poseidonBuiltinApplications
    self.ecOpBuiltinApplications = ecOpBuiltinApplications
    self.ecdsaBuiltinApplications = ecdsaBuiltinApplications
    self.bitwiseBuiltinApplications = bitwiseBuiltinApplications
    self.keccakBuiltinApplications = keccakBuiltinApplications
    self.segmentArenaBuiltin = segmentArenaBuiltin
    self.dataAvailability = dataAvailability
    self.l1Gas = l1Gas
    self.l1DataGas = l1DataGas
    self.l2Gas = l2Gas
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.steps = try container.decodeIfPresent(UInt64.self, forKey: .steps)
    self.memoryHoles = try container.decodeIfPresent(UInt64.self, forKey: .memoryHoles)
    self.rangeCheckBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .rangeCheckBuiltinApplications)
    self.pedersenBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .pedersenBuiltinApplications)
    self.poseidonBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .poseidonBuiltinApplications)
    self.ecOpBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .ecOpBuiltinApplications)
    self.ecdsaBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .ecdsaBuiltinApplications)
    self.bitwiseBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .bitwiseBuiltinApplications)
    self.keccakBuiltinApplications = try container.decodeIfPresent(
      UInt64.self, forKey: .keccakBuiltinApplications)
    self.segmentArenaBuiltin = try container.decodeIfPresent(UInt64.self, forKey: .segmentArenaBuiltin)
    self.dataAvailability = try container.decodeIfPresent(
      StarknetDataAvailability.self, forKey: .dataAvailability)
    self.l1Gas = try container.decodeIfPresent(UInt64.self, forKey: .l1Gas)
    self.l1DataGas = try container.decodeIfPresent(UInt64.self, forKey: .l1DataGas)
    self.l2Gas = try container.decodeIfPresent(UInt64.self, forKey: .l2Gas)
  }
}

// MARK: - Data Availability

public struct StarknetDataAvailability: Codable, Sendable, Equatable {
  public let l1Gas: UInt64?
  public let l1DataGas: UInt64?

  enum CodingKeys: String, CodingKey {
    case l1Gas = "l1_gas"
    case l1DataGas = "l1_data_gas"
  }
}
