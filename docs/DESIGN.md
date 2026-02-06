# MultiChainKit Design

## Overview

Swift SDK for Ethereum and Starknet. One mnemonic, multiple chains, consistent API.

**Stack**: Swift 5.10+, iOS 14+/macOS 12+, async/await

**Not in scope (for now)**: hardware wallets, WebSocket subscriptions, full ABI encoding, ENS/Starknet ID, multisig

## Modules

```
MultiChainKit
├── MultiChainCore     → protocols, BIP39/32, errors
├── EthereumKit        → secp256k1, RLP, EIP-1559
├── StarknetKit        → STARK curve, Pedersen/Poseidon, account abstraction
└── MultiChainKit      → MultiChainWallet facade
```

Dependencies: BigInt, CryptoSwift, secp256k1.swift

## Core Protocols

### Chain

```swift
protocol Chain: Sendable, Identifiable {
    associatedtype Value: ChainValue      // Wei, Felt
    associatedtype Address: ChainAddress
    associatedtype Transaction: ChainTransaction
    associatedtype Signature: ChainSignature
    associatedtype Receipt: ChainReceipt

    var id: String { get }
    var name: String { get }
    var isTestnet: Bool { get }
}
```

Associated types let each chain define its own concrete types while keeping a unified interface.

### Account

```swift
protocol Account<C>: Sendable where C: Chain {
    var address: C.Address { get }
    func balanceRequest() -> ChainRequest<C, C.Value>
    func nonceRequest() -> ChainRequest<C, UInt64>
}

protocol SignableAccount<C>: Account<C> {
    var signer: S { get }
    func sign(transaction: inout C.Transaction) throws
    func signMessage(_ message: Data) throws -> C.Signature
}

protocol DeployableAccount<C>: SignableAccount<C> {
    var isDeployed: Bool { get async throws }
    func deployRequest() throws -> ChainRequest<C, C.Receipt>
}
```

Three levels:

- `Account` — read-only, for watch-only wallets
- `SignableAccount` — can sign
- `DeployableAccount` — for Starknet where accounts need deployment

### Signer

```swift
protocol Signer<C>: Sendable where C: Chain {
    var publicKey: Data { get }
    func sign(hash: Data) throws -> C.Signature
}
```

Separate from Account so you can swap implementations (hardware wallet, remote signer, mock for tests).

### Provider

```swift
struct ChainRequest<C: Chain, Result: Decodable>: Sendable {
    let method: String
    let params: [any Encodable & Sendable]
}

protocol Provider<C>: Sendable where C: Chain {
    var chain: C { get }
    func send<R: Decodable>(request: ChainRequest<C, R>) async throws -> R
    func send<R: Decodable>(requests: [ChainRequest<C, R>]) async throws -> [Result<R, ProviderError>]
}
```

Requests are value types — create them without executing, batch them, inspect them.

## Ethereum

### Types

| Type                  | What it is                                 |
| --------------------- | ------------------------------------------ |
| `Wei`                 | 256-bit value, converts to/from Gwei/Ether |
| `EthereumAddress`     | 20 bytes, EIP-55 checksum                  |
| `EthereumTransaction` | EIP-1559 tx                                |
| `EthereumSignature`   | r, s, v                                    |

### Crypto

- Curve: secp256k1
- Hash: Keccak-256
- Address: last 20 bytes of keccak256(pubkey)
- Encoding: RLP

### Transaction flow

```
1. Build tx (to, value, data, nonce, gas)
2. RLP encode → keccak256 → ECDSA sign
3. RLP encode signed tx → eth_sendRawTransaction
```

## Starknet

### Types

| Type                | What it is              |
| ------------------- | ----------------------- |
| `Felt`              | Field element, < 2^251  |
| `StarknetAddress`   | Contract address (felt) |
| `StarknetInvokeV3`  | Invoke transaction      |
| `StarknetSignature` | [r, s] felts            |

### Crypto

- Curve: STARK curve
- Hash: Pedersen (address), Poseidon (tx hash)
- Address: pedersen(prefix, deployer, salt, classHash, calldataHash)

### Account types

Starknet has native account abstraction — accounts are contracts.

```swift
enum StarknetAccountType {
    case openZeppelin(classHash: Felt)  // MVP
    case argent(classHash: Felt)        // later
    case braavos(classHash: Felt)       // later
    case custom(classHash: Felt, encoder: CalldataEncoder)
}
```

MVP supports OpenZeppelin (simplest). Others can be added via `CalldataEncoder` protocol.

### Key differences from Ethereum

|                      | Ethereum    | Starknet                     |
| -------------------- | ----------- | ---------------------------- |
| Account              | EOA         | Contract                     |
| Signature validation | Protocol    | Contract                     |
| Address              | From pubkey | From deploy params           |
| Tx types             | Legacy/1559 | Invoke/DeployAccount/Declare |
| Gas                  | Single      | L1 + L2                      |
| Value                | uint256     | felt252                      |

### Transaction flow

```
1. Check if account deployed, deploy if not
2. Build tx (encode calls, get nonce, estimate fee)
3. Poseidon hash → ECDSA sign on STARK curve
4. starknet_addInvokeTransaction
```

## Shared: BIP39/BIP32

```swift
// Mnemonic
BIP39.generateMnemonic(strength: 128) // 12 words
BIP39.seed(from: mnemonic, password: "")
BIP39.validate(mnemonic)

// Derivation
DerivationPath.ethereum  // m/44'/60'/0'/0/0
DerivationPath.starknet  // m/44'/9004'/0'/0/0
BIP32.derive(seed: seed, path: path)
```

## Usage

### Direct (recommended for production)

```swift
// Ethereum
let account = try EthereumAccount(mnemonic: mnemonic)
let provider = EthereumProvider(chain: .sepolia)
let balance = try await provider.getBalance(account.address)

// Starknet
let account = try StarknetAccount(mnemonic: mnemonic)
let provider = StarknetProvider(chain: .sepolia)
if try await !account.isDeployed {
    try await account.deploy()
}
```

### Convenience (for simple apps)

```swift
let wallet = try MultiChainWallet(mnemonic: mnemonic)
wallet.ethereum.connect(provider: EthereumProvider(chain: .sepolia))
wallet.starknet.connect(provider: StarknetProvider(chain: .sepolia))
```

## Security

- Private keys in memory only, never persisted
- Signing happens locally
- HTTPS required for RPC
- Apps should use Keychain for mnemonic storage

## Testing

Standard test vectors:

- BIP39: trezor/python-mnemonic
- BIP32: bitcoin/bips
- Ethereum: ethereum/tests
- Starknet: starkware-libs/starknet-specs

## References

**Ethereum**: EIP-155, EIP-1559, EIP-2718, BIP-32/39/44

**Starknet**: [docs.starknet.io](https://docs.starknet.io) — transactions, STARK curve, Pedersen hash, account abstraction

**Libraries**: web3swift, starknet.swift, BigInt, CryptoSwift, secp256k1.swift
