# MultiChainKit

[![Tests](https://github.com/iossocket/MultiChainKit/actions/workflows/test.yml/badge.svg)](https://github.com/iossocket/MultiChainKit/actions/workflows/test.yml)

Swift SDK for Ethereum and Starknet. One mnemonic, multiple chains.

## Why?

Most Swift blockchain SDKs focus on a single chain. If you're building a wallet or dApp that needs to support multiple chains, you end up juggling different libraries with inconsistent APIs. MultiChainKit provides a unified interface so you can work with Ethereum and Starknet using the same patterns.

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/iossocket/MultiChainKit.git", from: "0.1.0")
]

// Pick what you need
.target(name: "YourApp", dependencies: ["MultiChainKit"])   // everything
.target(name: "YourApp", dependencies: ["EthereumKit"])     // Ethereum only
.target(name: "YourApp", dependencies: ["StarknetKit"])     // Starknet only
.target(name: "YourApp", dependencies: ["MultiChainCore"])  // core only (BIP39/BIP32, etc.)
```

Requires iOS 14+ / macOS 12+, Swift 5.10+.

## Quick Start: MultiChainWallet

Derive Ethereum and Starknet accounts from a single mnemonic:

```swift
import MultiChainKit

// One mnemonic -> both chains
var wallet = try MultiChainWallet(mnemonic: "abandon abandon ...")

print(wallet.ethereum.address.checksummed)  // 0x9858...
print(wallet.starknet.address.checksummed)  // 0x0412...

// Attach providers when ready
try wallet.connectEthereum(provider: EthereumProvider(chain: .sepolia))
wallet.connectStarknet(provider: StarknetProvider(chain: .sepolia))
```

## Ethereum

### Account & Balance

```swift
import EthereumKit

let signable = try EthereumSignableAccount(mnemonic: "abandon abandon ...", path: .ethereum)
let provider = EthereumProvider(chain: .sepolia)
let balanceHex: String = try await provider.send(request: signable.balanceRequest())
let wei = Wei(balanceHex) ?? .zero
print("Balance: \(wei.toEtherDecimal()) ETH")
```

### Transfer (EIP-1559)

```swift
let provider = EthereumProvider(chain: .sepolia)
let signable = try EthereumSignableAccount(privateKey: privateKeyData)

let nonceHex: String = try await provider.send(
    request: provider.getTransactionCountRequest(address: signable.address, block: .pending)
)
let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0

var tx = signable.transferTransaction(
    to: EthereumAddress("0x7099...")!,
    value: Wei.fromEther(1),
    nonce: nonce,
    maxPriorityFeePerGas: Wei.fromGwei(2),
    maxFeePerGas: Wei.fromGwei(30),
    chainId: 11155111
)
try signable.sign(transaction: &tx)
let txHash: String = try await provider.send(request: provider.sendRawTransactionRequest(tx.rawTransaction!))
```

### Message Signing & EIP-712

```swift
let signature = try signable.signMessage("Hello, Ethereum")
let recovered = try signable.recoverMessageSigner(message: "Hello, Ethereum", signature: signature)
```

### Contract Calls

```swift
let contract = try EthereumContract(address: contractAddress, abiJson: abiJson, provider: provider)
let balance: Wei = try await contract.readSingle(functionName: "balanceOf", args: [.address(addr)])
```

## Starknet

### Account & Balance

```swift
import StarknetKit

let signer = try StarknetSigner(mnemonic: "abandon abandon ...", path: .starknet)
let pubKey = signer.publicKeyFelt!
let address = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)
let account = StarknetAccount(signer: signer, address: address, chain: .sepolia,
                              provider: StarknetProvider(chain: .sepolia))

let balance: [String] = try await account.provider!.send(request: account.balanceRequest())
```

### Execute Transactions (V3, auto fee)

```swift
let call = StarknetCall(contractAddress: contractFelt, entrypoint: "transfer", calldata: [to, amount])
let response = try await account.executeV3(calls: [call])
let receipt = try await account.provider!.waitForTransaction(hash: response.transactionHashFelt)
```

### Contract Interaction

```swift
let contract = try StarknetContract(address: contractFelt, abiJson: abiJson,
                                    provider: StarknetProvider(chain: .sepolia))

// Read
let results = try await contract.call(function: "balanceOf", args: [.felt(addressFelt)])

// Write (auto nonce + fee)
let response = try await contract.invoke(function: "transfer",
                                         args: [.felt(to), .u256(amount)],
                                         account: account)
```

### SNIP-12 Typed Data Signing

```swift
let domain = SNIP12Domain(name: "MyDApp", version: "1", chainId: chain.chainId)
let typedData = SNIP12TypedData(types: types, primaryType: "Mail", domain: domain, message: message)
let hash = try typedData.messageHash(accountAddress: account.addressFelt)
let signature = try account.signer.sign(feltHash: hash)
```

## Structure

```
MultiChainKit
├── MultiChainCore    # Protocols (Chain, Account, Provider, Signer), BIP39/BIP32
├── EthereumKit       # Ethereum implementation
│   ├── Account       # EthereumAccount, EthereumSignableAccount
│   ├── Contract      # ABI encoding, EthereumContract
│   ├── Crypto        # Keccak256, Secp256k1
│   ├── Extensions    # EIP-712 typed data
│   ├── Provider      # EthereumProvider, JSON-RPC
│   ├── Signer        # EthereumSigner, EthereumSignature
│   ├── Transaction   # EthereumTransaction (EIP-1559), RLP
│   └── Types         # Wei, EthereumAddress, BlockTag, ABI, Events, Receipt
├── StarknetKit       # Starknet implementation
│   ├── Account       # StarknetAccount, OpenZeppelinAccount
│   ├── Contract      # StarknetContract, CairoValue, CairoType, ABI
│   ├── Crypto        # StarkCurve, Pedersen, Poseidon, StarknetKeyDerivation
│   ├── Extensions    # SNIP-12 typed data
│   ├── Provider      # StarknetProvider, JSON-RPC, fee estimation, polling
│   ├── Signer        # StarknetSigner, StarknetSignature
│   └── Transaction   # InvokeV1/V3, DeployAccountV1/V3, Receipt
└── MultiChainKit     # MultiChainWallet unified entry point
```

## Status

| Chain    | Mainnet | Testnet     |
| -------- | ------- | ----------- |
| Ethereum | ✓       | ✓ (Sepolia) |
| Starknet | ✓       | ✓ (Sepolia) |

**Ethereum:**

- BIP39/BIP32, accounts (read-only + signable)
- EIP-1559 transactions, RLP encoding, signing
- Provider (JSON-RPC), balance/nonce/call/sendRawTransaction
- ABI encode/decode, EthereumContract (read/write/estimateGas/getLogs)
- EIP-712 typed data signing, EIP-191 personal message signing

**Starknet:**

- BIP32 + EIP-2645 key grinding, StarkCurve (Pedersen, Poseidon)
- Account abstraction (OpenZeppelin), address derivation
- InvokeV1/V3, DeployAccountV1/V3 transactions, signing and verification
- Provider (JSON-RPC), fee estimation, transaction polling
- StarknetContract (call/invoke/estimateFee/getEvents), CairoValue codec
- SNIP-12 typed data signing (v0 Pedersen, v1 Poseidon)

**MultiChainKit:**

- MultiChainWallet: single mnemonic -> Ethereum + Starknet accounts
- Re-exports all modules via `import MultiChainKit`

## Related

- [web3swift](https://github.com/web3swift-team/web3swift)
- [starknet.swift](https://github.com/software-mansion/starknet.swift)

## License

MIT
