//
//  StarknetAccountType.swift
//  StarknetKit
//
//  Account type abstraction for deploying new Starknet account contracts.
//  For controlling already-deployed accounts, use StarknetAccount directly with private key + address.
//

import BigInt
import Foundation

// MARK: - Account Type Protocol

/// Defines the contract-level details needed to deploy a new account.
/// Each account type has its own class hash, constructor format, and address derivation.
public protocol StarknetAccountType: Sendable {
  /// The class hash of the account contract.
  var classHash: Felt { get }

  /// Build constructor calldata from a public key.
  func constructorCalldata(publicKey: Felt) -> [Felt]

  /// Compute the account contract address for a given public key and salt.
  func computeAddress(publicKey: Felt, salt: Felt) throws -> StarknetAddress
}

// MARK: - Default address computation

extension StarknetAccountType {
  /// address = pedersen("STARKNET_CONTRACT_ADDRESS", 0, salt, classHash, pedersen(calldata)) mod 2^251
  public func computeAddress(publicKey: Felt, salt: Felt) throws -> StarknetAddress {
    let calldata = constructorCalldata(publicKey: publicKey)
    let felt = try StarknetContractAddress.calculate(
      classHash: classHash,
      calldata: calldata,
      salt: salt,
      deployerAddress: .zero
    )
    return StarknetAddress(felt.bigEndianData)
  }
}

// MARK: - OpenZeppelin

/// OpenZeppelin account contract. Constructor: [public_key]
public struct OpenZeppelinAccount: StarknetAccountType {
  public let classHash: Felt

  /// Standard OZ account class hash (Cairo 1, v0.17.0).
  public static let defaultClassHash = Felt("0x061dac032f228abef9c6626f995015233097ae253a7f72d68552db02f2971b8f")!

  public init(classHash: Felt = OpenZeppelinAccount.defaultClassHash) {
    self.classHash = classHash
  }

  public func constructorCalldata(publicKey: Felt) -> [Felt] {
    [publicKey]
  }
}
